//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  Modified by Kiseok (carti-RIBs-Concurrency): RxSwift -> Swift Concurrency migration.
//  Derived from uber/RIBs-iOS.
//
//
//  Workflow.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 4/9/26.
//

import Foundation

// RxSwift replacement mapping:
// - `Workflow.onStep { ... -> Observable<(NextActionableItem, Value)> }`
//   -> `Workflow.onStep { ... async throws -> (NextActionableItem, Value) }`
// - `Step.onStep { ... -> Observable<(NextActionableItem, Value)> }`
//   -> `Step.onStep { ... async throws -> (NextActionableItem, Value) }`
// - `PublishSubject<(ActionableItemType, ())>` root trigger -> `subscribe(_:)`
//   starting committed `Task`s directly
// - `CompositeDisposable` owned by the workflow -> `AnyCancelTaskBag`
// - `Disposable.disposeWith(workflow:)` -> `Task.disposeWith(workflow:)`
// - `flatMapLatest + filter + take(1) + share()` step progression
//   -> sequential `async` chaining plus "wait until Interactable is active"

/// The base class for all workflows.
///
/// Workflows are used to execute a sequence of actionable items.
@MainActor
open class Workflow<ActionableItemType> {

	/// Called when the workflow has completed.
	open func didComplete() {
	}

	/// Called when the workflow has been forked.
	open func didFork() {
	}

	/// Called when an error occurs during the workflow execution.
	///
	/// - Parameter error: The error that occurred.
	open func didReceiveError(_ error: Error) {
	}

	/// Initializer.
	public init() {}

	/// Adds a step to the workflow.
	///
	/// - Parameter onStep: The closure to execute for this step.
	/// - Returns: A `Step` representing the added step.
	public final func onStep<NextActionableItemType, NextValueType>(
		_ onStep: @escaping @MainActor (ActionableItemType) async throws -> (NextActionableItemType, NextValueType)
	) -> Step<ActionableItemType, NextActionableItemType, NextValueType> {
		Step(workflow: self) { actionableItem in
			try await onStep(actionableItem)
		}
	}

	/// Subscribes to the workflow, triggering its execution.
	///
	/// - Parameter actionableItem: The initial actionable item to start the workflow with.
	/// - Returns: A task representing the workflow's execution.
	@discardableResult
	public final func subscribe(_ actionableItem: ActionableItemType) -> Task<Void, Never> {
		guard !commitFactories.isEmpty else {
			assertionFailure("Attempt to subscribe to \(self) before it is committed.")
			let noopTask = Task { }
			noopTask.store(in: cancellables)
			return noopTask
		}

		let workflowTask = Task { @MainActor [weak self] in
			guard let self else { return }

			let tasks = self.commitFactories.map { factory in
				let task = factory(actionableItem)
				task.store(in: self.cancellables)
				return task
			}

			for task in tasks {
				_ = await task.result
			}
		}

		workflowTask.store(in: cancellables)
		return workflowTask
	}

	fileprivate func appendCommit(
		_ factory: @escaping @MainActor (ActionableItemType) -> Task<Void, Never>
	) {
		commitFactories.append(factory)
	}

	fileprivate func didCompleteIfNotYet() {
		guard !didInvokeComplete else { return }
		didInvokeComplete = true
		didComplete()
	}

	fileprivate let cancellables = AnyCancelTaskBag()

	private var didInvokeComplete = false
	private var commitFactories: [@MainActor (ActionableItemType) -> Task<Void, Never>] = []
}

/// A step in a workflow.
@MainActor
open class Step<WorkflowActionableItemType, ActionableItemType, ValueType> {

	private let workflow: Workflow<WorkflowActionableItemType>
	private var operation: @MainActor (WorkflowActionableItemType) async throws -> (ActionableItemType, ValueType)

	fileprivate init(
		workflow: Workflow<WorkflowActionableItemType>,
		operation: @escaping @MainActor (WorkflowActionableItemType) async throws -> (ActionableItemType, ValueType)
	) {
		self.workflow = workflow
		self.operation = operation
	}

	/// Adds a subsequent step to the workflow.
	///
	/// - Parameter onStep: The closure to execute for this step.
	/// - Returns: A new `Step` representing the added step.
	public final func onStep<NextActionableItemType, NextValueType>(
		_ onStep: @escaping @MainActor (ActionableItemType, ValueType) async throws -> (NextActionableItemType, NextValueType)
	) -> Step<WorkflowActionableItemType, NextActionableItemType, NextValueType> {
		Step<WorkflowActionableItemType, NextActionableItemType, NextValueType>(workflow: workflow) { rootActionableItem in
			let (actionableItem, value) = try await self.operation(rootActionableItem)
			let activeActionableItem = try await Self.awaitActiveIfNeeded(actionableItem)
			return try await onStep(activeActionableItem, value)
		}
	}

	/// Adds an error handler to the workflow.
	///
	/// - Parameter onError: The closure to execute if an error occurs.
	/// - Returns: This step.
	public final func onError(
		_ onError: @escaping @MainActor (Error) -> Void
	) -> Step<WorkflowActionableItemType, ActionableItemType, ValueType> {
		let previousOperation = operation
		operation = { rootActionableItem in
			do {
				return try await previousOperation(rootActionableItem)
			} catch {
				onError(error)
				throw error
			}
		}
		return self
	}

	/// Commits the workflow, preparing it for subscription.
	///
	/// - Returns: The committed workflow.
	@discardableResult
	public final func commit() -> Workflow<WorkflowActionableItemType> {
		workflow.appendCommit { [weak workflow, operation] rootActionableItem in
			Task { @MainActor in
				guard let workflow else { return }
				
				do {
					_ = try await operation(rootActionableItem)
					workflow.didCompleteIfNotYet()
				} catch is CancellationError {
					return
				} catch WorkflowStepError.actionableItemBecameInactiveBeforeStep {
					return
				} catch {
					workflow.didReceiveError(error)
				}
			}
		}
		return workflow
	}

	/// Forks the workflow.
	///
	/// - Returns: A new step representing the fork.
	public final func fork() -> Step<WorkflowActionableItemType, ActionableItemType, ValueType> {
		workflow.didFork()
		return Step(workflow: workflow, operation: operation)
	}

	private static func awaitActiveIfNeeded(_ actionableItem: ActionableItemType) async throws -> ActionableItemType {
		guard let interactable = actionableItem as? Interactable else {
			return actionableItem
		}

		for await isActive in interactable.isActiveStream {
			if isActive {
				return actionableItem
			}
		}

		throw WorkflowStepError.actionableItemBecameInactiveBeforeStep
	}
}

public extension Task {

	/// Disposes the task when the given workflow completes.
	///
	/// - Parameter workflow: The workflow to scope the task to.
	@MainActor
	func disposeWith<ActionableItemType>(workflow: Workflow<ActionableItemType>) {
		store(in: workflow.cancellables)
	}
}

public extension AnyCancellableTask {

	/// Disposes the task when the given workflow completes.
	///
	/// - Parameter workflow: The workflow to scope the task to.
	@MainActor
	func disposeWith<ActionableItemType>(workflow: Workflow<ActionableItemType>) {
		workflow.cancellables.insert(self)
	}
}

@MainActor
private enum WorkflowStepError: Error {
	case actionableItemBecameInactiveBeforeStep
}

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
//  Worker.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/6/26.
//

// RxSwift replacement mapping:
// - `private let isStartedSubject = BehaviorSubject<Bool>(value: false)`
//   -> `private let isStartedSubject = CurrentValueAsyncStream<Bool>(false)`
// - `var isStartedStream: Observable<Bool>` -> `var isStartedStream: AsyncStream<Bool>`
// - `try isStartedSubject.value()` -> `isStartedSubject.value`
// - `isStartedSubject.onNext(true/false)` -> `isStartedSubject.send(true/false)`
// - `isStartedSubject.onCompleted()` -> `isStartedSubject.finish()`
// - `fileprivate var disposable: CompositeDisposable?`
//   -> `fileprivate var workerCancellable: CompositeCancellable?`
// - `private var interactorBindingDisposable: Disposable?`
//   -> `private var interactorBindingObservation: ActiveStateObservation?`
// - `interactorScope.isActiveStream.subscribe(onNext:)`
//   -> synchronous `interactorScope.observeActiveState { ... }`
// - Rx `Disposable.disposeOnStop(worker:)`
//   -> `Task.cancelOnStop(worker:)` / `Task.disposeOnStop(worker:)`

import Foundation

/// The base protocol for all workers.
@MainActor
public protocol Working: AnyObject {

	/// Starts the worker.
	///
	/// - Parameter interactorScope: The interactor scope to bind the worker to.
	func start(_ interactorScope: InteractorScope)

	/// Stops the worker.
	func stop()

	/// Indicates if the worker is currently started.
	var isStarted: Bool { get }

	/// A stream that emits a boolean value indicating whether the worker is started.
	var isStartedStream: AsyncStream<Bool> { get }
}

/// The base class for all workers.
///
/// Workers are used to perform tasks independently of the interactor's lifecycle,
/// but they can be bound to an interactor's lifecycle using the `start` method.
@MainActor
open class Worker: Working {

	/// Indicates if the worker is currently started.
	public final var isStarted: Bool {
		return isStartedSubject.value
	}

	/// A stream that emits a boolean value indicating whether the worker is started.
	public final var isStartedStream: AsyncStream<Bool> {
		return isStartedSubject.stream
	}

	/// Initializer.
	public init() {}

	/// Starts the worker.
	///
	/// - Parameter interactorScope: The interactor scope to bind the worker to.
	public final func start(_ interactorScope: InteractorScope) {
		guard !isStarted else {
			return
		}

		stop()
		isStartedSubject.send(true)

		let weakInteractorScope = WeakInteractorScope(sourceScope: interactorScope)
		bind(to: weakInteractorScope)
	}

	/// Called when the worker has started.
	///
	/// Subclasses should override this method to perform initialization and start tasks.
	open func didStart(_ interactorScope: InteractorScope) {

	}

	/// Stops the worker.
	public final func stop() {
		guard isStarted else {
			return
		}

		isStartedSubject.send(false)
		executeStop()
	}

	/// Called when the worker has stopped.
	///
	/// Subclasses should override this method to perform cleanup.
	open func didStop() {

	}

	private let isStartedSubject = CurrentValueAsyncStream<Bool>(false)
	fileprivate var workerCancellable: CompositeCancellable?
	private var interactorBindingObservation: ActiveStateObservation?

	private func bind(to interactorScope: InteractorScope) {
		unbindInteractor()

		// RxSwift replacement mapping:
		// - `interactorScope.isActiveStream.subscribe(onNext:)`
		//   -> `interactorScope.observeActiveState { ... }`
		// Like the Rx subscription, the current state is applied immediately and every later
		// change runs `didStart`/`didStop` before the interactor's `activate()`/`deactivate()`
		// returns, so no transition is skipped.
		interactorBindingObservation = interactorScope.observeActiveState { [weak self] isInteractorActive in
			guard let self else { return }
			if isInteractorActive {
				if self.isStarted {
					self.executeStart(interactorScope)
				}
			} else {
				self.executeStop()
			}
		}
	}

	private func executeStart(_ interactorScope: InteractorScope) {
		workerCancellable = CompositeCancellable()
		didStart(interactorScope)
	}

	private func executeStop() {
		guard let cancellable = self.workerCancellable else {
			return
		}

		cancellable.cancel()
		self.workerCancellable = nil

		didStop()
	}

	private func unbindInteractor() {
		interactorBindingObservation?.cancel()
		interactorBindingObservation = nil
	}

	isolated deinit {
		stop()
		unbindInteractor()
		isStartedSubject.finish()
	}
}

// MARK: - AnyCancellable Extension

public extension Task {

	/// Cancels the task when the given worker is stopped.
	///
	/// - Parameter worker: The worker to scope the task to.
	/// - Returns: The task itself.
	@MainActor
	@discardableResult
	func cancelOnStop(_ worker: Worker) -> Task {
		// RxSwift replacement mapping:
		// - `Disposable.disposeOnStop(worker:)` -> `Task.cancelOnStop(worker:)`
		// - `disposable.insert(...)` -> `workerCancellable.insert(...)`
		// - `disposable.dispose()` -> `task.cancel()`
		if let compositeCancellable = worker.workerCancellable {
			compositeCancellable.insert(self)
		} else {
			self.cancel()
			print("Task immediately cancelled, since \(worker) is stopped.")
		}

		return self
	}

	/// Disposes the task when the given worker is stopped. (Alias for `cancelOnStop`)
	///
	/// - Parameter worker: The worker to scope the task to.
	/// - Returns: The task itself.
	@MainActor
	@discardableResult
	func disposeOnStop(_ worker: Worker) -> Task {
		// Migration alias so existing RIBs call sites can replace
		// `disposable.disposeOnStop(...)` with `task.disposeOnStop(...)`.
		cancelOnStop(worker)
	}
}

// MARK: - WeakInteractorScope

@MainActor
fileprivate class WeakInteractorScope: InteractorScope {

	weak var sourceScope: InteractorScope?

	var isActive: Bool {
		return sourceScope?.isActive ?? false
	}

	var isActiveStream: AsyncStream<Bool> {
		return sourceScope?.isActiveStream ?? AsyncStream { continuation in
			continuation.yield(false)
			continuation.finish()
		}
	}

	func observeActiveState(_ onChange: @escaping @MainActor (Bool) -> Void) -> ActiveStateObservation {
		guard let sourceScope else {
			onChange(false)
			return ActiveStateObservation {}
		}
		return sourceScope.observeActiveState(onChange)
	}

	fileprivate init(sourceScope: InteractorScope? = nil) {
		self.sourceScope = sourceScope
	}
}

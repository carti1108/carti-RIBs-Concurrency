//
//  Interactor.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/20/25.
//

// RxSwift replacement mapping:
// - `private let isActiveSubject = BehaviorSubject<Bool>(value: false)`
//   -> `private let isActiveSubject = CurrentValueAsyncStream<Bool>(false)`
// - `var isActiveStream: Observable<Bool>` -> `var isActiveStream: AsyncStream<Bool>`
// - `try isActiveSubject.value()` -> `isActiveSubject.value`
// - `isActiveSubject.onNext(true/false)` -> `isActiveSubject.send(true/false)`
// - `isActiveSubject.onCompleted()` -> `isActiveSubject.finish()`
// - `fileprivate var activenessDisposable: CompositeDisposable?`
//   -> `fileprivate var activenessCancellables: CompositeCancellable?`
// - Rx `Disposable.disposeOnDeactivate(interactor:)`
//   -> `Task.cancelOnDeactivate(interactor:)` / `Task.disposeOnDeactivate(interactor:)`

import Foundation
import AsyncAlgorithms

/// The scope of an `Interactor`, defining its active state and stream.
@MainActor
public protocol InteractorScope: AnyObject {

	/// Indicates if the interactor is currently active.
	var isActive: Bool { get }

	/// A stream that emits a boolean value indicating whether the interactor is active.
	var isActiveStream: AsyncStream<Bool> { get }
}

/// The base protocol for all interactors.
@MainActor
public protocol Interactable: InteractorScope {

	/// Activates this interactor.
	func activate()

	/// Deactivates this interactor.
	func deactivate()
}

/// An `Interactor` defines a unit of business logic that corresponds to a router unit.
///
/// Interactors have a lifecycle dictated by the router that owns it. They should perform
/// business logic and state management only when they're active.
@MainActor
open class Interactor: Interactable {

	/// Indicates if the interactor is currently active.
	public var isActive: Bool {
		return isActiveSubject.value
	}

	/// A stream that emits a boolean value indicating whether the interactor is active.
	public var isActiveStream: AsyncStream<Bool> {
		return isActiveSubject.stream
	}

	private let isActiveSubject = CurrentValueAsyncStream<Bool>(false)
	fileprivate var activenessCancellables: CompositeCancellable?

	/// Initializer.
	public init() {}

	/// Activates this interactor.
	///
	/// - Note: This method is internally used by the framework. Application code should never
	/// invoke this method explicitly.
	public final func activate() {
		guard !isActive else { return }
		activenessCancellables = CompositeCancellable()
		isActiveSubject.send(true)
		didBecomeActive()
	}

	/// Called when the interactor has become active.
	///
	/// Subclasses should override this method to perform initialization and start tasks
	/// that should only execute while the interactor is active.
	open func didBecomeActive() {

	}

	/// Deactivates this interactor.
	///
	/// - Note: This method is internally used by the framework. Application code should never
	/// invoke this method explicitly.
	public final func deactivate() {
		guard isActive else { return }
		willResignActive()

		activenessCancellables?.cancel()
		activenessCancellables = nil

		isActiveSubject.send(false)
	}

	/// Called when the interactor will resign the active state.
	///
	/// Subclasses should override this method to perform cleanup. All tasks bound to the
	/// interactor's lifecycle (`cancelOnDeactivate(interactor:)`) are automatically cancelled.
	open func willResignActive() {

	}

	isolated deinit {
		if self.isActive {
			self.deactivate()
		}
		self.isActiveSubject.finish()
	}
}

public extension AsyncSequence where Self: Sendable, Element: Sendable {

	/// Confines the emission of elements from the sequence to the active lifespan of the given `InteractorScope`.
	///
	/// Elements emitted by the source sequence will only be forwarded if the interactor is active.
	///
	/// - Parameter interactorScope: The interactor scope to confine to.
	/// - Returns: A confined `AsyncStream`.
	@MainActor
	func confineTo(_ interactorScope: InteractorScope) -> AsyncStream<Element> {
		// RxSwift replacement mapping:
		// - `Observable.combineLatest(interactorScope.isActiveStream, self)`
		//   -> `AsyncAlgorithms.combineLatest(interactorScope.isActiveStream, self)`
		// - `.filter { isActive, value in isActive }` -> same
		// - `.map { isActive, value in value }` -> same
		// - resulting `Observable<Element>` -> `AsyncStream<Element>`
		return combineLatest(interactorScope.isActiveStream, self)
			.filter { isActive, value in
				isActive
			}
			.map { isActive, value in
				value
			}
			.eraseToStream()

	}
}

public extension Task {

	/// Cancels the task when the given interactor is deactivated.
	///
	/// - Parameter interactor: The interactor to scope the task to.
	/// - Returns: The task itself.
	@MainActor
	@discardableResult
	func cancelOnDeactivate(interactor: Interactor) -> Task {
		// RxSwift replacement mapping:
		// - `Disposable.disposeOnDeactivate(interactor:)` -> `Task.cancelOnDeactivate(interactor:)`
		// - `activenessDisposable.insert(disposable)` -> `activenessCancellables.insert(task)`
		// - `disposable.dispose()` -> `task.cancel()`
		if let cancellables = interactor.activenessCancellables {
			cancellables.insert(self)
		} else {
			self.cancel()
			print("Subscription immediately terminated, since \(interactor) is inactive.")
		}

		return self
	}

	/// Disposes the task when the given interactor is deactivated. (Alias for `cancelOnDeactivate`)
	///
	/// - Parameter interactor: The interactor to scope the task to.
	/// - Returns: The task itself.
	@MainActor
	@discardableResult
	func disposeOnDeactivate(interactor: Interactor) -> Task {
		// Migration alias so existing RIBs call sites can replace
		// `disposable.disposeOnDeactivate(...)` with `task.disposeOnDeactivate(...)`.
		cancelOnDeactivate(interactor: interactor)
	}
}

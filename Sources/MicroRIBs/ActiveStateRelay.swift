//
//  ActiveStateRelay.swift
//  MicroRIBs
//
//  Created by Kiseok on 11/13/26.
//

import Foundation
import OrderedCollections

/// Holds an activeness value and delivers its changes both synchronously and as an `AsyncStream`.
///
/// In upstream RIBs, subscriptions to a `BehaviorSubject` run in the same call stack as
/// `onNext`, so a parent's `deactivate()` deactivates the whole subtree before it returns.
/// Delivering through an `AsyncStream` hops through a `Task`, which loses that ordering and
/// can coalesce rapid changes so lifecycle callbacks are skipped. The framework therefore
/// propagates lifecycle changes through the synchronous observers held here, and keeps
/// `stream` for external observation.
@MainActor
public final class ActiveStateRelay {

	/// The current value.
	public private(set) var value: Bool

	/// A stream that replays the current value and emits every subsequent change.
	public var stream: AsyncStream<Bool> {
		subject.stream
	}

	private let subject: CurrentValueAsyncStream<Bool>
	private var observers: OrderedDictionary<UUID, @MainActor (Bool) -> Void> = [:]
	private var isFinished = false

	/// Initializer.
	///
	/// - Parameter initialValue: The initial value.
	public init(_ initialValue: Bool = false) {
		self.value = initialValue
		self.subject = CurrentValueAsyncStream(initialValue)
	}

	/// Updates the value and notifies the synchronous observers, in registration order,
	/// before returning.
	///
	/// - Parameter newValue: The new value.
	public func send(_ newValue: Bool) {
		guard !isFinished else { return }
		value = newValue
		subject.send(newValue)
		// An observer may cancel another observation while being notified, so skip
		// observers that were removed during this notification.
		for id in Array(observers.keys) {
			observers[id]?(newValue)
		}
	}

	/// Observes the value synchronously.
	///
	/// `onChange` is called immediately with the current value, then on every `send(_:)`
	/// before that call returns. The observation ends when the returned object is cancelled
	/// or deallocated.
	///
	/// - Parameter onChange: The closure called with the current and every subsequent value.
	/// - Returns: An object that keeps the observation alive.
	public func observe(_ onChange: @escaping @MainActor (Bool) -> Void) -> ActiveStateObservation {
		onChange(value)
		guard !isFinished else {
			return ActiveStateObservation {}
		}
		let id = UUID()
		observers[id] = onChange
		return ActiveStateObservation { [weak self] in
			_ = self?.observers.removeValue(forKey: id)
		}
	}

	/// Ends every observation and finishes `stream`. Later values are ignored.
	public func finish() {
		guard !isFinished else { return }
		isFinished = true
		observers.removeAll()
		subject.finish()
	}
}

/// Keeps a synchronous activeness observation alive.
///
/// The observation ends when `cancel()` is called or this object is deallocated, like
/// Combine's `AnyCancellable`.
@MainActor
public final class ActiveStateObservation {

	private var onCancel: (@MainActor () -> Void)?

	/// Initializer.
	///
	/// - Parameter onCancel: The closure that ends the observation. It is called at most once.
	public init(onCancel: @escaping @MainActor () -> Void) {
		self.onCancel = onCancel
	}

	/// Ends the observation. Calling this more than once has no effect.
	public func cancel() {
		let onCancel = self.onCancel
		self.onCancel = nil
		onCancel?()
	}

	isolated deinit {
		cancel()
	}
}

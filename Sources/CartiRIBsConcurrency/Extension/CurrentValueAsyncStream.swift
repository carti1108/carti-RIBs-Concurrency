//
//  CurrentValueAsyncStream.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/26/26.
//

// RxSwift replacement mapping:
// - `BehaviorSubject<Element>(value: initialValue)` -> `CurrentValueAsyncStream<Element>(initialValue)`
// - `BehaviorRelay<Element>(value: initialValue)` -> `CurrentValueAsyncStream<Element>(initialValue)`
// - `subject.value()` / `relay.value` -> `stream.value`
// - `subject.onNext(value)` / `relay.accept(value)` -> `stream.send(value)`
// - `subject.asObservable()` -> `stream.stream`
// - `subject.onCompleted()` -> `stream.finish()`

import Foundation

/// A thread-safe wrapper around `AsyncStream` that holds the latest value.
///
/// This serves as a replacement for RxSwift's `BehaviorSubject` or `BehaviorRelay`.
public final class CurrentValueAsyncStream<Value: Sendable>: @unchecked Sendable {
	private let lock = NSLock()
	private var _value: Value
	private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
	private var finished = false

	/// Initializer.
	///
	/// - Parameter initialValue: The initial value of the stream.
	public init(_ initialValue: Value) {
		self._value = initialValue
	}

	/// The current value held by the stream.
	public var value: Value {
		self.lock.lock()
		defer { self.lock.unlock() }
		return self._value
	}

	/// The underlying `AsyncStream` that emits the current value and subsequent updates.
	public var stream: AsyncStream<Value> {
		AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
			let id = UUID()

			self.lock.lock()
			if finished {
				self.lock.unlock()
				continuation.finish()
				return
			}
			let current = self._value
			self.continuations[id] = continuation
			continuation.yield(current)

			self.lock.unlock()

			continuation.onTermination = { [weak self] _ in
				guard let self else { return }
				self.lock.lock()
				self.continuations[id] = nil
				self.lock.unlock()
			}
		}
	}

	/// Sends a new value to the stream.
	///
	/// - Parameter newValue: The value to send.
	public func send(_ newValue: Value) {
		self.lock.lock()
		guard !finished else {
			self.lock.unlock()
			return
		}
		self._value = newValue
		let currentContinuations = Array(continuations.values)
		self.lock.unlock()

		currentContinuations.forEach { $0.yield(newValue) }
	}

	/// Finishes the stream, preventing further values from being sent.
	public func finish() {
		self.lock.lock()
		guard !finished else {
			self.lock.unlock()
			return
		}
		self.finished = true
		let currentContinuations = Array(self.continuations.values)
		self.continuations.removeAll()
		self.lock.unlock()

		currentContinuations.forEach { $0.finish() }
	}

	deinit {
		self.finish()
	}
}

//
//  PassthroughAsyncSubject.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/26/26.
//

// RxSwift replacement mapping:
// - `PublishSubject<Element>()` -> `PassthroughAsyncSubject<Element>()`
// - `subject.onNext(value)` -> `subject.send(value)`
// - `subject.asObservable()` -> `subject.stream`
// - `subject.onCompleted()` -> `subject.finish()`

import Foundation

/// A thread-safe subject that passes values through an `AsyncStream`.
///
/// This serves as a replacement for RxSwift's `PublishSubject`.
public final class PassthroughAsyncSubject<Value: Sendable>: @unchecked Sendable {

	private let lock = NSLock()
	private var continuations: [UUID: AsyncStream<Value>.Continuation] = [:]
	private var finished = false

	/// Initializer.
	public init() {}

	/// The underlying `AsyncStream` that emits sent values.
	public var stream: AsyncStream<Value> {
		AsyncStream { continuation in
			let id = UUID()

			self.lock.lock()
			if self.finished {
				self.lock.unlock()
				continuation.finish()
				return
			}

			self.continuations[id] = continuation
			self.lock.unlock()

			continuation.onTermination = { [weak self] _ in
				guard let self = self else { return }
				self.lock.lock()
				self.continuations[id] = nil
				self.lock.unlock()
			}
		}
	}

	/// Sends a new value to the stream.
	///
	/// - Parameter value: The value to send.
	public func send(_ value: Value) {
		self.lock.lock()
		guard !self.finished else {
			self.lock.unlock()
			return
		}

		let currentContinuations = Array(self.continuations.values)
		self.lock.unlock()

		for continuation in currentContinuations {
			continuation.yield(value)
		}
	}

	/// Finishes the stream, preventing further values from being sent.
	public func finish() {
		self.lock.lock()
		guard !self.finished else {
			self.lock.unlock()
			return
		}
		self.finished = true
		let currentContinuations = Array(self.continuations.values)
		self.continuations.removeAll()
		self.lock.unlock()

		for continuation in currentContinuations {
			continuation.finish()
		}
	}

	deinit {
		self.finish()
	}
}

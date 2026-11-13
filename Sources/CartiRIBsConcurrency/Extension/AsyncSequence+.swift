//
//  AsyncSequence+.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/26/26.
//

// RxSwift replacement mapping:
// - `Observable<Element>` chains that ended with another `Observable<Element>`
//   are represented here as `AsyncSequence<Element>` chains that are converted
//   back to `AsyncStream<Element>` via `eraseToStream()`.

import Foundation

public extension AsyncSequence where Self: Sendable, Element: Sendable  {
	/// Erases the type of this sequence to a standard `AsyncStream`.
	///
	/// - Returns: An `AsyncStream` that emits the elements from this sequence.
	func eraseToStream() -> AsyncStream<Element> {
		AsyncStream { continuation in
			let task = Task {
				do {
					for try await element in self {
						continuation.yield(element)
					}

					continuation.finish()
				} catch {
					continuation.finish()
				}
			}
			continuation.onTermination = { _ in task.cancel() }
		}
	}

	/// Erases the type of this sequence to a standard `AsyncThrowingStream`.
	///
	/// - Returns: An `AsyncThrowingStream` that emits the elements and errors from this sequence.
	func eraseToThrowingStream() -> AsyncThrowingStream<Element, Error> {
		AsyncThrowingStream { continuation in
			let task = Task {
				do {
					for try await element in self {
						continuation.yield(element)
					}
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
			continuation.onTermination = { _ in task.cancel() }
		}
	}
}

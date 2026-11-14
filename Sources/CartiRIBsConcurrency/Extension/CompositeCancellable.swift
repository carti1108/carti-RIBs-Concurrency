//
//  CompositeCancellable.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/26/26.
//

// RxSwift replacement mapping:
// - `CompositeDisposable` -> `CompositeCancellable`
// - `composite.insert(disposable)` -> `composite.insert(taskLike)`
// - `composite.dispose()` -> `composite.cancel()`
// This is used for task teardown in places that previously stored Rx
// subscriptions.

import Foundation

/// A thread-safe collection of `AnyCancellableTask`s that can be cancelled together.
///
/// This serves as a replacement for RxSwift's `CompositeDisposable`.
public final class CompositeCancellable: @unchecked Sendable {

	public typealias Key = UUID

	private let lock = NSLock()
	private var subscriptions: [Key: AnyCancellableTask] = [:]
	private var isCancelled = false

	/// Initializer.
	public init() {}

	/// Inserts a cancellable task into the composite.
	///
	/// If the composite has already been cancelled, the task is cancelled immediately.
	///
	/// - Parameter cancellable: The task to insert.
	/// - Returns: A unique key that can be used to remove the task later.
	@discardableResult
	public func insert(_ cancellable: AnyCancellableTask) -> Key {
		lock.lock()
		defer { lock.unlock() }

		let key = UUID()

		if isCancelled {
			cancellable.cancel()
		} else {
			subscriptions[key] = cancellable
		}

		return key
	}

	/// Removes and cancels the task associated with the given key.
	///
	/// - Parameter key: The key of the task to remove.
	public func remove(for key: Key) {
		lock.lock()
		let cancellable = subscriptions.removeValue(forKey: key)
		lock.unlock()

		cancellable?.cancel()
	}

	/// Cancels all tasks contained in this composite and prevents new ones from being added.
	public func cancel() {
		lock.lock()
		guard !isCancelled else {
			lock.unlock()
			return
		}

		isCancelled = true
		let currentSubscriptions = subscriptions.values
		subscriptions.removeAll()
		lock.unlock()

		for item in currentSubscriptions {
			item.cancel()
		}
	}

	deinit {
		cancel()
	}
}

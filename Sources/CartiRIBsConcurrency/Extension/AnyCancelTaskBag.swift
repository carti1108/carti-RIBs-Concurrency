//
//  AnyCancelTaskBag.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/26/26.
//

// RxSwift replacement mapping:
// - `DisposeBag` / ad-hoc grouped `Disposable` storage -> `AnyCancelTaskBag`
// - `disposable.disposed(by: bag)`-style ownership -> `task.store(in: bag)`
// - migration alias: `task.disposeWith(bag)`

import Foundation

/// A thread-safe bag that holds `AnyCancellableTask`s and cancels them upon deallocation.
///
/// This serves as a replacement for RxSwift's `DisposeBag`.
public final class AnyCancelTaskBag: @unchecked Sendable {

	private let lock = NSLock()

	private var tasks: [any AnyCancellableTask] = .init()

	/// Initializer.
	public init() {}

	/// Inserts a cancellable task into the bag.
	///
	/// - Parameter task: The task to insert.
	public func insert(_ task: any AnyCancellableTask) {
		self.lock.lock()
		self.tasks.append(task)
		self.lock.unlock()
	}

	private func cancel() {
		self.lock.lock()
		let currentTasks = self.tasks
		self.tasks.removeAll()
		self.lock.unlock()

		currentTasks.forEach { $0.cancel() }
	}

	deinit {
		self.cancel()
	}
}

public extension Task {
	/// Stores this task in the given `AnyCancelTaskBag`.
	///
	/// - Parameter bag: The bag to store the task in.
	func store(in bag: AnyCancelTaskBag) {
		bag.insert(self)
	}

	/// Stores this task in the given `AnyCancelTaskBag`. (Alias for `store(in:)`)
	///
	/// - Parameter bag: The bag to store the task in.
	func disposeWith(_ bag: AnyCancelTaskBag) {
		store(in: bag)
	}
}

//
//  AnyCancellableTask.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/26/26.
//

// RxSwift replacement mapping:
// - `Disposable` -> `AnyCancellableTask`
// - `disposable.dispose()` -> `task.cancel()`

import Foundation

/// A protocol representing a task that can be cancelled.
public protocol AnyCancellableTask: Sendable {
	/// Cancels the task.
	func cancel()
}

extension Task: AnyCancellableTask {}

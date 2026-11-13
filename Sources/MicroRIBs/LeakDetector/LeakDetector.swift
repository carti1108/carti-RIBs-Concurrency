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
//  Modified by Kiseok (MicroRIBs): RxSwift -> Swift Concurrency migration.
//  Derived from uber/RIBs-iOS.
//
//
//  LeakDetector.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/24/25.
//
//
// RxSwift replacement mapping:
// - `var status: Observable<LeakDetectionStatus>` -> `var status: AsyncStream<LeakDetectionStatus>`
// - `BehaviorRelay<Int>(value: 0)` for `expectationCount`
//   -> `CurrentValueAsyncStream<Int>(0)`
// - `expectationCount.accept(newValue)` -> `expectationCount.send(newValue)`
// - `expectationCount.asObservable().map(...).distinctUntilChanged()`
//   -> `expectationCount.stream.map(...).removeDuplicates().eraseToStream()`
// - `BehaviorRelay<Bool>(value: false)` inside `LeakDetectionHandleImpl`
//   -> `CurrentValueAsyncStream<Bool>(false)`
// - `cancelledRelay.accept(true)` -> `cancelledStream.send(true)`
// - `Executor.execute(withDelay:) { ... }` still exists, but now returns a
//   Swift Concurrency `Task<Void, Never>` instead of an Rx-managed resource.

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import AsyncAlgorithms

/// The status of leak detection.
public enum LeakDetectionStatus: Sendable {
	/// Leak detection is currently in progress.
	case InProgress
	/// Leak detection has completed.
	case DidComplete
}

/// Default timeout durations for leak detection expectations.
public struct LeakDefaultExpectationTime {
	/// The default time to wait for object deallocation (1.0 second).
	public static let deallocation = 1.0
	/// The default time to wait for a view controller to disappear (5.0 seconds).
	public static let viewDisappear = 5.0
}

/// A handle that can be used to cancel a leak detection expectation.
@MainActor
public protocol LeakDetectionHandle {
	/// Cancels the leak detection expectation.
	func cancel()
}

/// An explicitly-invoked leak detector that checks for memory leaks.
///
/// Under the hood, this uses a combination of weak references and delayed
/// execution on the MainActor.
@MainActor
public class LeakDetector {

	/// The singleton instance of the leak detector.
	public static private(set) var instance = LeakDetector()

	static func setInstance(_ newInstance: LeakDetector) {
		instance = newInstance
	}

	/// A stream that emits the current status of the leak detector.
	public var status: AsyncStream<LeakDetectionStatus> {
		return expectationCount.stream
			.map { count in
				count > 0 ? LeakDetectionStatus.InProgress : LeakDetectionStatus.DidComplete
			}
			.removeDuplicates()
			.eraseToStream()
	}

	/// Sets up an expectation for the given object to be deallocated within the given time.
	///
	/// - Parameters:
	///   - object: The object to track for deallocation.
	///   - time: The time interval to wait before checking for a leak.
	/// - Returns: A handle that can be used to cancel the expectation.
	@discardableResult
	public func expectDeallocate(object: AnyObject, inTime time: TimeInterval = LeakDefaultExpectationTime.deallocation) -> LeakDetectionHandle {
		self.increaseExpectationCount()

		let objectDescription = String(describing: object)
		let objectId = String(ObjectIdentifier(object).hashValue) as NSString

		trackingObjects.setObject(object, forKey: objectId)

		let handle = LeakDetectionHandleImpl { [weak self] in
			self?.decreaseExpectationCount()
		}

		_ = Executor.execute(withDelay: time) { [weak self] in
			guard let self = self else { return }

			if !handle.cancelled {
				let didDeallocate = (self.trackingObjects.object(forKey: objectId) == nil)
				let trackingObjectsDescription = String(describing: self.trackingObjects)
				
				let message = "<\(objectDescription): \(objectId)> has leaked. Objects are expected to be deallocated at this time: \(trackingObjectsDescription)"

				if self.disableLeakDetector {
					if !didDeallocate {
						print("Leak detection is disabled. This should only be used for debugging purposes.")
						print(message)
					}
				} else {
					assert(didDeallocate, message)
				}
			}

			if !handle.cancelled {
				self.decreaseExpectationCount()
			}
		}

		return handle
	}

	/// Sets up an expectation for the given view controller to disappear within the given time.
	///
	/// - Parameters:
	///   - viewController: The view controller to track for disappearance.
	///   - time: The time interval to wait before checking.
	/// - Returns: A handle that can be used to cancel the expectation.
	#if canImport(UIKit)
	@discardableResult
	public func expectViewControllerDisappear(viewController: UIViewController, inTime time: TimeInterval = LeakDefaultExpectationTime.viewDisappear) -> LeakDetectionHandle {
		self.increaseExpectationCount()

		let handle = LeakDetectionHandleImpl { [weak self] in
			self?.decreaseExpectationCount()
		}

		_ = Executor.execute(withDelay: time) { [weak self, weak viewController] in
			guard let self = self else { return }

			if let viewController = viewController, !handle.cancelled {
				let viewDidDisappear = (!viewController.isViewLoaded || viewController.view.window == nil)

				let trackingObjectsDescription = String(describing: self.trackingObjects)
				
				let message = "\(viewController) appearance has leaked. Either its parent router who does not own a view controller was detached, but failed to dismiss the leaked view controller; or the view controller is reused and re-added to window, yet the router is not re-attached but re-created. Objects are expected to be deallocated at this time: \(trackingObjectsDescription)"

				if self.disableLeakDetector {
					if !viewDidDisappear {
						print("Leak detection is disabled. This should only be used for debugging purposes.")
						print(message)
					}
				} else {
					assert(viewDidDisappear, message)
				}
			}

			if !handle.cancelled {
				self.decreaseExpectationCount()
			}
		}

		return handle
	}
	#elseif canImport(AppKit)
	@discardableResult
	public func expectViewControllerDisappear(viewController: NSViewController, inTime time: TimeInterval = LeakDefaultExpectationTime.viewDisappear) -> LeakDetectionHandle {
		self.increaseExpectationCount()

		let handle = LeakDetectionHandleImpl { [weak self] in
			self?.decreaseExpectationCount()
		}

		_ = Executor.execute(withDelay: time) { [weak self, weak viewController] in
			guard let self = self else { return }

			if let viewController = viewController, !handle.cancelled {
				let viewDidDisappear = (!viewController.isViewLoaded || viewController.view.window == nil)
				let message = "\(viewController) is expected to be removed from its window by now."

				if self.disableLeakDetector {
					if !viewDidDisappear {
						print("Leak detection is disabled. This should only be used for debugging purposes.")
						print(message)
					}
				} else {
					assert(viewDidDisappear, message)
				}
			}

			if !handle.cancelled {
				self.decreaseExpectationCount()
			}
		}

		return handle
	}
	#endif

	static var disableLeakDetectorOverride: Bool = false

#if DEBUG
	func reset() {
		trackingObjects.removeAllObjects()
		expectationCount.send(0)
	}
#endif

	private let expectationCount = CurrentValueAsyncStream<Int>(0)
	private let trackingObjects = NSMapTable<AnyObject, AnyObject>.strongToWeakObjects()

	private func increaseExpectationCount() {
		expectationCount.send(expectationCount.value + 1)
	}

	private func decreaseExpectationCount() {
		expectationCount.send(expectationCount.value - 1)
	}

	lazy var disableLeakDetector: Bool = {
		if let environmentValue = ProcessInfo().environment["DISABLE_LEAK_DETECTION"] {
			let lowercase = environmentValue.lowercased()
			return lowercase == "yes" || lowercase == "true"
		}
		return LeakDetector.disableLeakDetectorOverride
	}()
}

@MainActor
private class LeakDetectionHandleImpl: LeakDetectionHandle {
	var cancelled: Bool {
		return cancelledStream.value
	}

	let cancelledStream = CurrentValueAsyncStream<Bool>(false)
	let cancelClosure: (() -> Void)?

	init(cancelClosure: (() -> Void)? = nil) {
		self.cancelClosure = cancelClosure
	}

	func cancel() {
		cancelledStream.send(true)
		cancelClosure?()
	}
}

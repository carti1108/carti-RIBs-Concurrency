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
//  Router.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/20/25.
//

// RxSwift replacement mapping:
// - `private let lifecycleSubject = PublishSubject<RouterLifecycle>()`
//   -> `private let lifecycleSubject = PassthroughAsyncSubject<RouterLifecycle>()`
// - `var lifecycle: Observable<RouterLifecycle>` -> `var lifecycle: AsyncStream<RouterLifecycle>`
// - `lifecycleSubject.onNext(.didLoad)` -> `lifecycleSubject.send(.didLoad)`
// - `lifecycleSubject.onCompleted()` -> `lifecycleSubject.finish()`
// - Rx subscription to `interactable.isActiveStream`
//   -> synchronous `interactable.observeActiveState { ... }`
// - `CompositeDisposable` for router teardown -> `[ActiveStateObservation]`

import Foundation

/// The lifecycle stages of a router node.
@MainActor
public enum RouterLifecycle {
	/// Router has been loaded.
	case didLoad
}

/// The scope of a `Router`, defining its lifecycle stream.
@MainActor
public protocol RouterScope: AnyObject {
	/// A stream that emits router lifecycle events.
	var lifecycle: AsyncStream<RouterLifecycle>  { get }
}

/// The base protocol for all routers.
@MainActor
public protocol Routing: RouterScope {
	/// The interactable corresponding to this router.
	var interactable: Interactable { get }

	/// The children of this router.
	var children: [Routing] { get }

	/// Loads the router. This method is invoked once when the router is attached to the RIB tree.
	func load()

	/// Attaches the given child router to the RIB tree.
	///
	/// - Parameter child: The child router to attach.
	func attachChild(_ child: Routing)

	/// Detaches the given child router from the RIB tree.
	///
	/// - Parameter child: The child router to detach.
	func detachChild(_ child: Routing)
}

/// The base class of all routers that own no views.
///
/// Routers are responsible for routing between RIBs, including attaching and
/// detaching child RIBs. In MicroRIBs, routers operate strictly on the `@MainActor`.
@MainActor
open class Router<InteractorType>: Routing {

	/// The corresponding `Interactor` of this router.
	public let interactor: InteractorType

	/// The corresponding `Interactable` of this router.
	public let interactable: Interactable

	/// The children of this router.
	public final var children: [Routing] {
		return _children
	}

	/// A stream that emits router lifecycle events.
	public final var lifecycle: AsyncStream<RouterLifecycle> {
		return lifecycleSubject.stream
	}

	/// Synchronous activeness observations owned by this router, ended in `deinit`.
	var activeStateObservations: [ActiveStateObservation] = []

	private var didLoadFlag: Bool = false
	private let lifecycleSubject = PassthroughAsyncSubject<RouterLifecycle>()
	private var _children: [Routing] = []

	/// Initializer.
	///
	/// - Parameter interactor: The corresponding `Interactor` of this `Router`.
	public init(interactor: InteractorType) {
		self.interactor = interactor

		guard let interactable = interactor as? Interactable else {
			fatalError("\(interactor) should conform to \(Interactable.self)")
		}

		self.interactable = interactable
	}

	/// Loads the router. This method is invoked once when the router is attached to the RIB tree.
	public final func load() {
		guard !didLoadFlag else {
			return
		}

		didLoadFlag = true
		internalDidLoad()
		didLoad()
	}

	/// Called when the router has finished loading.
	///
	/// This method is invoked only once. Subclasses should override this method to perform
	/// one-time setup logic, such as attaching initial children.
	open func didLoad() {
	}

	/// Attaches the given child router to the RIB tree.
	///
	/// - Parameter child: The child router to attach.
	public final func attachChild(_ child: Routing) {
		assert(!(_children.contains { $0 === child }), "Attempt to attach child: \(child), which is already attached to \(self).")

		_children.append(child)

		child.interactable.activate()
		child.load()
	}

	/// Detaches the given child router from the RIB tree.
	///
	/// - Parameter child: The child router to detach.
	public final func detachChild(_ child: Routing) {
		child.interactable.deactivate()
		_children.removeElementByReference(child)
	}


	func internalDidLoad() {
		bindSubtreeActiveState()
		lifecycleSubject.send(.didLoad)
	}

	private func bindSubtreeActiveState() {
		// RxSwift replacement mapping:
		// - `interactable.isActiveStream.subscribe(onNext:)`
		//   -> `interactable.observeActiveState { ... }`
		// The Rx subscription replays the current state and delivers every change in the same
		// call stack, so the subtree follows the parent before `activate()`/`deactivate()`
		// returns. A `Task` iterating `isActiveStream` would deliver later and could skip
		// coalesced changes, so the synchronous observation is used instead. The closure holds
		// the router weakly so the interactor never keeps its router alive.
		let observation = interactable.observeActiveState { [weak self] isActive in
			self?.setSubtreeActive(isActive)
		}
		activeStateObservations.append(observation)
	}

	private func setSubtreeActive(_ active: Bool) {
		iterateSubtree(self) { router in
			if active {
				if !router.interactable.isActive {
					router.interactable.activate()
				}
			} else {
				if router.interactable.isActive {
					router.interactable.deactivate()
				}
			}
		}
	}

	private func iterateSubtree(_ root: Routing, closure: (_ node: Routing) -> Void) {
		closure(root)
		for child in root.children {
			iterateSubtree(child, closure: closure)
		}
	}

	private func detachAllChildren() {
		let childrenToDetach = _children

		for child in childrenToDetach {
			detachChild(child)
		}
	}

	isolated deinit {
		interactable.deactivate()

		if !children.isEmpty {
			detachAllChildren()
		}

		lifecycleSubject.finish()
		activeStateObservations.forEach { $0.cancel() }
		activeStateObservations.removeAll()

		_ = LeakDetector.instance.expectDeallocate(object: interactable)
	}
}

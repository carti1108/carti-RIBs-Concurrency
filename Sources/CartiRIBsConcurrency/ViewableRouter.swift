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
//  Modified by Kiseok (carti-RIBs-Concurrency): RxSwift -> Swift Concurrency migration.
//  Derived from uber/RIBs-iOS.
//
//
//  ViewableRouter.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 12/23/25.
//

// RxSwift replacement mapping:
// - Rx subscription to `interactable.isActiveStream`
//   -> synchronous `interactable.observeActiveState { ... }`
// - `deinitDisposable.insert(disposable)` -> `activeStateObservations.append(observation)`
// - upstream `viewControllable.uiviewController`
//   -> `viewControllable.uiViewController` / `uiviewController` alias
// The leak detection target and timing are kept aligned with upstream RIBs.

import Foundation

/// The base protocol for all routers that own their own view.
@MainActor
public protocol ViewableRouting: Routing {
	/// The `ViewControllable` associated with this router.
	var viewControllable: ViewControllable { get }
}

/// The base class of all routers that own their own view.
@MainActor
open class ViewableRouter<InteractorType, ViewControllerType>: Router<InteractorType>, ViewableRouting {

	/// The corresponding `ViewController` owned by this router.
	public let viewController: ViewControllerType

	/// The `ViewControllable` associated with this router.
	public let viewControllable: ViewControllable

	private var viewControllerDisappearExpectation: LeakDetectionHandle?

	/// Initializer.
	///
	/// - Parameters:
	///   - interactor: The corresponding `Interactor` of this `Router`.
	///   - viewController: The corresponding `ViewController` of this `Router`.
	public init(interactor: InteractorType, viewController: ViewControllerType) {
		self.viewController = viewController
		guard let viewControllable = viewController as? ViewControllable else {
			fatalError("\(viewController)는 \(ViewControllable.self)를 conform해야 합니다")
		}
		self.viewControllable = viewControllable
		super.init(interactor: interactor)
	}

	override func internalDidLoad() {
		self.setupViewControllerLeakDetection()
		super.internalDidLoad()
	}

	private func setupViewControllerLeakDetection() {
		// Observed synchronously like the upstream Rx subscription. The closure holds the
		// router weakly so the interactor never keeps its router alive.
		let observation = interactable.observeActiveState { [weak self] isActive in
			self?.handleInteractableStateChange(isActive)
		}
		activeStateObservations.append(observation)
	}

	private func handleInteractableStateChange(_ isActive: Bool) {
		viewControllerDisappearExpectation?.cancel()
		viewControllerDisappearExpectation = nil

		if !isActive {
			#if canImport(UIKit)
			let controller = viewControllable.uiViewController
			viewControllerDisappearExpectation = LeakDetector.instance.expectViewControllerDisappear(viewController: controller)
			#elseif canImport(AppKit)
			let controller = viewControllable.nsViewController
			viewControllerDisappearExpectation = LeakDetector.instance.expectViewControllerDisappear(viewController: controller)
			#endif
		}
	}

	isolated deinit {
		_ = LeakDetector.instance.expectDeallocate(
			object: trackedViewController,
			inTime: LeakDefaultExpectationTime.viewDisappear
		)
	}

	private var trackedViewController: AnyObject {
		#if canImport(UIKit)
		viewControllable.uiViewController
		#elseif canImport(AppKit)
		viewControllable.nsViewController
		#else
		viewControllable
		#endif
	}
}

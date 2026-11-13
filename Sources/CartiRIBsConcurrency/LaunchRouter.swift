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
//  LaunchRouter.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 12/23/25.
//

// RxSwift replacement mapping:
// - No Rx type was used here in upstream RIBs.
// - The Swift Concurrency migration here is `@MainActor` isolation only.

#if canImport(UIKit)
import UIKit

/// The base protocol for the root router of an application.
@MainActor
public protocol LaunchRouting: ViewableRouting {

	/// Launches the router tree.
	///
	/// - Parameter window: The application window to launch from.
	func launch(from window: UIWindow)
}

/// The base class of the root router of an application.
@MainActor
open class LaunchRouter<InteractorType, ViewControllerType>: ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting {

	/// Initializer.
	///
	/// - Parameters:
	///   - interactor: The corresponding `Interactor` of this `Router`.
	///   - viewController: The corresponding `ViewController` of this `Router`.
	public override init(interactor: InteractorType, viewController: ViewControllerType) {
		super.init(interactor: interactor, viewController: viewController)
	}

	/// Launches the router tree.
	///
	/// - Parameter window: The application window to launch from.
	@MainActor
	public final func launch(from window: UIWindow) {
		window.rootViewController = viewControllable.uiViewController
		window.makeKeyAndVisible()

		interactable.activate()
		load()
	}
}
#elseif canImport(AppKit)
import AppKit

/// The base protocol for the root router of a macOS application.
@MainActor
public protocol LaunchRouting: ViewableRouting {
	func launch(from window: NSWindow)
}

/// The base class of the root router of a macOS application.
@MainActor
open class LaunchRouter<InteractorType, ViewControllerType>: ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting {
	public override init(interactor: InteractorType, viewController: ViewControllerType) {
		super.init(interactor: interactor, viewController: viewController)
	}

	public final func launch(from window: NSWindow) {
		window.contentViewController = viewControllable.nsViewController
		window.makeKeyAndOrderFront(nil)
		interactable.activate()
		load()
	}
}
#endif

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
//  ViewControllable.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 12/20/25.
//

// RxSwift replacement mapping:
// - No Rx type was used here in upstream RIBs.
// - `uiviewController` is kept as a compatibility alias for migrated RIBs code.

#if canImport(UIKit)
import UIKit

/// Basic interface between a `Router` and the UIKit `UIViewController`.
@MainActor
public protocol ViewControllable: AnyObject {

	/// The actual `UIViewController` instance backing this `ViewControllable`.
	var uiViewController: UIViewController { get }
}

public extension ViewControllable where Self: UIViewController {

	var uiViewController: UIViewController { self }
}

@MainActor
public extension ViewControllable {

	/// A compatibility alias for `uiViewController` to support existing RIBs code.
	var uiviewController: UIViewController {
		uiViewController
	}

	func present(_ viewControllable: ViewControllable, animated: Bool, completion: (() -> Void)?) {
		self.uiViewController.present(viewControllable.uiViewController, animated: animated, completion: completion)
	}

	func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
		self.uiViewController.dismiss(animated: animated, completion: completion)
	}

	func pushViewController(_ viewControllable: ViewControllable, animated: Bool) {
		if let nav = self.uiViewController as? UINavigationController {
			nav.pushViewController(viewControllable.uiViewController, animated: animated)
		} else {
			self.uiViewController.navigationController?.pushViewController(viewControllable.uiViewController, animated: animated)
		}
	}

	func popViewController(animated: Bool) {
		if let nav = self.uiViewController as? UINavigationController {
			nav.popViewController(animated: animated)
		} else {
			self.uiViewController.navigationController?.popViewController(animated: animated)
		}
	}

	func popToRoot(animated: Bool) {
		if let nav = self.uiViewController as? UINavigationController {
			nav.popToRootViewController(animated: animated)
		} else {
			self.uiViewController.navigationController?.popToRootViewController(animated: animated)
		}
	}

	func setViewControllers(_ viewControllerables: [ViewControllable]) {
		if let nav = self.uiViewController as? UINavigationController {
			nav.setViewControllers(viewControllerables.map(\.uiViewController), animated: true)
		} else {
			self.uiViewController.navigationController?.setViewControllers(viewControllerables.map(\.uiViewController), animated: true)
		}
	}

	/// Returns the top-most `ViewControllable` in the presented view controller hierarchy.
	var topViewControllable: ViewControllable {
		var top: ViewControllable = self

		while let presented = top.uiViewController.presentedViewController as? ViewControllable {
			top = presented
		}

		return top
	}
}
#elseif canImport(AppKit)
import AppKit

/// Basic interface between a `Router` and the AppKit `NSViewController`.
@MainActor
public protocol ViewControllable: AnyObject {
	/// The actual `NSViewController` instance backing this `ViewControllable`.
	var nsViewController: NSViewController { get }
}

public extension ViewControllable where Self: NSViewController {
	var nsViewController: NSViewController { self }
}
#endif

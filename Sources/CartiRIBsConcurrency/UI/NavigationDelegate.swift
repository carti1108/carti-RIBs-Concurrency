//
//  NavigationDelegate.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/30/25.
//

#if canImport(UIKit)
import UIKit

/// A delegate that handles navigation lifecycle events for a `UINavigationController`.
@MainActor
public final class NavigationDelegate: NSObject, UINavigationControllerDelegate {

	// MARK: - Public Properties

	/// The previously stored delegate of the `UINavigationController`.
	public var storedPreviousDelegate: UINavigationControllerDelegate? {
		return self.previousDelegate
	}

	// MARK: - Private Properties

	private let onPop: () -> Void
	
	private weak var targetViewController: UIViewController?
	
	private weak var navigationController: UINavigationController?
	
	private weak var previousDelegate: UINavigationControllerDelegate?
	
	// MARK: - Initialization

	/// Initializer.
	///
	/// - Parameters:
	///   - onPop: The closure to execute when the target view controller is popped.
	///   - targetViewController: The target view controller to monitor for pop events.
	///   - navigationController: The navigation controller managing the target view controller.
	public init(
		onPop: @escaping () -> Void,
		targetViewController: UIViewController,
		navigationController: UINavigationController
	) {
		self.onPop = onPop
		self.targetViewController = targetViewController
		self.navigationController = navigationController
		self.previousDelegate = navigationController.delegate
		super.init()
		navigationController.delegate = self
	}
	
	// MARK: - Public Methods

	public func navigationController(
		_ navigationController: UINavigationController,
		didShow viewController: UIViewController,
		animated: Bool
	) {
		self.previousDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
		
		guard let target = self.targetViewController else {
			return
		}
		
		let isTargetVisible = navigationController.viewControllers.contains(target)
		
		if !isTargetVisible {
			self.onPop()
		}
	}
	
	public func navigationController(
		_ navigationController: UINavigationController,
		willShow viewController: UIViewController,
		animated: Bool
	) {
		self.previousDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
	}
}
#endif

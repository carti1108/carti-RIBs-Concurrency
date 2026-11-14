//
//  NavigationControllable.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/2/26.
//

#if canImport(UIKit)
import UIKit

/// A `ViewControllable` wrapper around `UINavigationController`.
@MainActor
public final class NavigationControllerable: ViewControllable {

	// MARK: - Public Properties

	/// The underlying `UIViewController` (which is the `UINavigationController`).
	public var uiViewController: UIViewController { self.navigationController }

	/// The wrapped `UINavigationController`.
	public let navigationController: UINavigationController

	// MARK: - Initialization

	/// Initializer.
	///
	/// - Parameter root: The root `ViewControllable` for the navigation controller.
	@MainActor
	public init(root: ViewControllable) {
		let navigation = UINavigationController(rootViewController: root.uiViewController)
		navigation.navigationBar.isTranslucent = false
		navigation.navigationBar.backgroundColor = .white
		navigation.navigationBar.scrollEdgeAppearance = navigation.navigationBar.standardAppearance

		self.navigationController = navigation
	}
}
#endif

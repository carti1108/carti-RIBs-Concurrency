//
//  PresentationDelegate.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/30/25.
//

#if canImport(UIKit)
import UIKit

/// A delegate that handles presentation lifecycle events for a `UIPresentationController`.
@MainActor
public final class PresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {

	// MARK: - Private Properties

	private let onDismiss: () -> Void
	
	private weak var presentationController: UIPresentationController?
	
	// MARK: - Initialization

	/// Initializer.
	///
	/// - Parameters:
	///   - onDismiss: The closure to execute when the presentation is dismissed.
	///   - presentationController: The presentation controller to monitor.
	public init(
		onDismiss: @escaping () -> Void,
		presentationController: UIPresentationController
	) {
		self.onDismiss = onDismiss
		self.presentationController = presentationController
		super.init()
		presentationController.delegate = self
	}
	
	// MARK: - Public Methods

	public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
		self.onDismiss()
	}
}
#endif


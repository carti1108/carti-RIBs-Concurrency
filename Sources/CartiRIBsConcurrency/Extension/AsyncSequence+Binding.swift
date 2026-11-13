//
//  AsyncSequence+Binding.swift
//  CartiRIBsConcurrency
//

// RxSwift replacement mapping:
// - RxCocoa `bind(to:)` -> `bind(to:at:)`
// - `subscribe(onNext:)` -> `bind(onNext:)`
// - `disposed(by:)` -> returned `Task` is managed via `store(in:)` or `disposeWith(workflow:)`

import Foundation

/// A set of extensions for UI binding on `AsyncSequence`.
@MainActor
public extension AsyncSequence where Element: Sendable, Self: Sendable {
	
	/// Binds the values from the async sequence to a specific key path on a target object.
	/// The binding is automatically executed on the MainActor.
	///
	/// - Parameters:
	///   - target: The object to bind to.
	///   - keyPath: The reference writable key path to update.
	/// - Returns: A Task that can be cancelled, e.g. using `cancelOnDeactivate()`.
	@discardableResult
	func bind<Target: AnyObject>(
		to target: Target,
		at keyPath: ReferenceWritableKeyPath<Target, Element>
	) -> Task<Void, Never> {
		Task { @MainActor [weak target] in
			do {
				for try await value in self {
					target?[keyPath: keyPath] = value
				}
			} catch {
				// Binding ignores errors implicitly, like RxCocoa's bind(to:).
			}
		}
	}
	
	/// Binds the values from the async sequence to a closure action.
	/// The closure is executed on the MainActor.
	///
	/// - Parameter action: The closure to execute with each emitted element.
	/// - Returns: A Task that can be cancelled.
	@discardableResult
	func bind(
		onNext action: @escaping @MainActor (Element) -> Void
	) -> Task<Void, Never> {
		Task { @MainActor in
			do {
				for try await value in self {
					action(value)
				}
			} catch {
				// Binding ignores errors implicitly
			}
		}
	}
}

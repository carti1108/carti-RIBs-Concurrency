//
//  Shared.swift
//  CartiRIBsConcurrency
//

// RxSwift replacement mapping:
// - The `shared` dictionary caching method in `Component` was removed.
// - Use the `@Shared` property wrapper instead to ensure dependencies are created exactly once.

import Foundation

/// A property wrapper used to lazily instantiate and cache shared dependencies in a Component.
/// Replaces the legacy `Component.shared { }` dictionary caching approach.
///
/// Ensures that the dependency is created exactly once on the MainActor.
@MainActor
@propertyWrapper
public struct Shared<Value> {
	private var value: Value?
	private let factory: () -> Value
	
	public init(wrappedValue: @autoclosure @escaping () -> Value) {
		self.factory = wrappedValue
	}
	
	public var wrappedValue: Value {
		mutating get {
			if let value = value {
				return value
			}
			let newValue = factory()
			self.value = newValue
			return newValue
		}
	}
}

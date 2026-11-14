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
//  Component.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 12/20/25.
//

// RxSwift replacement mapping:
// - No Rx type was used here in upstream RIBs.
// - The `shared` method was removed in favor of the new `@Shared` property wrapper.

import Foundation

/// The base class for all components.
///
/// Components provide dependency injection to the RIBs. Subclasses should
/// declare dependencies via `@Shared` property wrappers to ensure they are created exactly once.
@MainActor
open class Component<DependencyType>: Dependency {

	/// The dependency of this component.
	public let dependency: DependencyType

	/// Initializer.
	///
	/// - Parameter dependency: The dependency of this component.
	public init(dependency: DependencyType) {
		self.dependency = dependency
	}
}

/// The base class for an empty component.
@MainActor
open class EmptyComponent: EmptyDependency {

	/// Initializer.
	public init() {}
}

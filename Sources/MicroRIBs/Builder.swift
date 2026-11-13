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
//  Builder.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/20/25.
//

// RxSwift replacement mapping:
// Uber RIBs `Buildable` / `Builder` stay structurally the same here.
// The Swift Concurrency migration is the `@MainActor` isolation, which
// replaces the old "builders are called on main thread by convention" rule.

/// The base builder protocol that all builders should conform to.
@MainActor
public protocol Buildable: AnyObject {}

/// The base class for all builders.
///
/// Builders are responsible for instantiating the RIBs and their dependencies.
@MainActor
open class Builder<DependencyType>: Buildable {

	/// The dependency used to instantiate this RIB.
	public let dependency: DependencyType

	/// Initializer.
	///
	/// - Parameter dependency: The dependency used to instantiate this RIB.
	public init(dependency: DependencyType) {
		self.dependency = dependency
	}
}

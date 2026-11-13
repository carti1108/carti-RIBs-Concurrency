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
//  Presenter.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/25/25.
//

// RxSwift replacement mapping:
// - No Rx type was used here in upstream RIBs.
// - The Swift Concurrency migration here is `@MainActor` isolation only.

/// The base protocol for all `Presenter`s.
@MainActor
public protocol Presentable: AnyObject {}

/// The base class for all `Presenter`s.
@MainActor
open class Presenter<ViewControllerType>: Presentable {

	/// The `ViewController` associated with this `Presenter`.
	public let viewController: ViewControllerType

	/// Initializer.
	///
	/// - Parameter viewController: The `ViewController` associated with this `Presenter`.
	public init(viewController: ViewControllerType) {
		self.viewController = viewController
	}
}

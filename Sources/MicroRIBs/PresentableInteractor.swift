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
//  PresentableInteractor.swift
//  MicroRIBs
//
//  Created by Kiseok on 12/23/25.
//

// RxSwift replacement mapping:
// - No Rx lifecycle type was replaced in this file directly.
// - The migration here is `@MainActor` plus `isolated deinit` so the upstream
//   leak-check call remains actor-safe under Swift 6 strict concurrency.

/// The base class of all interactors that own a presenter.
@MainActor
open class PresentableInteractor<PresentableType>: Interactor {

	/// The `Presenter` owned by this interactor.
	public let presenter: PresentableType

	/// Initializer.
	///
	/// - Parameter presenter: The corresponding `Presenter` of this interactor.
	public init(presenter: PresentableType) {
		self.presenter = presenter
		super.init()
	}

	deinit {
		MainActor.assumeIsolated {
			_ = LeakDetector.instance.expectDeallocate(object: self.presenter as AnyObject)
		}
	}
}

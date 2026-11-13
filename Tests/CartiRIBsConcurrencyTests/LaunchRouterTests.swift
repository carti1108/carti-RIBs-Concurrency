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
//  LaunchRouterTests.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
#if canImport(UIKit)
import UIKit
@testable import CartiRIBsConcurrency

@Suite("LaunchRouter 테스트")
@MainActor
struct LaunchRouterTests {

	@MainActor
	final class MockInteractable: Interactable, @unchecked Sendable {
		let isActiveSubject = ActiveStateRelay(false)

		var isActive: Bool { isActiveSubject.value }
		var isActiveStream: AsyncStream<Bool> { isActiveSubject.stream }

		func observeActiveState(_ onChange: @escaping @MainActor (Bool) -> Void) -> ActiveStateObservation {
			isActiveSubject.observe(onChange)
		}

		var activateCallCount = 0
		var deactivateCallCount = 0

		func activate() {
			guard !isActive else { return }  // 중복 호출 방지
			activateCallCount += 1
			isActiveSubject.send(true)
		}

		func deactivate() {
			guard isActive else { return }  // 중복 호출 방지
			deactivateCallCount += 1
			isActiveSubject.send(false)
		}
	}

	@MainActor
	final class MockViewController: UIViewController, ViewControllable, @unchecked Sendable {
	}

	@MainActor
	final class TestLaunchRouter: LaunchRouter<MockInteractable, MockViewController> {
		var didLoadCallCount = 0

		override func didLoad() {
			super.didLoad()
			didLoadCallCount += 1
		}
	}

	@Test
	func 라우터와윈도우가있을때_launch호출시_루트뷰설정과활성화가되는지() {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		let router = TestLaunchRouter(interactor: interactor, viewController: viewController)
		let window = UIWindow()

		// when
		router.launch(from: window)

		// then
		#expect(window.rootViewController === viewController)
		#expect(window.isKeyWindow)
		#expect(interactor.activateCallCount == 1)
		#expect(router.didLoadCallCount == 1)
	}
	
	@Test
	func 라우터와윈도우가있을때_launch를여러번호출시_중복활성화와중복로드가없는지() {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		let router = TestLaunchRouter(interactor: interactor, viewController: viewController)
		let window = UIWindow()
		
		// when
		router.launch(from: window)
		router.launch(from: window)
		router.launch(from: window)
		
		// then
		#expect(interactor.activateCallCount == 1, "activate는 한 번만 호출되어야 합니다")
		#expect(router.didLoadCallCount == 1, "didLoad는 한 번만 호출되어야 합니다")
		#expect(window.rootViewController === viewController)
		#expect(window.isKeyWindow)
	}
}
#endif

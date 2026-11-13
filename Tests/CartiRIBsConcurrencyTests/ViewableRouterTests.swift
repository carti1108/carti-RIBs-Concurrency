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
//  ViewableRouterTests.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
#if canImport(UIKit)
import UIKit
@testable import CartiRIBsConcurrency

@Suite("ViewableRouter 테스트")
@MainActor
struct ViewableRouterTests {

	@MainActor
	final class MockInteractable: Interactable, @unchecked Sendable {
		let isActiveSubject = ActiveStateRelay(false)

		var isActive: Bool { isActiveSubject.value }
		var isActiveStream: AsyncStream<Bool> { isActiveSubject.stream }

		func observeActiveState(_ onChange: @escaping @MainActor (Bool) -> Void) -> ActiveStateObservation {
			isActiveSubject.observe(onChange)
		}

		func activate() { isActiveSubject.send(true) }
		func deactivate() { isActiveSubject.send(false) }

		func setActive(_ value: Bool) {
			isActiveSubject.send(value)
		}
	}

	@MainActor
	final class MockViewController: UIViewController, ViewControllable, @unchecked Sendable {
		var uiViewControllerAccessCount = 0

		var uiViewController: UIViewController {
			uiViewControllerAccessCount += 1
			return self
		}
	}

	@MainActor
	final class TestViewableRouter: ViewableRouter<MockInteractable, MockViewController> {
	}

	@MainActor
	final class NoSuperDidLoadRouter: ViewableRouter<MockInteractable, MockViewController> {
		var didLoadCallCount = 0

		override func didLoad() {
			didLoadCallCount += 1
		}
	}

	@Test
	func 인터랙터와뷰컨트롤러가있을때_초기화시_참조가정상설정되는지() {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()

		// when
		let router = TestViewableRouter(interactor: interactor, viewController: viewController)

		// then
		#expect(router.viewControllable === viewController)
		#expect(router.viewController === viewController)
	}

	@Test
	func 라우터가로드된상태에서_인터랙터가비활성화되면_뷰누수감지바인딩이동작하는지() async {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		let router = TestViewableRouter(interactor: interactor, viewController: viewController)

		// when
		router.load()
		interactor.setActive(true)
		try? await Task.sleep(nanoseconds: 10_000_000)

		interactor.setActive(false)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(viewController.uiViewControllerAccessCount > 0)
	}

	@Test
	func 라우터가로드된상태에서_인터랙터가활성화되면_뷰누수감지예약이취소되는지() async {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		let router = TestViewableRouter(interactor: interactor, viewController: viewController)
		router.load()
		let initialCount = viewController.uiViewControllerAccessCount

		// when
		interactor.setActive(true)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(viewController.uiViewControllerAccessCount == initialCount)
	}

	@Test
	func 인터랙터상태가_활성에서비활성후활성으로변할때_누수감지예약이재설정되는지() async {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		let router = TestViewableRouter(interactor: interactor, viewController: viewController)
		router.load()

		interactor.setActive(true)
		try? await Task.sleep(nanoseconds: 10_000_000)

		interactor.setActive(false)
		try? await Task.sleep(nanoseconds: 10_000_000)

		let countAfterInactive = viewController.uiViewControllerAccessCount
		#expect(countAfterInactive > 0)
		
		interactor.setActive(true)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(viewController.uiViewControllerAccessCount == countAfterInactive)
	}

	@Test
	func 뷰어블라우터가해제될때_정상해제되는지() async {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		weak var weakRouter: TestViewableRouter?
		do {
			let router = TestViewableRouter(interactor: interactor, viewController: viewController)
			router.load()
			weakRouter = router
		}

		// when: 바인딩이 실행될 기회를 줌
		await Task.yield()

		// then
		#expect(weakRouter == nil)
	}

	@Test
	func didLoad에서super를호출하지않아도_로드호출시_누수감지바인딩이유지되는지() async {
		// given
		let interactor = MockInteractable()
		let viewController = MockViewController()
		let router = NoSuperDidLoadRouter(interactor: interactor, viewController: viewController)

		// when
		router.load()
		interactor.setActive(false)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(router.didLoadCallCount == 1)
		#expect(viewController.uiViewControllerAccessCount > 0)
	}

	@Test
	func 뷰컨트롤러가있을때_uiviewController별칭호출시_동일인스턴스를반환하는지() {
		// given
		let viewController = MockViewController()

		// then
		#expect(viewController.uiviewController === viewController)
	}
}
#endif

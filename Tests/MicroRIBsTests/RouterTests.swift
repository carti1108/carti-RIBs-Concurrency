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
//  RouterTests.swift
//  MicroRIBsTests
//
//  Created by Kiseok on 1/10/26.
//

import Testing
import Foundation
@testable import MicroRIBs

@Suite("Router 기본 기능 및 트리 상태 전파 테스트")
@MainActor
struct RouterTests {
	
	// MARK: - Mocks (Spy)
	@MainActor
	final class MockInteractable: Interactable, @unchecked Sendable {
		var isActive: Bool { isActiveSubject.value }
		var isActiveStream: AsyncStream<Bool> { isActiveSubject.stream }

		func observeActiveState(_ onChange: @escaping @MainActor (Bool) -> Void) -> ActiveStateObservation {
			isActiveSubject.observe(onChange)
		}
		
		let isActiveSubject = ActiveStateRelay(false)
		
		var activateCallCount = 0
		var deactivateCallCount = 0
		
		func activate() {
			guard !isActive else { return }
			activateCallCount += 1
			isActiveSubject.send(true)
		}
		
		func deactivate() {
			guard isActive else { return }
			deactivateCallCount += 1
			isActiveSubject.send(false)
		}
	}
	
	@MainActor
	final class TestRouter: Router<MockInteractable>, @unchecked Sendable {
		var didLoadCallCount = 0
		
		override func didLoad() {
			super.didLoad()
			didLoadCallCount += 1
		}
	}
	
	// MARK: - Tests
	
	@Test
	func 부모라우터와자식라우터가있을때_attachChild호출시_자식이활성화되고로드되는지() {
		// given
		let interactor = MockInteractable()
		let router = TestRouter(interactor: interactor)
		
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		
		// when
		router.attachChild(childRouter)
		
		// then
		#expect(router.children.count == 1)
		#expect(router.children.first === childRouter)
		#expect(childInteractor.activateCallCount == 1)
	}
	
	@Test
	func 부모라우터에자식이붙어있을때_detachChild호출시_자식이비활성화되는지() {
		// given
		let router = TestRouter(interactor: MockInteractable())
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		
		router.attachChild(childRouter)
		
		// when
		router.detachChild(childRouter)
		
		// then
		#expect(router.children.isEmpty)
		#expect(childInteractor.deactivateCallCount == 1)
	}

	@Test
	func 자식라우터에하위트리가있을때_detachChild호출시_부모에서만제거되고하위트리는유지되는지() async {
		// given
		let parentRouter = TestRouter(interactor: MockInteractable())
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		let grandchildInteractor = MockInteractable()
		let grandchildRouter = TestRouter(interactor: grandchildInteractor)

		childRouter.attachChild(grandchildRouter)
		parentRouter.attachChild(childRouter)
		parentRouter.load()
		childInteractor.activate()
		try? await Task.sleep(nanoseconds: 10_000_000)

		// when
		parentRouter.detachChild(childRouter)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(parentRouter.children.isEmpty)
		#expect(childRouter.children.count == 1)
		#expect(childRouter.children.first === grandchildRouter)
		#expect(childInteractor.isActive == false)
		#expect(grandchildInteractor.isActive == false)
	}
	
	@Test
	func 부모라우터트리가로드된상태에서_부모활성상태가바뀌면_자식트리도같이변하는지() async {
		// given
		let parentInteractor = MockInteractable()
		let parentRouter = TestRouter(interactor: parentInteractor)
		
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		
		parentRouter.attachChild(childRouter)
		parentInteractor.activate()
		parentRouter.load()

		try? await Task.sleep(nanoseconds: 10_000_000)
		
		#expect(childInteractor.isActive == true)
		
		parentInteractor.deactivate()
		
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(childInteractor.isActive == false, "부모가 꺼지면 자식도 꺼져야 합니다")
		
		// when
		parentInteractor.activate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(childInteractor.isActive == true, "부모가 켜지면 자식도 켜져야 합니다")
	}
	
	@Test
	func 자식이붙은라우터가해제될때_자신과자식인터랙터가정리되는지() async {
		// given
		let interactor = MockInteractable()
		var router: TestRouter? = TestRouter(interactor: interactor)
		
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		
		interactor.activate()
		router?.attachChild(childRouter)
		
		// when
		router = nil
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(interactor.deactivateCallCount == 1, "부모 Interactor가 deactivate되어야 함")
		#expect(childInteractor.deactivateCallCount == 1, "자식 Interactor도 deactivate되어야 함")
	}
	
	@Test
	func 라우터가있을때_load를여러번호출시_didLoad가한번만호출되는지() {
		// given
		let interactor = MockInteractable()
		let router = TestRouter(interactor: interactor)
		
		// when
		router.load()
		router.load()
		router.load()
		
		// then
		#expect(router.didLoadCallCount == 1, "didLoad는 한 번만 호출되어야 합니다")
	}
	
	@Test
	func 라우터가로드될때_lifecycle스트림이_didLoad이벤트를방출하는지() async {
		// given
		let interactor = MockInteractable()
		let router = TestRouter(interactor: interactor)
		
		var receivedEvents: [RouterLifecycle] = []
		let task = Task {
			for await event in router.lifecycle {
				receivedEvents.append(event)
				break
			}
		}

		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// when
		router.load()
		try? await Task.sleep(nanoseconds: 10_000_000)
		task.cancel()
		
		// then
		#expect(receivedEvents.contains(.didLoad), "lifecycle 스트림은 didLoad 이벤트를 방출해야 합니다")
	}

	@Test
	func 라우터가해제될때_lifecycle스트림이종료되는지() async {
		// given
		let interactor = MockInteractable()
		var router: TestRouter? = TestRouter(interactor: interactor)
		let lifecycle = router!.lifecycle

		// when
		router = nil

		// then
		var finished = false
		for await _ in lifecycle { }
		finished = true
		#expect(finished)
	}
	
	@Test
	func 삼단계라우터트리가있을때_최상위활성상태변경이전체하위트리에전파되는지() async {
		// given
		let grandparentInteractor = MockInteractable()
		let grandparentRouter = TestRouter(interactor: grandparentInteractor)
		
		let parentInteractor = MockInteractable()
		let parentRouter = TestRouter(interactor: parentInteractor)
		
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		
		grandparentRouter.attachChild(parentRouter)
		parentRouter.attachChild(childRouter)

		grandparentInteractor.activate()
		grandparentRouter.load()

		try? await Task.sleep(nanoseconds: 10_000_000)
		
		#expect(grandparentInteractor.isActive == true)
		#expect(parentInteractor.isActive == true)
		#expect(childInteractor.isActive == true)
		
		// when
		grandparentInteractor.deactivate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(grandparentInteractor.isActive == false)
		#expect(parentInteractor.isActive == false)
		#expect(childInteractor.isActive == false, "손자까지 모두 비활성화되어야 합니다")
		
		// when
		grandparentInteractor.activate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(grandparentInteractor.isActive == true)
		#expect(parentInteractor.isActive == true)
		#expect(childInteractor.isActive == true, "손자까지 모두 다시 활성화되어야 합니다")
	}

	@Test
	func 부모인터랙터가비활성화되면_반환전에손자까지동기로비활성화되는지() {
		// given
		let parentInteractor = MockInteractable()
		let parentRouter = TestRouter(interactor: parentInteractor)
		let childInteractor = MockInteractable()
		let childRouter = TestRouter(interactor: childInteractor)
		let grandchildInteractor = MockInteractable()
		let grandchildRouter = TestRouter(interactor: grandchildInteractor)
		parentInteractor.activate()
		parentRouter.load()
		parentRouter.attachChild(childRouter)
		childRouter.attachChild(grandchildRouter)

		// when
		parentInteractor.deactivate()

		// then: 기다리지 않아도 이미 반영되어 있어야 함
		#expect(childInteractor.isActive == false)
		#expect(grandchildInteractor.isActive == false)

		// when
		parentInteractor.activate()

		// then
		#expect(childInteractor.isActive == true)
		#expect(grandchildInteractor.isActive == true)
	}

	@Test
	func 부모활성상태가빠르게토글되면_자식생명주기가빠짐없이호출되는지() {
		// given
		let parentInteractor = MockInteractable()
		let parentRouter = TestRouter(interactor: parentInteractor)
		let childInteractor = MockInteractable()
		parentInteractor.activate()
		parentRouter.load()
		parentRouter.attachChild(TestRouter(interactor: childInteractor))

		// when
		parentInteractor.deactivate()
		parentInteractor.activate()

		// then
		#expect(childInteractor.deactivateCallCount == 1)
		#expect(childInteractor.activateCallCount == 2)
	}

	@Test
	func 로드된라우터를놓으면_활성상태관찰때문에남지않고해제되는지() async {
		// given
		weak var weakRouter: TestRouter?
		do {
			let router = TestRouter(interactor: MockInteractable())
			router.interactable.activate()
			router.load()
			weakRouter = router
		}

		// when: 이전 구현에서 바인딩 Task가 실행될 기회를 줌
		await Task.yield()

		// then
		#expect(weakRouter == nil)
	}
}

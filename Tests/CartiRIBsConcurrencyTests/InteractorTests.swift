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
//  InteractorTests.swift
//  CartiRIBsConcurrencyTests
//
//  Created by Kiseok on 1/10/26.
//

import Testing
import Foundation
import AsyncAlgorithms
@testable import CartiRIBsConcurrency

@Suite("Interactor 테스트")
@MainActor
struct InteractorTests {
	
	@MainActor
	final class MockInteractor: Interactor, @unchecked Sendable {
		var didBecomeActiveCallCount = 0
		var willResignActiveCallCount = 0
		
		override func didBecomeActive() {
			super.didBecomeActive()
			didBecomeActiveCallCount += 1
		}
		
		override func willResignActive() {
			super.willResignActive()
			willResignActiveCallCount += 1
		}
	}
	
	@Test
	func 비활성인터랙터가있을때_activate호출시_활성상태와콜백이변경되는지() {
		// given
		let interactor = MockInteractor()
		
		// when
		interactor.activate()
		
		// then
		#expect(interactor.isActive == true)
		#expect(interactor.didBecomeActiveCallCount == 1)
		#expect(interactor.willResignActiveCallCount == 0)
	}
	
	@Test
	func 활성인터랙터가있을때_deactivate호출시_비활성상태와콜백이변경되는지() {
		// given
		let interactor = MockInteractor()
		interactor.activate()
		
		// when
		interactor.deactivate()
		
		// then
		#expect(interactor.isActive == false)
		#expect(interactor.didBecomeActiveCallCount == 1)
		#expect(interactor.willResignActiveCallCount == 1)
	}
	
	@Test
	func 이미활성화된인터랙터가있을때_activate를다시호출시_중복콜백이발생하지않는지() {
		// given
		let interactor = MockInteractor()
		interactor.activate()
		
		// when
		interactor.activate()
		
		// then
		#expect(interactor.didBecomeActiveCallCount == 1)
	}
	
	@Test
	func 활성인터랙터와태스크가있을때_cancelOnDeactivate호출후비활성화하면_태스크가취소되는지() async {
		// given
		let interactor = Interactor()
		interactor.activate()
		
		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}
		task.cancelOnDeactivate(interactor: interactor)
		
		// when
		interactor.deactivate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(task.isCancelled == true)
	}
	
	@Test
	func 비활성인터랙터가있을때_cancelOnDeactivate호출시_태스크가즉시취소되는지() async {
		// given
		let interactor = Interactor()
		let task = Task {
			try? await Task.sleep(nanoseconds: 1_000_000_000)
		}
		
		// when
		task.cancelOnDeactivate(interactor: interactor)
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(task.isCancelled == true)
	}

	@Test
	func 활성인터랙터와태스크가있을때_disposeOnDeactivate호출후비활성화하면_태스크가취소되는지() async {
		// given
		let interactor = Interactor()
		interactor.activate()

		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}

		// when
		task.disposeOnDeactivate(interactor: interactor)
		interactor.deactivate()
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true)
	}
	
	@Test
	func 비활성구간과활성구간이섞인스트림이있을때_confineTo호출시_활성중값만전달되는지() async {
		// given
		let interactor = Interactor()
		let (stream, continuation) = AsyncStream<Int>.makeStream()
		let task = Task {
			var values: [Int] = []
			for await value in stream.confineTo(interactor) {
				values.append(value)
			}
			return values
		}
		
		// when
		continuation.yield(1)
		try? await Task.sleep(nanoseconds: 10_000_000)
		interactor.activate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		continuation.yield(2)
		try? await Task.sleep(nanoseconds: 10_000_000)
		interactor.deactivate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		continuation.yield(3)
		task.cancel()
		
		// then
		let receivedValues = await task.value
		
		#expect(receivedValues.contains(2))
		#expect(!receivedValues.contains(3))
	}
	
	@Test
	func 활성화직전값과활성중값이있을때_confineTo호출시_combineLatest의미로전달되는지() async {
		// given
		let interactor = Interactor()
		let (stream, continuation) = AsyncStream<Int>.makeStream(bufferingPolicy: .unbounded)
		
		let task = Task {
			var values: [Int] = []
			for await value in stream.confineTo(interactor) {
				values.append(value)
			}
			return values
		}
		
		// when
		continuation.yield(1)
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		interactor.activate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		continuation.yield(2)
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		interactor.deactivate()
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		continuation.yield(3)
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		task.cancel()
		
		// then
		let result = await task.value
		#expect(result == [1, 2], "활성화 시점의 최신값(1)과 활성 중 받은 값(2)이 들어와야 함. 실제값: \(result)")
	}
	
	@Test
	func 활성인터랙터가해제될때_isActiveStream이종료되는지() async {
		// given
		var interactor: MockInteractor? = MockInteractor()
		interactor?.activate()
		let stream = interactor!.isActiveStream
		
		// when
		interactor = nil
		
		// then
		var finished = false
		for await _ in stream { }
		finished = true
		
		#expect(finished)
	}
}

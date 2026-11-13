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
//  WorkerTests.swift
//  MicroRIBs
//
//  Created by Kiseok on 1/27/26.
//

import Testing
import Foundation
@testable import MicroRIBs

@Suite("Worker 테스트")
@MainActor
struct WorkerTests {

	@MainActor
	final class MockInteractorScope: InteractorScope, @unchecked Sendable {
		let isActiveSubject = ActiveStateRelay(false)

		var isActive: Bool { isActiveSubject.value }
		var isActiveStream: AsyncStream<Bool> { isActiveSubject.stream }

		func observeActiveState(_ onChange: @escaping @MainActor (Bool) -> Void) -> ActiveStateObservation {
			isActiveSubject.observe(onChange)
		}

		func setActive(_ value: Bool) {
			isActiveSubject.send(value)
		}
	}

	@MainActor
	final class TestWorker: Worker, @unchecked Sendable {
		var didStartCallCount = 0
		var didStopCallCount = 0

		override func didStart(_ interactorScope: InteractorScope) {
			super.didStart(interactorScope)
			didStartCallCount += 1
		}

		override func didStop() {
			super.didStop()
			didStopCallCount += 1
		}
	}

	@Test
	func 활성인터랙터스코프가있을때_start호출시_didStart가실행되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)
		let worker = TestWorker()

		// when
		worker.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(worker.isStarted == true)
		#expect(worker.didStartCallCount == 1)
		#expect(worker.didStopCallCount == 0)
	}

	@Test
	func 비활성인터랙터스코프가있을때_start호출후활성화되면_didStart가실행되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(false)
		let worker = TestWorker()

		worker.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		#expect(worker.didStartCallCount == 0)

		// when
		interactorScope.setActive(true)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(worker.didStartCallCount == 1)
	}

	@Test
	func 시작된워커가있을때_인터랙터활성상태가토글되면_stop과restart가반영되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)
		let worker = TestWorker()
		worker.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// when
		interactorScope.setActive(false)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(worker.didStopCallCount == 1)
		#expect(worker.isStarted == true)

		// when
		interactorScope.setActive(true)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(worker.didStartCallCount == 2)
	}

	@Test
	func 시작된워커가있을때_stop호출시_중지상태와didStop이반영되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)
		let worker = TestWorker()
		worker.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// when
		worker.stop()

		// then
		#expect(worker.isStarted == false)
		#expect(worker.didStopCallCount == 1)
	}

	@Test
	func 시작된워커와태스크가있을때_cancelOnStop호출후stop하면_태스크가취소되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)
		let worker = TestWorker()
		worker.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}

		// when
		task.cancelOnStop(worker)
		worker.stop()
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true)
	}

	@Test
	func 정지된워커가있을때_cancelOnStop호출시_태스크가즉시취소되는지() async {
		// given
		let worker = TestWorker()

		let task = Task {
			try? await Task.sleep(nanoseconds: 1_000_000_000)
		}

		// when
		task.cancelOnStop(worker)
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true)
	}

	@Test
	func 시작된워커와태스크가있을때_disposeOnStop호출후stop하면_태스크가취소되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)
		let worker = TestWorker()
		worker.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}

		// when
		task.disposeOnStop(worker)
		worker.stop()
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true)
	}

	@Test
	func 시작된워커가해제될때_isStartedStream이종료되는지() async {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)

		var worker: TestWorker? = TestWorker()
		worker?.start(interactorScope)
		try? await Task.sleep(nanoseconds: 10_000_000)

		let isStartedStream = worker!.isStartedStream

		// when
		worker = nil

		// then
		var finished = false
		for await _ in isStartedStream { }
		finished = true

		#expect(finished)
	}

	@Test
	func 인터랙터가빠르게토글되면_didStop과didStart가반환전에모두호출되는지() {
		// given
		let interactorScope = MockInteractorScope()
		interactorScope.setActive(true)
		let worker = TestWorker()
		worker.start(interactorScope)

		// when
		interactorScope.setActive(false)
		interactorScope.setActive(true)

		// then
		#expect(worker.didStopCallCount == 1)
		#expect(worker.didStartCallCount == 2)
	}
}

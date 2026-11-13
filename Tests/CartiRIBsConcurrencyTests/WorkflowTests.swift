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
//  WorkflowTests.swift
//  CartiRIBsConcurrencyTests
//
//  Created by Kiseok on 4/9/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("Workflow 테스트")
@MainActor
struct WorkflowTests {

	@MainActor
	final class TestWorkflow<ActionableItemType>: Workflow<ActionableItemType> {
		var didCompleteCallCount = 0
		var didForkCallCount = 0
		var receivedErrors: [String] = []

		override func didComplete() {
			didCompleteCallCount += 1
		}

		override func didFork() {
			didForkCallCount += 1
		}

		override func didReceiveError(_ error: Error) {
			receivedErrors.append(String(describing: error))
		}
	}

	@MainActor
	final class MockInteractable: Interactor, @unchecked Sendable {
	}

	final class MockCancellable: AnyCancellableTask, @unchecked Sendable {
		var isCancelled = false

		func cancel() {
			isCancelled = true
		}
	}

	private enum TestError: Error {
		case failure
	}

	@Test
	func 커밋된워크플로우가있을때_subscribe호출시_step체인이순서대로실행되는지() async {
		// given
		let workflow = TestWorkflow<String>()
		var visitedSteps: [String] = []

		workflow
			.onStep { root in
				visitedSteps.append("root:\(root)")
				return ("child", 1)
			}
			.onStep { actionableItem, value in
				visitedSteps.append("\(actionableItem):\(value)")
				return ("done", value + 1)
			}
			.commit()

		// when
		let task = workflow.subscribe("start")
		_ = await task.result

		// then
		#expect(visitedSteps == ["root:start", "child:1"])
		#expect(workflow.didCompleteCallCount == 1)
		#expect(workflow.receivedErrors.isEmpty)
	}

	@Test
	func 다음액셔너블아이템이인터랙터블일때_subscribe호출시_활성화될때까지다음step을대기하는지() async {
		// given
		let workflow = TestWorkflow<String>()
		let nextInteractable = MockInteractable()
		var secondStepRan = false

		workflow
			.onStep { _ in
				return (nextInteractable, "payload")
			}
			.onStep { actionableItem, value in
				secondStepRan = true
				return (actionableItem, value)
			}
			.commit()

		// when
		let task = workflow.subscribe("root")
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(secondStepRan == false)

		// when
		nextInteractable.activate()
		_ = await task.result

		// then
		#expect(secondStepRan == true)
		#expect(workflow.didCompleteCallCount == 1)
	}

	@Test
	func 스텝에러가발생할수있는워크플로우가있을때_subscribe호출시_onError와didReceiveError가호출되는지() async {
		// given
		let workflow = TestWorkflow<String>()
		var capturedError = false

		workflow
			.onStep { _ -> (String, Int) in
				throw TestError.failure
			}
			.onError { _ in
				capturedError = true
			}
			.commit()

		// when
		let task = workflow.subscribe("root")
		_ = await task.result

		// then
		#expect(capturedError == true)
		#expect(workflow.receivedErrors.count == 1)
		#expect(workflow.didCompleteCallCount == 0)
	}

	@Test
	func 포크가능한워크플로우가있을때_fork후각브랜치를커밋하면_같은워크플로우에서모두실행되는지() async {
		// given
		let workflow = TestWorkflow<String>()
		var firstBranchRan = false
		var secondBranchRan = false

		let baseStep = workflow.onStep { root in
			return (root, 1)
		}

		baseStep
			.onStep { actionableItem, value in
				firstBranchRan = true
				return (actionableItem, value + 1)
			}
			.commit()

		baseStep
			.fork()
			.onStep { actionableItem, value in
				secondBranchRan = true
				return (actionableItem, value + 10)
			}
			.commit()

		// when
		let task = workflow.subscribe("root")
		_ = await task.result

		// then
		#expect(firstBranchRan == true)
		#expect(secondBranchRan == true)
		#expect(workflow.didForkCallCount == 1)
		#expect(workflow.didCompleteCallCount == 1)
	}

	@Test
	func 외부태스크가워크플로우에묶여있을때_워크플로우해제시_태스크가취소되는지() async {
		// given
		var workflow: TestWorkflow<String>? = TestWorkflow<String>()
		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}

		// when
		task.disposeWith(workflow: workflow!)
		workflow = nil
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true)
	}

	@Test
	func 외부캔슬러블이워크플로우에묶여있을때_워크플로우해제시_취소되는지() async {
		// given
		var workflow: TestWorkflow<String>? = TestWorkflow<String>()
		let cancellable = MockCancellable()

		// when
		cancellable.disposeWith(workflow: workflow!)
		workflow = nil
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(cancellable.isCancelled == true)
	}

}

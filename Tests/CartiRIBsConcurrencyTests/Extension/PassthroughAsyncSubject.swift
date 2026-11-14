//
//  PassthroughAsyncSubject.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("PassthroughAsyncSubject 테스트")
@MainActor
struct PassthroughAsyncSubjectTests {
	
	@Test
	func 구독중인PassthroughAsyncSubject가있을때_send호출시_구독이후값만전달되는지() async {
		// given
		let subject = PassthroughAsyncSubject<Int>()
		var receivedValues: [Int] = []
		
		let task = Task {
			for await value in subject.stream {
				receivedValues.append(value)
			}
			return receivedValues
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		subject.send(1)
		subject.send(2)
		subject.finish()
		
		let result = await task.value
		
		// then
		#expect(result == [1, 2])
	}
	
	@Test
	func 다수의구독자가있는PassthroughAsyncSubject가있을때_send호출시_모두같은값을받는지() async {
		// given
		let subject = PassthroughAsyncSubject<String>()
		
		let task1 = Task {
			var values: [String] = []
			for await value in subject.stream {
				values.append(value)
			}
			return values
		}
		
		let task2 = Task {
			var values: [String] = []
			for await value in subject.stream {
				values.append(value)
			}
			return values
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		subject.send("Event")
		subject.finish()
		
		let result1 = await task1.value
		let result2 = await task2.value
		
		// then
		#expect(result1 == ["Event"])
		#expect(result2 == ["Event"])
	}
	
	@Test
	func 구독중인PassthroughAsyncSubject가있을때_finish호출시_정상종료되는지() async {
		// given
		let subject = PassthroughAsyncSubject<Int>()
		var finished = false
		
		let task = Task {
			for await _ in subject.stream {}
			finished = true
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		subject.finish()
		
		_ = await task.result
		
		// then
		#expect(finished)
	}
	
	@Test
	func 종료된PassthroughAsyncSubject가있을때_새로구독하면_즉시종료되는지() async {
		// given
		let subject = PassthroughAsyncSubject<Int>()
		subject.finish()
		
		// when
		var receivedCount = 0
		for await _ in subject.stream {
			receivedCount += 1
		}
		
		// then
		#expect(receivedCount == 0)
	}
	
	@Test
	func 종료된PassthroughAsyncSubject가있을때_send호출시_값이무시되는지() async {
		// given
		let subject = PassthroughAsyncSubject<Int>()
		var receivedValues: [Int] = []
		
		let task = Task {
			for await value in subject.stream {
				receivedValues.append(value)
			}
			return receivedValues
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		subject.send(1)
		subject.finish()
		subject.send(2)
		
		let result = await task.value
		
		// then
		#expect(result == [1])
	}
	
	@Test
	func 패스스루서브젝트가해제될때_구독스트림이종료되는지() async {
		// given
		var subject: PassthroughAsyncSubject<Int>? = PassthroughAsyncSubject()
		let observedStream = subject!.stream
		var finished = false
		
		let task = Task {
			for await _ in observedStream { }
			finished = true
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		subject = nil
		
		_ = await task.result
		
		// then
		#expect(finished)
	}
}

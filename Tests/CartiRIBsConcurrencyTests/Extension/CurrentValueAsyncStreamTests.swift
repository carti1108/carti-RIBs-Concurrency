//
//  CurrentValueAsyncStreamTests.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("CurrentValueAsyncStream 테스트")
@MainActor
struct CurrentValueAsyncStreamTests {
	
	@Test
	func 초기값이있는CurrentValueAsyncStream이있을때_value조회시_초기값을반환하는지() {
		// given
		let stream = CurrentValueAsyncStream(10)
		
		// then
		#expect(stream.value == 10)
	}
	
	@Test
	func 구독중인CurrentValueAsyncStream이있을때_send호출시_초기값과업데이트값을순서대로받는지() async {
		// given
		let stream = CurrentValueAsyncStream(0)
		var receivedValues: [Int] = []
		
		let task = Task {
			for await value in stream.stream {
				receivedValues.append(value)
				if value == 2 { break }
			}
			return receivedValues
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		stream.send(1)
		stream.send(2)
		
		let result = await task.value
		
		// then
		#expect(result == [0, 1, 2])
		#expect(stream.value == 2)
	}
	
	@Test
	func 다수의구독자가있는CurrentValueAsyncStream이있을때_send호출시_모두같은값을받는지() async {
		// given
		let stream = CurrentValueAsyncStream("A")
		
		let task1 = Task {
			var values: [String] = []
			for await value in stream.stream {
				values.append(value)
			}
			return values
		}
		
		let task2 = Task {
			var values: [String] = []
			for await value in stream.stream {
				values.append(value)
			}
			return values
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		stream.send("B")
		stream.finish()
		
		let result1 = await task1.value
		let result2 = await task2.value
		
		// then
		#expect(result1 == ["A", "B"])
		#expect(result2 == ["A", "B"])
	}
	
	@Test
	func 구독중인CurrentValueAsyncStream이있을때_finish호출시_정상종료되는지() async {
		// given
		let stream = CurrentValueAsyncStream(1)
		var finished = false
		
		let task = Task {
			for await _ in stream.stream {}
			finished = true
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		stream.finish()
		
		_ = await task.result
		
		// then
		#expect(finished)
	}
	
	@Test
	func 종료된CurrentValueAsyncStream이있을때_새로구독하면_즉시종료되는지() async {
		// given
		let stream = CurrentValueAsyncStream(1)
		stream.finish()
		
		// when
		var receivedCount = 0
		for await _ in stream.stream {
			receivedCount += 1
		}
		
		// then
		#expect(receivedCount == 0)
	}
	
	@Test
	func 종료된CurrentValueAsyncStream이있을때_send호출시_값이무시되는지() async {
		// given
		let stream = CurrentValueAsyncStream(1)
		var values: [Int] = []
		
		let task = Task {
			for await value in stream.stream {
				values.append(value)
			}
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		stream.finish()
		stream.send(2)
		
		_ = await task.result
		
		// then
		#expect(values == [1])
	}
	
	@Test
	func 현재값스트림이해제될때_구독스트림이종료되는지() async {
		// given
		var stream: CurrentValueAsyncStream<Int>? = CurrentValueAsyncStream(100)
		let observedStream = stream!.stream
		var finished = false
		
		let task = Task {
			for await _ in observedStream {}
			finished = true
		}
		
		try? await Task.sleep(nanoseconds: 1_000_000)
		
		// when
		stream = nil
		
		_ = await task.result
		
		// then
		#expect(finished)
	}
}

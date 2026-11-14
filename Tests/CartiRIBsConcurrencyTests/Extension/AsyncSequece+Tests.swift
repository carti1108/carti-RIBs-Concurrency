//
//  AsyncSequece+Tests.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("AsyncSequence Extension 테스트")
struct AsyncSequenceExtensionTests {
	
	@Test
	func 값이있는AsyncSequence가있을때_eraseToStream호출시_순서대로전달되는지() async {
		// given
		let sourceStream = AsyncStream<Int> { continuation in
			continuation.yield(1)
			continuation.yield(2)
			continuation.yield(3)
			continuation.finish()
		}
		
		// when
		let erasedStream = sourceStream.eraseToStream()
		
		// then
		var result: [Int] = []
		for await value in erasedStream {
			result.append(value)
		}
		
		#expect(result == [1, 2, 3], "소스 시퀀스의 값이 순서대로 전달되어야 합니다.")
	}
	
	@Test
	func 에러가발생하는AsyncThrowingStream이있을때_eraseToStream호출시_에러없이종료되는지() async {
		// given
		let sourceStream = AsyncThrowingStream<Int, Error> { continuation in
			continuation.yield(100)
			continuation.finish(throwing: NSError(domain: "TestError", code: -1))
		}
		
		// when
		let erasedStream = sourceStream.eraseToStream()
		
		// then
		var result: [Int] = []
		for await value in erasedStream {
			result.append(value)
		}
		
		#expect(result == [100], "에러 발생 전의 값은 전달되고, 에러 발생 시 스트림이 종료되어야 합니다.")
	}
	
	@Test
	func 외부태스크가취소될때_eraseToStream내부구독도종료되는지() async {
		// given
		await confirmation("Source stream should be terminated", expectedCount: 1) { confirm in
			let sourceStream = AsyncStream<Int> { continuation in
				continuation.onTermination = { _ in
					confirm()
				}
				
				continuation.yield(1)
			}
			
			let erasedStream = sourceStream.eraseToStream()
			
			// when
			let consumeTask = Task {
				for await _ in erasedStream {
					
				}
			}
			
			while consumeTask.isCancelled == false {
				await Task.yield()
				try? await Task.sleep(nanoseconds: 1_000_000)
				consumeTask.cancel()
			}
		}
	}
}

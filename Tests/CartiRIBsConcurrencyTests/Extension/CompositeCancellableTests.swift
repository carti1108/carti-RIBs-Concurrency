//
//  CompositeCancellableTests.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("CompositeCancellable 테스트")
@MainActor
struct CompositeCancellableTests {
	
	final class MockCancellable: AnyCancellableTask, @unchecked Sendable {
		var isCancelled = false
		
		func cancel() {
			isCancelled = true
		}
	}
	
	@Test
	func 여러작업이있는CompositeCancellable이있을때_cancel호출시_모든작업이취소되는지() {
		// given
		let composite = CompositeCancellable()
		let task1 = MockCancellable()
		let task2 = MockCancellable()
		
		composite.insert(task1)
		composite.insert(task2)
		
		// when
		composite.cancel()
		
		// then
		#expect(task1.isCancelled)
		#expect(task2.isCancelled)
	}
	
	@Test
	func 이미취소된CompositeCancellable이있을때_insert호출시_즉시취소되는지() {
		// given
		let composite = CompositeCancellable()
		composite.cancel()
		
		let task = MockCancellable()
		
		// when
		composite.insert(task)
		
		// then
		#expect(task.isCancelled)
	}
	
	@Test
	func 여러작업이있는CompositeCancellable이있을때_remove호출시_해당작업만취소되는지() {
		// given
		let composite = CompositeCancellable()
		let task1 = MockCancellable()
		let task2 = MockCancellable()
		
		let key1 = composite.insert(task1)
		composite.insert(task2)
		
		// when
		composite.remove(for: key1)
		
		// then
		#expect(task1.isCancelled)
		#expect(!task2.isCancelled)
	}
	
	@Test
	func 작업이있는CompositeCancellable이해제될때_모든작업이취소되는지() {
		// given
		var composite: CompositeCancellable? = CompositeCancellable()
		let task = MockCancellable()
		composite?.insert(task)
		
		// when
		composite = nil
		
		// then
		#expect(task.isCancelled)
	}
}

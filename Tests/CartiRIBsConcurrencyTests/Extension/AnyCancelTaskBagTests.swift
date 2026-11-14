//
//  AnyCancelTaskBagTests.swift
//  CartiRIBsConcurrency
//
//  Created by Kiseok on 1/27/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("AnyCancelTaskBag 테스트")
struct AnyCancelTaskBagTests {

	@Test
	func 태스크가담긴백이해제될때_내부태스크가취소되는지() async throws {
		// given
		var bag: AnyCancelTaskBag? = AnyCancelTaskBag()

		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}
		task.store(in: bag!)

		// when
		bag = nil
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true, "가방이 nil이 되면 태스크는 취소되어야 함")
	}
	
	@Test
	func 여러태스크가담긴백이해제될때_모든태스크가취소되는지() async {
		// given
		var bag: AnyCancelTaskBag? = AnyCancelTaskBag()
		
		let task1 = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}
		
		let task2 = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}
		
		let task3 = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}
		
		task1.store(in: bag!)
		task2.store(in: bag!)
		task3.store(in: bag!)
		
		// when
		bag = nil
		try? await Task.sleep(nanoseconds: 10_000_000)
		
		// then
		#expect(task1.isCancelled == true, "첫 번째 Task가 취소되어야 함")
		#expect(task2.isCancelled == true, "두 번째 Task가 취소되어야 함")
		#expect(task3.isCancelled == true, "세 번째 Task가 취소되어야 함")
	}

	@Test
	func 태스크를disposeWith별칭으로백에담았을때_백해제시태스크가취소되는지() async {
		// given
		var bag: AnyCancelTaskBag? = AnyCancelTaskBag()

		let task = Task {
			while !Task.isCancelled {
				try? await Task.sleep(nanoseconds: 10_000_000)
			}
		}

		// when
		task.disposeWith(bag!)
		bag = nil
		try? await Task.sleep(nanoseconds: 10_000_000)

		// then
		#expect(task.isCancelled == true)
	}
}

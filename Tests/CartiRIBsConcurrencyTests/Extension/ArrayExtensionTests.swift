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
//  ArrayExtensionTests.swift
//  CartiRIBsConcurrencyTests
//
//  Created by Kiseok on 1/10/26.
//

import Testing
import Foundation
@testable import CartiRIBsConcurrency

@Suite("Array Extension 테스트")
struct ArrayExtensionTests {
	final class MockItem: @unchecked Sendable {
		let id: Int
		init(id: Int) { self.id = id }
	}
	
	@Test
	func 같은참조의요소가있을때_removeElementByReference호출시_정확한인스턴스만제거되는지() {
		// given
		let item1 = MockItem(id: 1)
		let item2 = MockItem(id: 2)
		var array = [item1, item2]
		
		// when
		array.removeElementByReference(item1)
		
		// then
		#expect(array.count == 1)
		#expect(array.first === item2, "item1은 지워지고 item2만 남아야 함")
	}
	
	@Test
	func 값은같지만다른인스턴스가있을때_removeElementByReference호출시_제거되지않는지() {
		// given
		let originalItem = MockItem(id: 100)
		let sameValueItem = MockItem(id: 100)
		
		var array = [originalItem]
		
		// when
		array.removeElementByReference(sameValueItem)
		
		// then
		#expect(array.count == 1, "주소가 다르므로 지워지면 안 됨")
		#expect(array.first === originalItem, "원래 객체가 그대로 있어야 함")
	}
	
	@Test
	func 배열에없는요소가있을때_removeElementByReference호출시_안전하게무시되는지() {
		// given
		let item1 = MockItem(id: 1)
		let newItem = MockItem(id: 2)
		var array = [item1]
		
		// when
		array.removeElementByReference(newItem)
		
		// then
		#expect(array.count == 1)
		#expect(array.first === item1)
	}
	
	@Test
	func 같은참조가중복된배열이있을때_removeElementByReference호출시_첫번째요소만제거되는지() {
		// given
		let item = MockItem(id: 1)
		var array = [item, item]
		
		// when
		array.removeElementByReference(item)
		
		// then
		#expect(array.count == 1, "하나만 지워져야 함")
		#expect(array.first === item, "나머지 하나는 남아있어야 함")
	}
}

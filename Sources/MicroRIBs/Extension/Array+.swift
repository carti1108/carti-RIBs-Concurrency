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
//  Array+.swift
//  MicroRIBs
//
//  Created by Kiseok on 1/8/26.
//

import Foundation

public extension Array {

	mutating func removeElementByReference(_ element: Element) {
		guard let objIndex = firstIndex(where: { $0 as AnyObject === element as AnyObject }) else {
			return
		}
		remove(at: objIndex)
	}
}

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
//  Executor.swift
//  MicroRIBs
//
//  Created by Kiseok on 1/24/26.
//

import Foundation

/// A utility for executing tasks with a delay, taking frame duration into account.
public class Executor {

	/// Executes the given logic after the specified delay.
	///
	/// - Parameters:
	///   - delay: The delay before executing the logic.
	///   - maxFrameDuration: The maximum allowed duration for a single frame.
	///   - logic: The logic to execute.
	/// - Returns: A task representing the execution.
	public static func execute(withDelay delay: TimeInterval, maxFrameDuration: Int = 33, logic: @escaping @MainActor () -> Void) -> Task<Void, Never> {

		return Task { @MainActor in
			let period = UInt64(maxFrameDuration) * 1_000_000 / 3
			let maxFrameDurationSec = Double(maxFrameDuration) / 1000.0

			var lastRunLoopTime = Date().timeIntervalSinceReferenceDate
			var properFrameTime = 0.0

			while properFrameTime <= delay {
				try? await Task.sleep(nanoseconds: period)

				if Task.isCancelled { return }

				let currentTime = Date().timeIntervalSinceReferenceDate
				let trueElapsedTime = currentTime - lastRunLoopTime
				lastRunLoopTime = currentTime

				let boundedElapsedTime = min(trueElapsedTime, maxFrameDurationSec)
				properFrameTime += boundedElapsedTime
			}

			logic()
		}
	}
}

//
//  AsyncStream+Testing.swift
//  CartiRIBsConcurrency
//

import Foundation

public extension AsyncStream {
	
	/// Asynchronously waits for and returns the first value emitted by the stream.
	/// Useful for testing.
	func firstValue() async -> Element? {
		var iterator = self.makeAsyncIterator()
		return await iterator.next()
	}
	
	/// Asynchronously waits for and returns the specified number of elements from the stream.
	/// Useful for testing.
	func take(_ count: Int) async -> [Element] {
		var results = [Element]()
		var iterator = self.makeAsyncIterator()
		while results.count < count, let value = await iterator.next() {
			results.append(value)
		}
		return results
	}
}

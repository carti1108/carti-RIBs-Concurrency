//
//  TestAsyncSubject.swift
//  CartiRIBsConcurrency
//

import Foundation

/// A subject designed for synchronous value injection in unit tests.
public final class TestAsyncSubject<Element: Sendable>: @unchecked Sendable {
	private let subject = PassthroughAsyncSubject<Element>()

	public var stream: AsyncStream<Element> { 
		subject.stream 
	}
	
	public init() {}
	
	public func send(_ value: Element) {
		subject.send(value)
	}
}

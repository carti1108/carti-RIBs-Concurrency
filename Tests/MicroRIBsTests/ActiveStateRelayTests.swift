//
//  ActiveStateRelayTests.swift
//  MicroRIBsTests
//
//  Created by Kiseok on 11/13/26.
//

import Testing
@testable import MicroRIBs

@Suite("ActiveStateRelay 테스트")
@MainActor
struct ActiveStateRelayTests {

	@Test
	func 관찰을시작하면_현재값을즉시받는지() {
		// given
		let relay = ActiveStateRelay(true)
		var received: [Bool] = []

		// when
		let observation = relay.observe { received.append($0) }

		// then
		#expect(received == [true])
		_ = observation
	}

	@Test
	func send하면_반환전에모든옵저버가등록순서대로호출되는지() {
		// given
		let relay = ActiveStateRelay(false)
		var calls: [String] = []
		let first = relay.observe { calls.append("first:\($0)") }
		let second = relay.observe { calls.append("second:\($0)") }
		calls.removeAll()

		// when
		relay.send(true)

		// then
		#expect(calls == ["first:true", "second:true"])
		#expect(relay.value == true)
		_ = (first, second)
	}

	@Test
	func 관찰을취소하거나놓으면_더이상호출되지않는지() {
		// given
		let relay = ActiveStateRelay(false)
		var cancelledCount = 0
		var droppedCount = 0
		let cancelled = relay.observe { _ in cancelledCount += 1 }
		var dropped: ActiveStateObservation? = relay.observe { _ in droppedCount += 1 }

		// when
		cancelled.cancel()
		dropped = nil
		relay.send(true)

		// then
		#expect(cancelledCount == 1)
		#expect(droppedCount == 1)
		#expect(dropped == nil)
	}

	@Test
	func 알림중에다른관찰이취소되면_취소된옵저버는호출되지않는지() {
		// given
		let relay = ActiveStateRelay(false)
		var secondCount = 0
		var second: ActiveStateObservation?
		let first = relay.observe { _ in second?.cancel() }
		second = relay.observe { _ in secondCount += 1 }

		// when
		relay.send(true)

		// then
		#expect(secondCount == 1)
		_ = first
	}

	@Test
	func finish하면_스트림이끝나고이후값은무시되는지() async {
		// given
		let relay = ActiveStateRelay(false)
		var received: [Bool] = []
		let observation = relay.observe { received.append($0) }
		let stream = relay.stream

		// when
		relay.finish()
		relay.send(true)

		// then
		var streamed: [Bool] = []
		for await value in stream {
			streamed.append(value)
		}
		#expect(streamed == [false])
		#expect(received == [false])
		#expect(relay.value == false)
		_ = observation
	}
}

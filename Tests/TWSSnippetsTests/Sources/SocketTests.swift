//
//  Copyright 2024 INOVA IT d.o.o.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
@testable import TWSSnippets
@testable import TWSCommon
@testable import TWSModels
@testable import ComposableArchitecture
@testable import TWSTriggers

final class SocketTests: XCTestCase {

    let socketURL = URL(string: "https://www.google.com")!
    let configuration = TWSBasicConfiguration(id: "00000000-0000-0000-0000-000000000001")
    let triggerId = TWSDefaultTriggers.sdk_init.rawValue
    
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testConnectingToSocket() async throws {
        var state = TWSSnippetsFeature.State(configuration: configuration)
        state.socketURL = socketURL

        let clock = TestClock()
        let stream = AsyncStream<WebSocketEvent>.makeStream()
        let store: TestStoreOf<TWSSnippetsFeature> = .init(
            initialState: state,
            reducer: { TWSSnippetsObserverFeature() },
            withDependencies: {
                $0.api.getProject = { [socketURL] _ in (TWSProject(listenOn: socketURL, snippets: []), nil)}
                $0.socket.get = { _, _ in .init() }
                $0.socket.connect = { _ in stream.stream }
                $0.socket.closeConnection = { _ in }
                $0.socket.listen = { _ in }
                $0.continuousClock = clock
            }
        )

        await store.send(.business(.listenForChanges))

        // After the socket connection is established, check the snippets again

        stream.continuation.yield(.didConnect)
        await store.receive(\.business.isSocketConnected, true) {
            $0.isSocketConnected = true
        }
        await store.receive(\.business.load, timeout: NSEC_PER_SEC) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success, .init(listenOn: self.socketURL, snippets: [])) {
            $0.state = .loaded
            $0.shouldTriggerSdkInitCampaign = false
        }

        await store.receive(\.business.sendTrigger) {
            $0.campaigns = [.init(trigger: self.triggerId)]
        }
        
        await store.receive(\.business.startVisibilityTimers)
        
        await store.receive(\.business.trigger[id: triggerId].business.checkTrigger)

        await store.receive(\.business.trigger[id: triggerId].business.campaignLoaded)

        // Stop listening
        await store.send(.business(.stopListeningForChanges))
        await store.receive(\.business.delayReconnect)
        await store.send(.business(.stopReconnecting))
    }

    @MainActor
    func testReconnectingToSocket() async throws {
        var state = TWSSnippetsFeature.State(configuration: configuration)
        state.socketURL = socketURL

        let stream = AsyncStream<WebSocketEvent>.makeStream()
        let clock = TestClock()

        let store = TestStore(
            initialState: state,
            reducer: { TWSSnippetsObserverFeature() },
            withDependencies: {
                $0.api.getProject = { [socketURL] _ in (TWSProject(listenOn: socketURL, snippets: []), nil)}
                $0.continuousClock = clock
                $0.socket.get = { _, _ in .init() }
                $0.socket.connect = { _ in stream.stream }
                $0.socket.closeConnection = { _ in }
                $0.socket.listen = { _ in }
            }
        )

        await store.send(.business(.listenForChanges))

        // After the socket connection is established, check the snippets again

        stream.continuation.yield(.didConnect)
        await store.receive(\.business.isSocketConnected, true) {
            $0.isSocketConnected = true
        }
        await store.receive(\.business.load, timeout: NSEC_PER_SEC) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success, .init(listenOn: self.socketURL, snippets: [])) {
            $0.state = .loaded
            $0.shouldTriggerSdkInitCampaign = false
        }

        await store.receive(\.business.sendTrigger) {
            $0.campaigns = [.init(trigger: self.triggerId)]
        }
        
        await store.receive(\.business.startVisibilityTimers)
        
        await store.receive(\.business.trigger[id: triggerId].business.checkTrigger)
        
        await store.receive(\.business.trigger[id: triggerId].business.campaignLoaded)
        // End with didDisconnectEvent
        stream.continuation.yield(.didDisconnect)

        await store.receive(\.business.isSocketConnected, false) {
            $0.isSocketConnected = false
        }
        await store.receive(\.business.delayReconnect, timeout: NSEC_PER_SEC)

        // Reconnect after 3s
        await clock.advance(by: .seconds(3))
        await store.receive(\.business.reconnectTriggered, timeout: NSEC_PER_SEC) {
            $0.socketURL = nil
        }

        // Ask for new url,...
        await store.receive(\.business.load) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success, .init(listenOn: self.socketURL, snippets: [])) {
            $0.socketURL = self.socketURL
            $0.state = .loaded
        }
        await store.receive(\.business.startVisibilityTimers)
        await store.receive(\.business.listenForChanges, timeout: NSEC_PER_SEC)

        // After the socket connection is established, check the snippets again

        stream.continuation.yield(.didConnect)
        await store.receive(\.business.isSocketConnected, true) {
            $0.isSocketConnected = true
        }
        await store.receive(\.business.load, timeout: NSEC_PER_SEC) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success, .init(listenOn: self.socketURL, snippets: [])) {
            $0.state = .loaded
        }
        await store.receive(\.business.startVisibilityTimers)

        // Stop listening
        await store.send(.business(.stopListeningForChanges))
        await store.receive(\.business.delayReconnect)
        await store.send(.business(.stopReconnecting))
    }

    @MainActor
    func testOnSocketMessageRefresh() async throws {
        var state = TWSSnippetsFeature.State(configuration: configuration)
        state.socketURL = socketURL

        let clock = TestClock()
        let socketURL = URL(string: "https://www.google.com")!
        let stream = AsyncStream<WebSocketEvent>.makeStream()
        let store: TestStoreOf<TWSSnippetsFeature> = .init(
            initialState: state,
            reducer: { TWSSnippetsObserverFeature() },
            withDependencies: {
                $0.api.getProject = { _ in (TWSProject(listenOn: socketURL, snippets: []), nil)}
                $0.socket.get = { _, _ in .init() }
                $0.socket.connect = { _ in stream.stream }
                $0.socket.closeConnection = { _ in }
                $0.socket.listen = { _ in }
                $0.continuousClock = clock
            }
        )

        await store.send(.business(.listenForChanges))

        // After the socket connection is established, check the snippets again

        stream.continuation.yield(.didConnect)
        await store.receive(\.business.isSocketConnected, true) {
            $0.isSocketConnected = true
        }
        await store.receive(\.business.load, timeout: NSEC_PER_SEC) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success, .init(listenOn: self.socketURL, snippets: [])) {
            $0.state = .loaded
            $0.shouldTriggerSdkInitCampaign = false
        }

        await store.receive(\.business.sendTrigger) {
            $0.campaigns = [.init(trigger: self.triggerId)]
        }
        
        await store.receive(\.business.startVisibilityTimers)
        
        await store.receive(\.business.trigger[id: triggerId].business.checkTrigger)
        
        await store.receive(\.business.trigger[id: triggerId].business.campaignLoaded)

        // After message is received, refresh
        stream.continuation.yield(.receivedMessage(.init(id: .init(), type: .created)))
        await store.receive(\.business.load, timeout: NSEC_PER_SEC) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success, .init(listenOn: self.socketURL, snippets: [])) {
            $0.state = .loaded
        }
        await store.receive(\.business.startVisibilityTimers)

        // Stop listening
        await store.send(.business(.stopListeningForChanges))
        await store.receive(\.business.delayReconnect)
        await store.send(.business(.stopReconnecting))
    }
    
    @MainActor
    func testProjectHasSocketURL() async throws {
        var state = TWSSnippetsFeature.State(configuration: configuration)
        let testSnippet: TWSSnippet = .init(id: "test", target: URL(string: "https://www.test.com")!)
        
        let socketURL = URL(string: "https://www.google.com")!
        let stream = AsyncStream<WebSocketEvent>.makeStream()
        let clock = TestClock()

        let store = TestStore(
            initialState: state,
            reducer: { TWSSnippetsObserverFeature() },
            withDependencies: {
                $0.api.getProject = { [socketURL] _ in (TWSProject(listenOn: socketURL, snippets: [testSnippet]), nil)}
                $0.continuousClock = clock
                $0.socket.get = { _, _ in .init() }
                $0.socket.connect = { _ in stream.stream }
                $0.socket.closeConnection = { _ in }
                $0.socket.listen = { _ in }
                $0.date.now = Date()
            }
        )
        
        await store.send(.business(.load)) {
            $0.state = .loading
        }
        
        stream.continuation.yield(.didConnect)
        await store.receive(\.business.projectLoaded.success) {
            $0.state = .loaded
            $0.snippets = .init([.init(snippet: testSnippet)])
            $0.socketURL = socketURL
            $0.shouldTriggerSdkInitCampaign = false
        }
        
        await store.receive(\.business.sendTrigger) {
            $0.campaigns = [.init(trigger: self.triggerId)]
        }
        await store.receive(\.business.startVisibilityTimers)
        await store.receive(\.business.listenForChanges)
        
        await store.receive(\.business.trigger[id: triggerId].business.checkTrigger)
        await store.receive(\.business.trigger[id: triggerId].business.campaignLoaded)
        
        await store.receive(\.business.isSocketConnected) {
            $0.isSocketConnected = true
        }
        
        await store.receive(\.business.load) {
            $0.state = .loading
        }
        await store.receive(\.business.projectLoaded.success) {
            $0.state = .loaded
        }
        await store.receive(\.business.startVisibilityTimers)
        
        await store.send(.business(.stopListeningForChanges))
        await store.receive(\.business.delayReconnect)
        await store.send(.business(.stopReconnecting))
    }
    
    @MainActor
    func testProjectHasNoSocketURL() async throws {
        var state = TWSSnippetsFeature.State(configuration: configuration)
        let testSnippet: TWSSnippet = .init(id: "test", target: URL(string: "https://www.test.com")!)
        
        let stream = AsyncStream<WebSocketEvent>.makeStream()
        let clock = TestClock()

        let store = TestStore(
            initialState: state,
            reducer: { TWSSnippetsObserverFeature() },
            withDependencies: {
                $0.api.getProject = { [socketURL] _ in (TWSProject(listenOn: nil, snippets: [testSnippet]), nil)}
                $0.continuousClock = clock
                $0.socket.get = { _, _ in .init() }
                $0.socket.connect = { _ in stream.stream }
                $0.socket.closeConnection = { _ in }
                $0.socket.listen = { _ in }
                $0.date.now = Date()
            }
        )
        
        await store.send(.business(.load)) {
            $0.state = .loading
        }
        
        await store.receive(\.business.projectLoaded) {
            $0.state = .loaded
            $0.snippets = .init([.init(snippet: testSnippet)])
            $0.shouldTriggerSdkInitCampaign = false
        }
        await store.receive(\.business.sendTrigger) {
            $0.campaigns = [.init(trigger: self.triggerId)]
        }
        await store.receive(\.business.startVisibilityTimers)
        await store.receive(\.business.trigger[id: triggerId].business.checkTrigger)
        await store.receive(\.business.trigger[id: triggerId].business.campaignLoaded)
    }
}

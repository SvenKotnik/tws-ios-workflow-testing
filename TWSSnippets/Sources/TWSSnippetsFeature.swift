import Foundation
import ComposableArchitecture
import TWSSnippet
import TWSCommon
import Mustache
@_spi(InternalLibraries) import TWSModels

// swiftlint:disable identifier_name
private let RECONNECT_TIMEOUT: TimeInterval = 3
// swiftlint:enable identifier_name

@Reducer
public struct TWSSnippetsFeature: Sendable {

    @Dependency(\.api) var api
    @Dependency(\.socket) var socket
    @Dependency(\.continuousClock) var clock
    @Dependency(\.configuration) var configuration

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .business(action):
                return _reduce(into: &state, action: action)
            }
        }
        .forEach(\.snippets, action: \.business.snippets) {
            TWSSnippetFeature()
        }
    }

    // MARK: - Helpers

    private func _reduce(into state: inout State, action: Action.BusinessAction) -> Effect<Action> {
        switch action {

        // MARK: - Loading snippets

        case .load:
            logger.info("Load from source: \(state.source)")

            switch state.source {
            case .api:
                break

            case let .customURLs(urls):
                let dummySocketURL = URL(string: "wss://api.thewebsnippet.com")!
                let snippets = _generateCustomSnippets(urls: urls)
                let project = TWSProject(
                    listenOn: dummySocketURL,
                    snippets: snippets
                )

                return .send(.business(.projectLoaded(.success(.init(
                    project: project,
                    resources: [:],
                    serverDate: nil
                )))))

            @unknown default:
                break
            }

            return .run { [api] send in
                do {
                    let project = try await api.getProject(configuration())
                    let resources = await preloadResources(for: project.0, using: api)
                    let serverDate = project.1

                    await send(.business(.projectLoaded(.success(.init(
                        project: project.0,
                        resources: resources,
                        serverDate: serverDate
                    )))))
                } catch {
                    await send(.business(.projectLoaded(.failure(error))))
                }
            }

        case let .projectLoaded(.success(project)):
            logger.info("Snippets loaded.")

            var effects = [Effect<Action>]()
            let snippets = project.snippets
            let newOrder = snippets.map(\.id)
            let currentOrder = state.snippets.ids
            state.socketURL = project.listenOn
            state.preloadedResources = project.resources

            let snippetTimes = state.snippetDates
            snippets.forEach { snippet in
                if let snippetDateInfo = snippetTimes[snippet.id] {
                    if let snippetVisibility = snippet.visibility {
                        if let fromUtc = snippetVisibility.fromUtc,
                           snippetDateInfo.adaptedTime < fromUtc {
                            let duration = snippetDateInfo.adaptedTime.timeIntervalSince(fromUtc)
                            effects.append(
                                .run { send in
                                    try? await clock.sleep(for: .seconds(duration))
                                    await send(.business(.showSnippet(snippetId: snippet.id)))
                                }
                                    .cancellable(id: CancelID.showSnippet(snippet.id), cancelInFlight: true)
                            )

                        }
                        if let untilUtc = snippetVisibility.untilUtc,
                           snippetDateInfo.adaptedTime < untilUtc {
                            let duration = untilUtc.timeIntervalSince(snippetDateInfo.adaptedTime)
                            effects.append(
                                .run { send in
                                    try? await clock.sleep(for: .seconds(duration))
                                    await send(.business(.hideSnippet(snippetId: snippet.id)))
                                }
                                    .cancellable(id: CancelID.hideSnippet(snippet.id), cancelInFlight: true)
                            )
                        }
                    }
                }
            }

            // Update current or add new
            for var snippet in snippets {
                if let date = project.serverDate {
                    state.snippetDates[snippet.id] = SnippetDateInfo(serverTime: date)
                }
                /*if snippet.engine == .mustache {
                    do {
                        let template = try Template(URL: snippet.target)
                        //let data = snippet.props.map(\.data)
                        let rendering = try template.render(data)
                        
                    } catch {
                        
                    }
                }*/
                if currentOrder.contains(snippet.id) {
                    if state.snippets[id: snippet.id]?.snippet != snippet {
                        // View needs to be forced refreshed
                        effects.append(
                            .send(
                                .business(
                                    .snippets(
                                        .element(
                                            id: snippet.id,
                                            action: .business(.snippetUpdated(snippet: snippet))
                                        )
                                    )
                                )
                            )
                        )
                    }

                    state.snippets[id: snippet.id]?.snippet = snippet
                    logger.info("Updated snippet: \(snippet.id)")
                } else {
                    state.snippets.append(
                        .init(snippet: snippet)
                    )
                    logger.info("Added snippet: \(snippet.id)")
                }
            }

            // Remove old

            for id in currentOrder.subtracting(newOrder) {
                state.snippets.remove(id: id)
                logger.info("Removed snippet: \(id)")
            }

            // Keep sorted
            _sort(basedOn: newOrder, &state)

            return .concatenate(effects)

        case let .projectLoaded(.failure(error)):
            if let error = error as? DecodingError {
                logger.err(
                    "Failed to decode snippets: \(error)"
                )
            } else {
                logger.err(
                    "Failed to load snippets: \(error)"
                )
            }

            return .none

        // MARK: - Listening for changes via WebSocket

        case .listenForChanges:
            guard !state.isSocketConnected
            else {
                let socket = state.socketURL?.absoluteString ?? ""
                logger.info("Early return, because the socket is already connected to: \(socket)")
                return .none
            }

            logger.info("Request to start listening request with source: \(state.source)")
            switch state.source {
            case .api:
                break

            case .customURLs:
                logger.info("Won't listen because the snippets are overridden locally.")
                return .none

            @unknown default:
                break
            }

            guard let url = state.socketURL
            else {
                logger.err("Failed to listen for changes. URL is nil")
                assertionFailure()
                return .none
            }

            return .run { [socket, url, config = configuration()] send in
                let connectionID = await socket.get(config, url)
                let stream: AsyncStream<WebSocketEvent>
                do {
                    stream = try await socket.connect(connectionID)
                } catch {
                    await send(.business(.delayReconnect))
                    return
                }

                do {
                    try await _listen(
                        connectionID: connectionID,
                        stream: stream,
                        send: send
                    )
                } catch {
                    logger.info("Stopped listening: \(error)")
                }

                logger.info("The task used for listening to socket has completed. Closing connection.")
                await socket.closeConnection(connectionID)
            }
            .cancellable(id: CancelID.socket(configuration()))
            .concatenate(with: .send(.business(.delayReconnect)))

        case let .isSocketConnected(isConnected):
            state.isSocketConnected = isConnected
            return .none

        case .delayReconnect:
            return .run { [clock] send in
                do {
                    try await clock.sleep(for: .seconds(RECONNECT_TIMEOUT))
                    guard !Task.isCancelled else { return }
                    logger.info("Reconnect")
                    await send(.business(.reconnectTriggered))
                } catch {
                    logger.err("Reconnecting failed: \(error)")
                }
            }
            .cancellable(id: CancelID.reconnect(configuration()))

        case .reconnectTriggered:
            state.socketURL = nil
            return .send(.business(.load))

        case .stopListeningForChanges:
            logger.warn("Requested to stop listening for changes")
            return .cancel(id: CancelID.socket(configuration()))

        case .stopReconnecting:
            logger.warn("Requested to stop reconnecting to the socket")
            return .cancel(id: CancelID.reconnect(configuration()))

        // MARK: - Other

        case let .set(source):
            logger.info("Set source to: \(source)")
            state.source = source

            switch source {
            case .api, .customURLs:
                return .send(.business(.load))

            @unknown default:
                return .send(.business(.load))
            }

        case let .setLocalProps(props):
            let id = props.0
            let localProps = props.1
            state.snippets[id: id]?.localProps = .dictionary(localProps)
            return .none

        case .snippets:
            return .none

        case .showSnippet(snippetId: let snippetId):
            state.snippets[id: snippetId]?.isVisible = true
            return .none

        case .hideSnippet(snippetId: let snippetId):
            state.snippets[id: snippetId]?.isVisible = false
            return .none
        }
    }

    // MARK: - Helpers

    private func _sort(basedOn orderedIDs: [TWSSnippet.ID], _ state: inout State) {
        var orderDict = [TWSSnippet.ID: Int]()
        for (index, id) in orderedIDs.enumerated() {
            orderDict[id] = index
        }

        state.snippets.sort(by: {
            let idx1 = orderDict[$0.id] ?? Int.max
            let idx2 = orderDict[$1.id] ?? Int.max
            return idx1 < idx2
        })
    }

    private func _generateCustomSnippets(urls: [URL]) -> [TWSSnippet] {
        let uuidGenerator = IncrementingUUIDGenerator()
        return urls.map {
            .init(
                id: uuidGenerator(),
                target: $0,
                status: "enabled",
                visibilty: nil
            )
        }
    }

    private func _listen(
        connectionID: UUID,
        stream: AsyncStream<WebSocketEvent>,
        send: Send<TWSSnippetsFeature.Action>
    ) async throws {
        mainLoop: for await event in stream {
            switch event {
            case .didConnect:
                logger.info("Did connect \(Date.now)")
                await send(.business(.isSocketConnected(true)))
                await send(.business(.load))

                do {
                    try await socket.listen(connectionID)
                } catch {
                    logger.err("Failed to receive a message: \(error)")
                    break mainLoop
                }

                if Task.isCancelled { break mainLoop }

            case .didDisconnect:
                logger.info("Did disconnect \(Date())")
                await send(.business(.isSocketConnected(false)))
                break mainLoop

            case let .receivedMessage(message):
                logger.info("Received a message: \(message)")

                switch message.type {
                case .created, .deleted:
                    await send(.business(.load))

                case .updated:

                    await send(
                        .business(
                            .snippets(
                                .element(
                                    id: message.id.uuidString,
                                    action: .business(.snippetUpdated(snippet: message.snippet))
                                )
                            )
                        )
                    )
                }

                do {
                    try await socket.listen(connectionID)
                } catch {
                    logger.err("Failed to receive a message: \(error)")
                    break mainLoop
                }
            }
        }
    }
}

import Foundation
import ComposableArchitecture
@_spi(Internals) import TWSModels
import TWSCommon

@Reducer
public struct TWSSnippetFeature: Sendable {

    @ObservableState
    public struct State: Equatable, Codable, Sendable {

        enum CodingKeys: String, CodingKey {
            case snippet, updateCount, isVisible, customProps
        }

        public var snippet: TWSSnippet
        public var updateCount = 0
        public var isVisible = true
        public var localProps: TWSSnippet.Props = .dictionary([:])

        public init(snippet: TWSSnippet) {
            self.snippet = snippet
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // MARK: - Persistent properties

            snippet = try container.decode(TWSSnippet.self, forKey: .snippet)

            // MARK: - Non-persistent properties - Reset on init

            isVisible = true
            updateCount = 0
            localProps = .dictionary([:])
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(snippet, forKey: .snippet)
            try container.encode(isVisible, forKey: .isVisible)
            try container.encode(updateCount, forKey: .updateCount)
            try container.encode(localProps, forKey: .customProps)
        }
    }

    public enum Action {

        @CasePathable
        public enum Business {
            case snippetUpdated(snippet: TWSSnippet?)
            case showSnippet
            case hideSnippet
            case checkResources(snippet: TWSSnippet)
        }

        @CasePathable
        public enum Delegate {
            case resourcesUpdated([TWSSnippet.Attachment: String])
        }

        case business(Business)
        case delegate(Delegate)
    }

    @Dependency(\.api) var api

    public init() { }

    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .business(.snippetUpdated(snippet)):
            if let snippet {
                state.snippet = snippet
                state.isVisible = true
                if snippet != state.snippet {
                    logger.info("Snippet updated from \(state.snippet) to \(snippet).")
                } else {
                    logger.info("Snippet's payload changed")
                    state.updateCount += 1
                }

                return .send(.business(.checkResources(snippet: snippet)))
            }

            return .none

        case .business(.hideSnippet):
            state.isVisible = false
            return .none

        case .business(.showSnippet):
            state.isVisible = true
            return .none

        case let .business(.checkResources(snippet)):
            return .run { [api] send in
                let resources = await preloadResources(for: snippet, using: api)
                await send(.delegate(.resourcesUpdated(resources)))
            }

        case .delegate:
            return .none
        }
    }
}

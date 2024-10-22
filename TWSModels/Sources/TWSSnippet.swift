import Foundation

public struct TWSSnippet: Identifiable, Codable, Hashable, Sendable {

    public enum SnippetStatus: ExpressibleByStringLiteral, Hashable, Codable, Sendable {

        case enabled
        case disabled
        case other(String)

        public init(stringLiteral value: String) {
            let value = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            switch value {
            case "enabled":
                self = .enabled

            case "disabled":
                self = .disabled

            default:
                self = .other(value)
            }
        }

        public var rawValue: String {
            switch self {
            case .enabled: "enabled"
            case .disabled: "disabled"
            case .other(let string): string
            }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            self = .init(stringLiteral: value)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    public let id: UUID
    public let status: SnippetStatus
    public var target: URL
    public let props: Props?
    @_spi(InternalLibraries) @LossyCodableList public var dynamicResources: [Attachment]?

    enum CodingKeys: String, CodingKey {
        case id, status, target, props, dynamicResources
    }

    public init(
        id: UUID,
        target: URL,
        dynamicResources: [Attachment]? = nil,
        status: SnippetStatus = .enabled,
        props: Props = .dictionary([:])
    ) {
        self.id = id
        self.target = target
        self.status = status
        self._dynamicResources = .init(elements: dynamicResources)
        self.props = props
    }
}

public extension TWSSnippet {

    struct Attachment: Codable, Hashable, Sendable {

        public let url: URL
        public let contentType: `Type`

        public init(url: URL, contentType: `Type`) {
            self.url = url
            self.contentType = contentType
        }
    }
}

public extension TWSSnippet.Attachment {

    enum `Type`: String, Codable, Hashable, Sendable {

        case javascript = "text/javascript"
        case css = "text/css"
        case html = "text/html"
    }
}

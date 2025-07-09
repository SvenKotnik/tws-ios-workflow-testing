import Foundation
@_spi(Internals) import TWSModels
import TWSFormatters

public struct TWSAPI {

    public let getProject: @Sendable (
        _ projectId: TWSBasicConfiguration
    ) async throws(APIError) -> (TWSProject, Date?)

    public var getSharedToken: @Sendable (
        _ sharedId: TWSSharedConfiguration
    ) async throws(APIError) -> String

    public var getSnippetByShareToken: @Sendable (
        _ token: String
    ) async throws(APIError) -> (TWSProject, Date?)

    public let getResource: @Sendable (
        TWSSnippet.Attachment, [String: String]
    ) async throws(APIError) -> ResourceResponse
    
    public let getCampaign: @Sendable (
        TWSBasicConfiguration, String
    ) async throws(APIError) -> TWSCampaign

    static func live(
        baseUrl: TWSBaseUrl
    ) -> Self {
        .init(
            getProject: { project throws(APIError) in
                let result = try await Router.make(request: .init(
                        method: .get,
                        scheme: baseUrl.scheme,
                        path: "/projects/\(project.id)/snippets/v1",
                        host: baseUrl.host,
                        queryItems: [],
                        headers: [:],
                        auth: true
                    ))

                do {
                    let decoder = JSONDecoder()

                    decoder.dateDecodingStrategy = isoDateDecoder

                    return (try decoder.decode(TWSProject.self, from: result.data), result.dateOfResponse)
                } catch {
                    throw APIError.decode(error)
                }
            },
            getSharedToken: { shared throws(APIError) in
                let result = try await Router.make(request: .init(
                    method: .get,
                    scheme: baseUrl.scheme,
                    path: "/shared/\(shared.id)",
                    host: baseUrl.host,
                    queryItems: [],
                    headers: [
                        "Accept": "application/json"
                    ],
                    auth: true
                ))

                do {
                    let sharedTokenResponse = try JSONDecoder().decode(TWSSharedToken.self, from: result.data)
                    return sharedTokenResponse.shareToken
                } catch {
                    throw APIError.decode(error)
                }
            },
            getSnippetByShareToken: { token throws(APIError) in
                let result = try await Router.make(request: .init(
                    method: .get,
                    scheme: baseUrl.scheme,
                    path: "/snippets/shared",
                    host: baseUrl.host,
                    queryItems: [
                        URLQueryItem(name: "shareToken", value: token)
                    ],
                    headers: [
                        "Accept": "application/json"
                    ],
                    auth: true
                ))

                do {
                    return (try JSONDecoder().decode(TWSProject.self, from: result.data), result.dateOfResponse)
                } catch {
                    throw APIError.decode(error)
                }
            },
            getResource: { attachment, headers throws(APIError) in
                let queryItems = URLComponents(url: attachment.url, resolvingAgainstBaseURL: false)?.queryItems
                
                let result = try await Router.make(request: .init(
                    method: .get,
                    scheme: attachment.url.scheme ?? "https",
                    path: attachment.url.path(),
                    host: attachment.url.host() ?? "",
                    queryItems: queryItems ?? [],
                    headers: headers.merging(["User-Agent" : await UserAgentProvider.userAgent], uniquingKeysWith: { first, second in second}) ,
                    auth: false
                ))

                if let payload = String(data: result.data, encoding: .utf8) {
                    return ResourceResponse(responseUrl: result.responseUrl, data: payload)
                }

                throw .decode(NSError(domain: "invalid-string", code: -1))
            },
            getCampaign: { project, campaignTrigger throws(APIError) in

                let result = try await Router.make(request: .init(
                    method: .post,
                    scheme: baseUrl.scheme,
                    path: "/projects/\(project.id)/events",
                    host: baseUrl.host,
                    queryItems: [],
                    headers: ["content-type":"application/json-patch+json"],
                    auth: true,
                    body: ["event": campaignTrigger]
                ))
                
                do {
                    let decoder = JSONDecoder()

                    decoder.dateDecodingStrategy = isoDateDecoder
                    
                    return try decoder.decode(TWSCampaign.self, from: result.data)
                } catch {
                    throw APIError.decode(error)
                }
            }
        )
    }
}

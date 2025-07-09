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

import Foundation
import WebKit

class Router {

    private static let authManager = AuthManager(baseUrl: TWSBuildSettingsProvider.getTWSBaseUrl())
    private static let redirectDelegate = RedirectHandler()
    private static let urlSession = URLSession(configuration: URLSessionConfiguration.default, delegate: redirectDelegate, delegateQueue: nil)
    
    private static let dateFormatter = {
        let newDateFormatter = DateFormatter()
        newDateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ssZ"
        newDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        newDateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        return newDateFormatter
    }()

    class func make(request: Request, retryEnabled: Bool = true) async throws(APIError) -> APIResult {
        var components = URLComponents()
        components.scheme = request.scheme
        components.host = request.host
        components.path = request.path

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            fatalError("Failed to create an URL")
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: 60)
        urlRequest.httpMethod = request.method.rawValue.uppercased()
        for header in request.headers {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }
        
        if request.method != .get {
            do {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request.body, options: [])
            } catch {
                throw APIError.local(error)
            }
        }
        logger.info(urlRequest.debugDescription)

        do {
            let shouldRefreshTokens = await authManager.shouldRefreshTokens()
            if shouldRefreshTokens {
                try await authManager.forceRefreshRefreshTokens()
            }
            
            let token = try await authManager.getAccessToken(shouldRefreshTokens)

            if request.auth {
                urlRequest.setValue(
                    "Bearer \(token)",
                    forHTTPHeaderField: "Authorization"
                )
            }
            let result = try await urlSession.data(for: urlRequest)
            guard
                let httpResult = result.1 as? HTTPURLResponse
            else {
                fatalError("Received a response without being an HTTPURLResponse?")
            }

            if 200..<300 ~= httpResult.statusCode {
                if let resolvedUrl = result.1.url,
                   let httpCookies = HTTPCookieStorage.shared.cookies(for: resolvedUrl) {
                    httpCookies.forEach { cookie in
                        Task { @MainActor in
                            await WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie)
                        }
                    }
                }
                
                var serverDate: Date?
                if let responseHeaders = httpResult.allHeaderFields as? [String: String],
                   let serverDateHeader = responseHeaders["Date"] {
                    serverDate = dateFormatter.date(from: serverDateHeader)
                }
                
                return .init(
                    data: result.0,
                    dateOfResponse: serverDate,
                    responseUrl: result.1.url
                )
            } else if httpResult.statusCode == 401 {
                if retryEnabled {
                    try await authManager.forceRefreshAccessTokens()
                    return try await make(request: request, retryEnabled: false)
                } else {
                    throw APIError.server(httpResult.statusCode, result.0)
                }
            } else {
                logger.err(String(data: result.0, encoding: .utf8) ?? "null")
                throw APIError.server(httpResult.statusCode, result.0)
            }
        } catch {
            throw APIError.local(error)
        }
    }
}

struct APIResult {

    let data: Data
    let dateOfResponse: Date?
    let responseUrl: URL?
}

public enum APIError: Error {

    case local(Error)
    case server(Int, Data)
    case decode(Error)
    case auth(String)
}

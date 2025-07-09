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
import SwiftJWT

actor AuthManager {

    private let loginUrl: URL
    private let registerUrl: URL

    private let keychainHelper = KeychainHelper()
    private let accessTokenKey = "TWSAccessToken"
    private let refreshTokenKey = "TWSRefreshToken"
    private let JWTTokenKey = "TWSJWTToken"

    private var ongoingRefreshTask: Task<String, Error>?
    private var ongoingAccessTask: Task<String, Error>?

    init(baseUrl: TWSBaseUrl) {
        guard !baseUrl.scheme.isEmpty, !baseUrl.host.isEmpty else {
            fatalError("Invalid base URL provided in constructor")
        }

        loginUrl = Self.createUrl(scheme: baseUrl.scheme, host: baseUrl.host, path: "/auth/login")
        registerUrl = Self.createUrl(scheme: baseUrl.scheme, host: baseUrl.host, path: "/auth/register")
    }

    func shouldRefreshTokens() -> Bool {
        // Observe service account change if cached and generated jwt tokens are not equal
        let newJwt = TWSBuildSettingsProvider.decodeJWT(TWSBuildSettingsProvider.generateMainJWTToken())
        let oldJwt = TWSBuildSettingsProvider.decodeJWT(keychainHelper.get(for: JWTTokenKey) ?? "")
        
        if(!areJWTEqual(oldJwt, newJwt)) {
            logger.debug("Service account has changed, refreshing tokens")
            return true
        }
        logger.debug("Service account hasn't changed, no need to refresh JWT")
        return false
    }
    
    func forceRefreshRefreshTokens() async throws {
        _ = try await getRefreshToken(true)
    }
    
    func forceRefreshAccessTokens() async throws {
        _ = try await getAccessToken(true)
    }

    func getAccessToken(_ force: Bool) async throws -> String {
        if let ongoingTask = ongoingAccessTask {
            return try await ongoingTask.value
        }

        let accessTask = Task { () -> String in
            if !force {
                if let savedAccessToken = keychainHelper.get(for: accessTokenKey) {
                    return savedAccessToken
                }
            }
            
            let refreshToken = keychainHelper.get(for: refreshTokenKey) ?? ""
            let accessToken = try await requestAccessToken(refreshToken)
            keychainHelper.save(accessToken, for: accessTokenKey)
            return accessToken
        }

        ongoingAccessTask = accessTask

        do {
            let result = try await accessTask.value
            ongoingAccessTask = nil
            return result
        } catch {
            ongoingAccessTask = nil
            throw error
        }

    }

    private func getRefreshToken(_ force: Bool) async throws -> String {
        if let ongoingTask = ongoingRefreshTask {
            return try await ongoingTask.value
        }

        let refreshTask = Task { () -> String in
            if !force {
                if let savedRefreshToken = keychainHelper.get(for: refreshTokenKey) {
                    return savedRefreshToken
                }
            }

            let jwtToken = getJWTToken(force)
            let refreshToken = try await requestRefreshToken(jwtToken)
            keychainHelper.save(refreshToken, for: refreshTokenKey)
            return refreshToken
        }

        ongoingRefreshTask = refreshTask

        do {
            let result = try await refreshTask.value
            ongoingRefreshTask = nil
            return result
        } catch {
            ongoingRefreshTask = nil
            throw error
        }
    }

    private func getJWTToken(_ force: Bool) -> String {
        if !force {
            if let savedJWTToken = keychainHelper.get(for: JWTTokenKey) {
                return savedJWTToken
            }
        }

        let jwtToken = TWSBuildSettingsProvider.generateMainJWTToken()
        keychainHelper.save(jwtToken, for: JWTTokenKey)
        return jwtToken
    }

    private func requestAccessToken(_ refreshToken: String, refreshEnabled: Bool = true) async throws -> String {
        var tokenRequest = URLRequest(url: loginUrl, timeoutInterval: 60)
        tokenRequest.httpMethod = Request.Method.post.rawValue.uppercased()
        tokenRequest.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")
        tokenRequest.setValue("text/plain", forHTTPHeaderField: "accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: tokenRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("Received a response without being an HTTPURLResponse?")
            }

            if 200..<300 ~= httpResponse.statusCode {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let accessToken = json["authToken"] as? String {
                    return accessToken
                } else {
                    throw APIError.auth("Invalid JSON structure or missing 'accessToken'")
                }
            } else if httpResponse.statusCode == 401 && refreshEnabled {
                let newRefreshToken = try await getRefreshToken(true)
                return try await requestAccessToken(newRefreshToken, refreshEnabled: false)
            } else {
                logger.err(String(data: data, encoding: .utf8) ?? "null")
                throw APIError.server(httpResponse.statusCode, data)
            }
        } catch {
            throw APIError.local(error)
        }
    }

    private func requestRefreshToken(_ jwtToken: String) async throws -> String {
        var tokenRequest = URLRequest(url: registerUrl, timeoutInterval: 60)
        tokenRequest.httpMethod = Request.Method.post.rawValue.uppercased()
        tokenRequest.setValue("Bearer \(jwtToken)", forHTTPHeaderField: "Authorization")
        tokenRequest.setValue("text/plain", forHTTPHeaderField: "accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: tokenRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("Received a response without being an HTTPURLResponse?")
            }

            if 200..<300 ~= httpResponse.statusCode {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let refreshToken = json["refreshToken"] as? String {
                    return refreshToken
                } else {
                    throw APIError.auth("Invalid JSON structure or missing 'refreshToken'")
                }
            } else {
                logger.err(String(data: data, encoding: .utf8) ?? "null")
                throw APIError.server(httpResponse.statusCode, data)
            }
        } catch {
            throw APIError.local(error)
        }
    }
    
    private static func createUrl(scheme: String, host: String, path: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.path = path

        guard let url = components.url else {
            fatalError("Failed to construct URL with scheme: \(scheme), host: \(host), path: \(path)")
        }
        
        return url
    }
    
    private func areJWTEqual(_ jwt1: JWT<TWSBuildSettingsProvider.Payload>, _ jwt2: JWT<TWSBuildSettingsProvider.Payload>) -> Bool {
        return jwt1.header.kid == jwt2.header.kid && jwt1.claims == jwt2.claims
    }
    
}

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
import ComposableArchitecture
import TWSModels

public struct SocketDependency: Sendable {

    public var get: @Sendable (any TWSConfiguration, URL) async -> UUID
    public var connect: @Sendable (UUID) async throws(SocketMessageReadError) -> AsyncStream<WebSocketEvent>
    public var listen: @Sendable (UUID) async throws -> Void
    public var closeConnection: @Sendable (UUID) async -> Void
    public var abort: @Sendable (any TWSConfiguration) async -> Void
}

public enum SocketDependencyKey: DependencyKey {

    public static var testValue: SocketDependency {
        return .init(
            get: { _,_ in return UUID()},
            connect: { _ in return AsyncStream<WebSocketEvent>.makeStream().stream},
            listen: { _ in},
            closeConnection: { _ in},
            abort: { _ in }
        )
    }
    public static var liveValue: SocketDependency {
        let storage = ActorIsolatedDictionary<UUID, SocketConnector>([:])
        let configuration = ActorIsolatedDictionary<String, UUID>([:])

        return .init(
            get: { [storage, configuration] config, url in
                let id = UUID()
                let socket = SocketConnector(url: url)
                await storage.setValue(socket, forKey: id)
                await configuration.setValue(id, forKey: config.id)
                return id
            },
            connect: { [storage] id throws(SocketMessageReadError) in
                guard let socket = await storage.getValue(forKey: id)
                else { preconditionFailure("Sending a `connect` message to an invalid object: \(id)") }
                try await socket.connect()
                return socket.stream
            },
            listen: { [storage] id in
                guard let socket = await storage.getValue(forKey: id)
                else { preconditionFailure("Sending a `listen` message to an invalid object: \(id)") }
                try await socket.listen()
            },
            closeConnection: { [storage] id in
                guard let socket = await storage.getValue(forKey: id)
                else { return }

                await socket.closeConnection()
                await storage.removeValue(forKey: id)
            },
            abort: { [storage, configuration] config in
                guard
                    let connection = await configuration.getValue(forKey: config.id),
                    let socket = await storage.getValue(forKey: connection)
                else {
                    return
                }

                await socket.closeConnection()
                await configuration.removeValue(forKey: config.id)
                await storage.removeValue(forKey: connection)
            }
        )
    }
}

public extension DependencyValues {

    var socket: SocketDependency {
        get { self[SocketDependencyKey.self] }
        set { self[SocketDependencyKey.self] = newValue }
    }
}

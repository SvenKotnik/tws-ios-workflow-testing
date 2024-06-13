//
//  SocketDependency.swift
//  TWSCommon
//
//  Created by Miha Hozjan on 12. 06. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import TWSModels
import ComposableArchitecture

public struct SocketDependency {

    public var get: @Sendable (URL) async -> UUID
    public var connect: @Sendable (UUID) async -> AsyncStream<WebSocketEvent>
    public var listen: @Sendable (UUID) async throws -> Void
    public var closeConnection: @Sendable (UUID) async -> Void
}

public enum SocketDependencyKey: DependencyKey {

    public static var liveValue: SocketDependency {
        let storage = ActorIsolatedDictionary<UUID, SocketConnector>([:])
        return .init(
            get: { [storage] url in
                let id = UUID()
                let socket = SocketConnector(url: url)
                await storage.setValue(socket, forKey: id)
                return id
            },
            connect: { [storage] id in
                guard let socket = await storage.getValue(forKey: id)
                else { preconditionFailure("Sending a `connect` message to an invalid object: \(id)") }
                socket.connect()
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
                socket.closeConnection()
                await storage.removeValue(forKey: id)
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

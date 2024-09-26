//
//  APIDependency.swift
//  TWSDemo
//
//  Created by Miha Hozjan on 27. 05. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import TWSModels
import TWSAPI
import ComposableArchitecture

public struct APIDependency {
    public var getProject: @Sendable (TWSConfiguration) async throws(APIError) -> TWSProject
    public var getSnippetBySharedId: @Sendable (
        TWSConfiguration,
        _ snippetId: String
    ) async throws(APIError) -> TWSSharedSnippet
}

public enum APIDependencyKey: DependencyKey {

    public static var liveValue: APIDependency {
        let api = TWSAPIFactory.new(host: "api.thewebsnippet.dev")

        return .init(
            getProject: api.getProject,
            getSnippetBySharedId: api.getSnippetBySharedId
        )
    }
}

public extension DependencyValues {

    var api: APIDependency {
        get { self[APIDependencyKey.self] }
        set { self[APIDependencyKey.self] = newValue }
    }
}

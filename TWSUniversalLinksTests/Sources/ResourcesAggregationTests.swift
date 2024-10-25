//
//  ResourcesAggregationTests.swift
//  TWSUniversalLinksTests
//
//  Created by Miha Hozjan on 27. 9. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import XCTest
@testable import TWSUniversalLinks
@testable import TWSCommon
@testable @_spi(InternalLibraries) import TWSModels
@testable import TWSAPI
@testable import ComposableArchitecture

final class ResourcesAggregationTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAggregateResourcesUniversalLink() async throws {
        let url = URL(string: "https://thewebsnippet.dev/shared/abc123")!
        let attachments: [TWSSnippet.Attachment] = [
            .init(
                url: URL(string: "https://www.r1.com")!,
                contentType: .javascript
            ),
            .init(
                url: URL(string: "https://www.r2.com")!,
                contentType: .css
            ),
            .init(
                url: URL(string: "https://www.r3.com")!,
                contentType: .javascript
            ),
            .init(
                url: URL(string: "https://www.r4.com")!,
                contentType: .css
            )
        ]

        var preloadedAttachments = Dictionary(
            uniqueKeysWithValues:
                attachments.map {
                    ($0, $0.url.absoluteString)
                }
        )

        preloadedAttachments[.init(
            url: url,
            contentType: .html
        )] = url.absoluteString

        let sharedSnippet = TWSSharedSnippet(
            organization: .init(
                id: "00000000-0000-0000-0000-000000000000"
            ),
            project: .init(
                id: "00000000-0000-0000-0000-000000000001"
            ),
            snippet: .init(
                id: "00000000-0000-0000-0000-000000000002",
                target: url,
                dynamicResources: attachments,
                status: "enabled"
            )
        )

        let store = await TestStore(
            initialState: .init(),
            reducer: { TWSUniversalLinksFeature() }
            ,
            withDependencies: {
                $0.api.getSnippetBySharedId = { @Sendable _, _ in return sharedSnippet }
                $0.api.getResource = { attachment in return attachment.url.absoluteString }
            }
        )

        await store.send(.business(.onUniversalLink(url))).finish()
        await store.receive(\.business.snippetLoaded.success, sharedSnippet)
        await store.receive(\.business.notifyClient, TWSSharedSnippetBundle(
            sharedSnippet: sharedSnippet,
            resources: preloadedAttachments
        ))

        await store.receive(
            \.delegate.snippetLoaded,
            TWSSharedSnippetBundle(
                sharedSnippet: sharedSnippet,
                resources: preloadedAttachments
            )
        )
    }
}

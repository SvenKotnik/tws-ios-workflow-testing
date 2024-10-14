//
//  ResourcesAggregationTests.swift
//  TWSSnippetsTests
//
//  Created by Miha Hozjan on 26. 9. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import XCTest
@testable import TWSSnippets
@testable import TWSCommon
@testable import TWSModels
@testable import ComposableArchitecture

final class ResourcesAggregationTests: XCTestCase {

    let socketURL = URL(string: "https://www.google.com")!
    let configuration = TWSConfiguration(
        organizationID: "00000000-0000-0000-0000-000000000000",
        projectID: "00000000-0000-0000-0000-000000000001"
    )
    let snippets: [TWSSnippet] = [
        .init(
            id: .init(),
            target: URL(string: "https://www.tws.com")!,
            dynamicResources: [
                .init(url: URL(string: "https://www.r1.com")!, contentType: .javascript),
                .init(url: URL(string: "https://www.r2.com")!, contentType: .css),
                .init(url: URL(string: "https://www.r3.com")!, contentType: .javascript),
                .init(url: URL(string: "https://www.r4.com")!, contentType: .css)
            ],
            type: "tab",
            status: "enabled"
        )
    ]

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAggregateResources() async throws {

        let state = TWSSnippetsFeature.State(configuration: configuration)
        let project = TWSProject(
            listenOn: socketURL,
            snippets: snippets
        )

        let expectedResources: [TWSSnippet.Attachment: String] = [
            .init(
                url: URL(string: "https://www.r1.com")!,
                contentType: .javascript
            ): "https://www.r1.com",
            .init(
                url: URL(string: "https://www.r2.com")!,
                contentType: .css
            ): "https://www.r2.com",
            .init(
                url: URL(string: "https://www.r3.com")!,
                contentType: .javascript
            ): "https://www.r3.com",
            .init(
                url: URL(string: "https://www.r4.com")!,
                contentType: .css
            ): "https://www.r4.com"
        ]

        let aggregate = TWSProjectBundle(
            project: project,
            resources: expectedResources
        )

        let store = TestStore(
            initialState: state,
            reducer: { TWSSnippetsFeature() },
            withDependencies: {
                $0.api.getProject = { _ in return project }
                $0.api.getResource = { attachment in return attachment.url.absoluteString }
            }
        )

        await store.send(.business(.load)).finish()
        await store.receive(\.business.projectLoaded.success, aggregate) {
            $0.snippets = .init(uniqueElements: self.snippets.map { .init(snippet: $0) })
            $0.socketURL = self.socketURL
            $0.preloadedResources = expectedResources
        }
    }
}

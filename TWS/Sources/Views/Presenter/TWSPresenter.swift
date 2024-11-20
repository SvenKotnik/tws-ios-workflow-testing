//
//  TWSPresenter.swift
//  Playground
//
//  Created by Miha Hozjan on 11. 11. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import TWSModels
internal import ComposableArchitecture
internal import TWSSnippet

@MainActor
protocol TWSPresenter {

    var preloadedResources: [TWSSnippet.Attachment: String] { get }
    var navigationProvider: NavigationProvider { get }
    var heightProvider: SnippetHeightProvider { get }
    var isLocal: Bool { get }

    func isVisible(snippet: TWSSnippet) -> Bool
    func resourcesHash(for snippet: TWSSnippet) -> Int
    func updateCount(for snippet: TWSSnippet) -> Int
    func handleIncomingUrl(_ url: URL)
    func store(forSnippetID id: String) -> StoreOf<TWSSnippetFeature>?
}

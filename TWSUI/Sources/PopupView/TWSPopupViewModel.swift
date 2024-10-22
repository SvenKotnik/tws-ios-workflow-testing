//
//  TWSPopupViewModel.swift
//  TheWebSnippet
//
//  Created by Luka Kit on 30. 9. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//
import Foundation
import TWSModels
import TWSKit
import SwiftUI

@MainActor
@Observable
class TWSPopupViewModel {
    var navigation: [TWSNavigationType] {
        didSet {
            if let topNavigation = navigation.last,
            let pendingIndex = pendingNavigationRemoval.firstIndex(of: topNavigation) {
                pendingNavigationRemoval.remove(at: pendingIndex)
                navigation.removeLast()
            }
            if navigation.isEmpty {
                onNavigationCleared?()
            }
        }
    }
    let manager: TWSManager
    var onNavigationCleared: (() -> Void)?

    private var clearedPopupSnippets: [TWSSnippet] = []
    private var pendingNavigationRemoval: [TWSNavigationType] = []

    init(manager: TWSManager) {
        self.manager = manager
        self.navigation = []
    }

    func addOnNavigationCleared(onNavigationCleared: @escaping (() -> Void)) {
        self.onNavigationCleared = onNavigationCleared
    }

    func fillInitialNavigation() {
        let popupSnippets = manager.snippets.filter { _ in
            // As of now, because `type` needs to be removed with TWS-212,
            // We have no way to detect pop-ups (Check below too)
            // Before: return snippet.type == .popup
            return false
        }
        self.navigation = popupSnippets.map { .snippetPopup($0) }
    }

    func startListeningForEvents() async {
        await manager.observe { [weak self] event in
            guard let self else { return }

            switch event {
            case .snippetsUpdated(let snippets):
                let updatedPopupSnippets = snippets.filter({ _ in
                    // As of now, because `type` needs to be removed with TWS-212,
                    // We have no way to detect pop-ups (Check above too)
                    // return self.canShowPopupSnippet(snippet) && snippet.type == .popup
                    return false
                })

                updatedPopupSnippets.forEach { snippet in
                    if self.isPopupMissingFromTheNavigationQueue(snippet) {
                        self.addNavigationToQueue(.snippetPopup(snippet))
                    }
                }
                self.navigation.forEach { navigation in
                    if self.isNavigationMissingFromReceivedPopups(updatedPopupSnippets, navigation) {
                        self.removeNavigationFromQueue(navigation)
                    }
                }

            default:
                return
            }
        }
    }

    public func addClearedPopup(_ snippet: TWSSnippet) {
        self.clearedPopupSnippets.append(snippet)
    }

    public func canShowPopupSnippet(_ snippet: TWSSnippet) -> Bool {
        return !clearedPopupSnippets.contains(snippet)
    }

    func removeNavigationFromQueue(_ navigation: TWSNavigationType) {
        if let index = self.navigation.firstIndex(of: navigation) {
            if index == self.navigation.endIndex - 1 {
                self.navigation.remove(at: index)
            } else {
                pendingNavigationRemoval.append(navigation)
            }
        }
    }

    private func addNavigationToQueue(_ navigation: TWSNavigationType) {
        self.navigation.append(navigation)
    }

    private func isPopupMissingFromTheNavigationQueue(_ snippet: TWSSnippet) -> Bool {
        if self.navigation.firstIndex(of: .snippetPopup(snippet)) != nil {
            return false
        }
        return true
    }

    private func isNavigationMissingFromReceivedPopups(
        _ receivedSnippets: [TWSSnippet],
        _ navigation: TWSNavigationType
    ) -> Bool {
        switch navigation {
        case .snippetPopup(let navigationSnippet):
            if receivedSnippets.firstIndex(of: navigationSnippet) != nil {
                return false
            }
        }
        return true
    }
}

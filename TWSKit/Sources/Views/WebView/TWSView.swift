//
//  TWSView.swift
//  TWSKit
//
//  Created by Miha Hozjan on 27. 05. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI
import TWSModels

public struct TWSView<
    LoadingView: View,
    ErrorView: View
>: View {

    @State var pageTitle: String
    let snippet: TWSSnippet
    let handler: TWSManager
    let displayID: String
    let loadingView: () -> LoadingView
    let errorView: (Error) -> ErrorView
    let onPageTitleChanged: ((String) -> Void)?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var loadingState: TWSLoadingState

    public init(
        snippet: TWSSnippet,
        using handler: TWSManager,
        displayID id: String,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        loadingState: Binding<TWSLoadingState>,
        @ViewBuilder loadingView: @escaping () -> LoadingView,
        @ViewBuilder errorView: @escaping (Error) -> ErrorView,
        onPageTitleChanged: ((String) -> Void)? = nil
    ) {
        self.snippet = snippet
        self.handler = handler
        self.displayID = id
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._loadingState = loadingState
        self.loadingView = loadingView
        self.errorView = errorView
        self.onPageTitleChanged = onPageTitleChanged
        self._pageTitle = .init(initialValue: "")
    }

    public var body: some View {
        ZStack {
            _TWSView(
                snippet: snippet,
                using: handler,
                displayID: displayID,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                loadingState: $loadingState,
                pageTitle: $pageTitle
            )
            .frame(width: loadingState.showView ? nil : 0, height: loadingState.showView ? nil : 0)
            .id(snippet.id)
            .id(handler.store.snippets.snippets[id: snippet.id]?.updateCount ?? 0)
            .onChange(of: pageTitle) { _, pageTitle in
                onPageTitleChanged?(pageTitle)
            }

            ZStack {
                switch loadingState {
                case .idle, .loading:
                    loadingView()

                case .loaded:
                    EmptyView()

                case let .failed(error):
                    errorView(error)
                }
            }
            .frame(width: loadingState.showView ? 0 : nil, height: loadingState.showView ? 0 : nil)
        }
    }
}

private struct _TWSView: View {

    @State var height: CGFloat = 16
    @State private var backCommandID = UUID()
    @State private var forwardCommandID = UUID()
    @State private var networkObserver = NetworkMonitor()

    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var loadingState: TWSLoadingState
    @Binding var pageTitle: String

    let snippet: TWSSnippet
    let handler: TWSManager
    let displayID: String

    init(
        snippet: TWSSnippet,
        using handler: TWSManager,
        displayID id: String,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        loadingState: Binding<TWSLoadingState>,
        pageTitle: Binding<String>
    ) {
        self.snippet = snippet
        self.handler = handler
        self.displayID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self._loadingState = loadingState
        self._pageTitle = pageTitle
    }

    var body: some View {
        WebView(
            url: snippet.target,
            displayID: displayID,
            isConnectedToNetwork: networkObserver.isConnected,
            dynamicHeight: $height,
            pageTitle: $pageTitle,
            backCommandId: backCommandID,
            forwardCommandID: forwardCommandID,
            snippetHeightProvider: handler.snippetHeightProvider,
            onHeightCalculated: { height in
                handler.set(height: height, for: snippet, displayID: displayID)
            },
            canGoBack: $canGoBack,
            canGoForward: $canGoForward,
            loadingState: $loadingState
        )
        .frame(idealHeight: height)
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name.Navigation.Back)
        ) { notification in
            guard NotificationBuilder.shouldReact(to: notification, as: snippet, displayID: displayID)
            else { return }
            backCommandID = UUID()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name.Navigation.Forward)
        ) { notification in
            guard NotificationBuilder.shouldReact(to: notification, as: snippet, displayID: displayID)
            else { return }
            forwardCommandID = UUID()
        }
    }
}

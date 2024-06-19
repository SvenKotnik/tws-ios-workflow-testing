//
//  TWSView.swift
//  TWSKit
//
//  Created by Miha Hozjan on 27. 05. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI
import WebKit
import TWSModels

public struct TWSView: View {

    @State var height: CGFloat
    let snippet: TWSSnippet
    let handler: TWSManager
    let displayID: String

    public init(
        snippet: TWSSnippet,
        using handler: TWSManager,
        displayID id: String
    ) {
        let height = handler.store.snippets.snippets[id: snippet.id]?.displayInfo.displays[id]?.height

        self.snippet = snippet
        self.handler = handler
        self._height = .init(initialValue: height ?? .zero)
        self.displayID = id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        WebView(
            identifier: snippet.id,
            url: snippet.target,
            dynamicHeight: $height
        )
        .frame(idealHeight: height)
        .onChange(of: height) { _, height in
            guard height > 0 else { return }
            handler.set(height: height, for: snippet, displayID: displayID)
        }
        .id(handler.store.snippets.snippets[id: snippet.id]?.updateCount ?? 0)
    }
}

struct WebView: UIViewRepresentable {

    @Binding var dynamicHeight: CGFloat
    let identifier: UUID
    let url: URL

    init(
        identifier: UUID,
        url: URL,
        dynamicHeight: Binding<CGFloat>
    ) {
        self.identifier = identifier
        self.url = url
        self._dynamicHeight = dynamicHeight
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.bounces = false
        webView.scrollView.isScrollEnabled = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: self.url))

        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}

extension WebView {

    class Coordinator: NSObject {

        var parent: WebView
        var heightWorkItem: DispatchWorkItem?

        init(_ parent: WebView) {
            self.parent = parent
        }
    }
}

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

import SwiftUI
import WebKit
@_spi(Internals) import TWSModels

struct WebView: UIViewRepresentable {

    @Environment(\.navigator) var navigator
    @Environment(\.interceptor) var interceptor
    @Environment(\.errorView) var errorView
    @Environment(\.loadingView) var loadingView
    @Binding var dynamicHeight: CGFloat
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Bindable var state: TWSViewState
    // This helps distinguish between parent and modal views
    @State var wkWebView: WKWebView? = nil

    var id: String { snippet.id }
    var targetURL: URL { snippet.target }
    let snippet: TWSSnippet
    let preloadedResources: [TWSSnippet.Attachment: ResourceResponse]
    let locationServicesBridge: LocationServicesBridge
    let cameraMicrophoneServicesBridge: CameraMicrophoneServicesBridge
    let displayID: String
    let isConnectedToNetwork: Bool
    let openURL: URL?
    let snippetHeightProvider: SnippetHeightProvider
    let navigationProvider: NavigationProvider
    let onUniversalLinkDetected: (URL) -> Void
    let downloadCompleted: ((TWSDownloadState) -> Void)?
    let enablePullToRefresh: Bool

    init(
        snippet: TWSSnippet,
        preloadedResources: [TWSSnippet.Attachment: ResourceResponse],
        locationServicesBridge: LocationServicesBridge,
        cameraMicrophoneServicesBridge: CameraMicrophoneServicesBridge,
        displayID: String,
        isConnectedToNetwork: Bool,
        dynamicHeight: Binding<CGFloat>,
        openURL: URL?,
        snippetHeightProvider: SnippetHeightProvider,
        navigationProvider: NavigationProvider,
        onUniversalLinkDetected: @escaping @Sendable @MainActor (URL) -> Void,
        canGoBack: Binding<Bool>,
        canGoForward: Binding<Bool>,
        downloadCompleted: ((TWSDownloadState) -> Void)?,
        state: Bindable<TWSViewState>,
        enablePullToRefresh: Bool
    ) {
        self.snippet = snippet
        self.preloadedResources = preloadedResources
        self.locationServicesBridge = locationServicesBridge
        self.cameraMicrophoneServicesBridge = cameraMicrophoneServicesBridge
        self.displayID = displayID
        self.isConnectedToNetwork = isConnectedToNetwork
        self._dynamicHeight = dynamicHeight
        self.openURL = openURL
        self.snippetHeightProvider = snippetHeightProvider
        self.navigationProvider = navigationProvider
        self.onUniversalLinkDetected = onUniversalLinkDetected
        self._dynamicHeight = dynamicHeight
        self._canGoBack = canGoBack
        self._canGoForward = canGoForward
        self.downloadCompleted = downloadCompleted
        self._state = state
        self.enablePullToRefresh = enablePullToRefresh
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()

        #if DEBUG
        controller.addUserScript(WKUserScript(source: interceptConsoleLogs(controller: controller).value, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        #endif

        // Location Permissions
        let locationPermissionsHandler = _handleLocationPermissions(with: controller)

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        let agent = (webView.value(forKey: "userAgent") as? String) ?? ""
        webView.customUserAgent = (agent + " " + "TheWebSnippet").trimmingCharacters(in: .whitespacesAndNewlines)
        webView.scrollView.bounces = true
        webView.scrollView.isScrollEnabled = true
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        navigator.delegate = context.coordinator

        if enablePullToRefresh {
            // process content on reloads
            context.coordinator.pullToRefresh.enable(on: webView) {
                reloadWithProcessedResources(webView: webView)
            }
        }

        // Process content on first load
        loadProcessedContent(webView: webView)
        context.coordinator.observe(heightOf: webView)
        context.coordinator.observe(currentUrlOf: webView)
        context.coordinator.webView = webView

        updateState(for: webView, loadingState: .loading)

        logger.debug("INIT WKWebView \(webView.hash) bind to \(id)")
        
        // Binding for permissions
        Task {
            await locationPermissionsHandler.bind(
                webView: webView,
                to: locationServicesBridge
            )
        }
        
        // Hold reference to created WKWebView to know which view is parent and which are presentable children
        Task {
            wkWebView = webView
        }
        
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            self,
            snippetHeightProvider: snippetHeightProvider,
            navigationProvider: navigationProvider,
            downloadCompleted: downloadCompleted,
            interceptor: interceptor,
            state: $state
        )
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        logger.debug("DEINIT WKWebView \(uiView.hash)")
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        uiView.configuration.userContentController.removeAllScriptMessageHandlers()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Save state at the end

        defer {
            context.coordinator.isConnectedToNetwork = isConnectedToNetwork
            context.coordinator.openURL = openURL
        }

        // Regained network connection

        let regainedNetworkConnection = !context.coordinator.isConnectedToNetwork && isConnectedToNetwork
        var stateUpdated: Bool?

        if regainedNetworkConnection, case .failed = state.loadingState {
            if uiView.url == nil {
                updateState(for: uiView, loadingState: .loading)
                reloadWithProcessedResources(webView: uiView)
                stateUpdated = true
            } else if !uiView.isLoading {
                reloadWithProcessedResources(webView: uiView)
            }
        }

        // OAuth - Google sign-in

        if
            context.coordinator.redirectedToSafari,
            let openURL,
            openURL != context.coordinator.openURL
            {
            context.coordinator.redirectedToSafari = false
            
            do {
                try navigationProvider.continueNavigation(with: openURL, from: uiView)
            } catch NavigationError.viewControllerNotFound {
                uiView.load(URLRequest(url: openURL))
            } catch {
                logger.err("Failed to continue navigation: \(error)")
            }
        }

        // Update state

        if let stateUpdated, !stateUpdated {
            updateState(for: uiView)
        }
    }

    // MARK: - Helpers

    func updateState(
        for webView: WKWebView,
        loadingState: TWSLoadingState? = nil,
        dynamicHeight: CGFloat? = nil
    ) {
        // Mandatory to hop the thread, because of UI layout change
        DispatchQueue.main.async {
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward

            if let dynamicHeight {
                self.dynamicHeight = dynamicHeight
            }

            if let loadingState {
                self.state.loadingState = loadingState
            }
        }
    }
    
    func loadProcessedContent(webView: WKWebView) {
        let key = TWSSnippet.Attachment(url: targetURL, contentType: .html)
        
        if let preloaded = preloadedResources[key] {
            logger.debug("Load from raw HTML: \(targetURL.absoluteString)")
            let htmlToLoad = _handleMustacheProccesing(preloadedHTML: preloaded.data, snippet: snippet)
            webView.loadSimulatedRequest(URLRequest(url: preloaded.responseUrl ?? self.targetURL), responseHTML: htmlToLoad)
        } else {
            logger.debug("Load from url: \(targetURL.absoluteString)")
            var urlRequest = URLRequest(url: self.targetURL)
            snippet.headers?.forEach { header in
                urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
            }
            webView.load(urlRequest)
        }
    }

    // MARK: - Permissions

    private func _handleLocationPermissions(
        with controller: WKUserContentController
    ) -> JavaScriptLocationAdapter {
        let jsURL = Bundle.module
            .url(forResource: "JavaScriptLocationInjection", withExtension: "js")!
        // swiftlint:disable:next force_try
        let jsContent = try! String(contentsOf: jsURL, encoding: .utf8)
        controller.addUserScript(.init(source: jsContent, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        let jsLocationServices = JavaScriptLocationAdapter()
        JavaScriptLocationMessageHandler.addObserver(for: jsLocationServices)
        controller.add(
            JavaScriptLocationMessageHandler(),
            name: "locationHandler"
        )

        return jsLocationServices
    }
    
    private func _handleMustacheProccesing(preloadedHTML: String, snippet: TWSSnippet) -> String {
        if snippet.engine == .mustache {
            let mustacheRenderer = MustacheRenderer()
            let convertedProps = mustacheRenderer.convertDictPropsToData(snippet.props)
            return mustacheRenderer.renderMustache(preloadedHTML, convertedProps, addDefaultValues: true)
        }
        
        return preloadedHTML
    }
    
    func reloadWithProcessedResources(
        webView: WKWebView
    ) {
        let key = TWSSnippet.Attachment(url: targetURL, contentType: .html)
        let resource = preloadedResources[key]
        if let currentUrl = state.currentUrl, currentUrl != resource?.responseUrl {
            webView.load(URLRequest(url: currentUrl))
        } else {
            loadProcessedContent(webView: webView)
        }
    }
}

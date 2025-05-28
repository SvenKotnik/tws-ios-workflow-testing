////
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
import UIKit
import WebKit
import SwiftUI

class WebViewWithErrorOverlay: UIViewController {
    let webView: WKWebView
    let navigationProvider: NavigationProvider
    private var activityIndicator: UIActivityIndicatorView
    private var popupDelegate: PopupNavigationDelegate?
    let locationServiceBridge = DefaultLocationServicesManager()
    let jsLocationServices = JavaScriptLocationAdapter()
    
    
    // MARK: - Init
    init(webView: WKWebView, navigationProvider: NavigationProvider) {
        self.webView = webView
        self.navigationProvider = navigationProvider
        self.activityIndicator = {
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.startAnimating()
            activityIndicator.tintColor = .black
            return activityIndicator
        }()
        
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        self.activityIndicator = UIActivityIndicatorView()
        self.navigationProvider = NavigationProviderImpl()
        super.init(coder: coder)
    }
    
    @objc private func appMovedToForeground() {
        if self.webView.url == nil {
            do {
                try navigationProvider.didClose(webView: webView, animated: true, completion: nil)
            } catch {
                logger.err("[UI \(webView.hash)] Failed to close the web view: \(webView)")
            }
        }
    }

    // MARK: - Setup

    override func viewDidLoad() {
        JavaScriptLocationMessageHandler.addObserver(for: jsLocationServices)

        Task {
            await jsLocationServices.bind(webView: self.webView, to: locationServiceBridge)
        }
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        self.popupDelegate = PopupNavigationDelegate(coordinator: webView.navigationDelegate, onEndNavigation: { [weak self] in self?.hideLoadingIndicator() })
        webView.navigationDelegate = popupDelegate
        setupSubviews()
    }
    
    private func setupSubviews() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    func hideLoadingIndicator() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }

    // MARK: - Public API

    func showError(err: Error, errorView: ((Error) -> AnyView)) {
        let customErrorView = errorView(err)
        
        let customErrorViewVC = UIHostingController(rootView: customErrorView)
        addChild(customErrorViewVC)
        view.addSubview(customErrorViewVC.view)
        customErrorViewVC.didMove(toParent: self)
        customErrorViewVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        if let errView = customErrorViewVC.view {
            NSLayoutConstraint.activate([
                errView.topAnchor.constraint(equalTo: self.view.topAnchor),
                errView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
                errView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                errView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor)
            ])
        }
    }
    
    deinit {
        let tempLocationService = jsLocationServices
        Task { @MainActor in
            JavaScriptLocationMessageHandler.removeObserver(for: tempLocationService)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

class PopupNavigationDelegate: NSObject, WKNavigationDelegate {
    let onEndNavigation: () -> Void
    let coordinator: WKNavigationDelegate?
    
    init(coordinator: WKNavigationDelegate?, onEndNavigation: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onEndNavigation = onEndNavigation
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onEndNavigation()
        guard let navigation else { return }
        coordinator?.webView?(webView, didFinish: navigation)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onEndNavigation()
        guard let navigation else { return }
        coordinator?.webView?(webView, didFail: navigation, withError: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onEndNavigation()
        guard let navigation else { return }
        coordinator?.webView?(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        guard let navigation else { return }
        coordinator?.webView?(webView, didStartProvisionalNavigation: navigation)
    }

    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        guard let navigation else { return }
        coordinator?.webView?(webView, didReceiveServerRedirectForProvisionalNavigation: navigation)
    }

    func webView(
        _ webView: WKWebView,
        didCommit navigation: WKNavigation!
    ) {
        guard let navigation else { return }
        coordinator?.webView?(webView, didCommit: navigation)
    }

    func webViewWebContentProcessDidTerminate(
        _ webView: WKWebView
    ) {
        coordinator?.webViewWebContentProcessDidTerminate?(webView)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        coordinator?.webView?(webView, decidePolicyFor: navigationAction, preferences: preferences, decisionHandler: decisionHandler)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        coordinator?.webView?(webView, decidePolicyFor: navigationResponse, decisionHandler: decisionHandler)
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @MainActor @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        coordinator?.webView?(webView, didReceive: challenge, completionHandler: completionHandler)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        coordinator?.webView?(webView, navigationResponse: navigationResponse, didBecome: download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        coordinator?.webView?(webView, navigationAction: navigationAction, didBecome: download)
    }
}

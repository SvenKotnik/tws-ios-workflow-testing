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

import Foundation
import WebKit

extension WebView.Coordinator: TWSViewNavigatorDelegate {
    func load(url: URLRequest) {
        assert(webView != nil)
        webView?.load(url)
    }
    
    func navigateBack() {
        assert(webView != nil)
        webView?.goBack()
    }

    func navigateForward() {
        assert(webView != nil)
        webView?.goForward()
    }

    func reload() {
        assert(webView != nil)
        guard let webView else { return }
        parent.reloadWithProcessedResources(webView: webView)
    }
    
    func pushState(path: String) {
        webView?.evaluateJavaScript(
            """
            window.history.pushState({}, '', '\(path)');
            window.dispatchEvent(new Event('popstate'));
            """
        )
    }
    
    func evaluateJavaScript(script: String, completionHandler: (@MainActor @Sendable (Any?, (any Error)?) -> Void)? = nil) {
        assert(webView != nil)
        webView?.evaluateJavaScript(script, completionHandler: completionHandler)
    }
}

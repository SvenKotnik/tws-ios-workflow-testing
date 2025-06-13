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
import WebKit

final class RedirectHandler: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession,
                        task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
        #if DEBUG
        logger.info("Redirecting request from \(response.url?.absoluteString ?? "unknown") to \(request.url?.absoluteString ?? "unknown")")
        #endif
        
        Task { @MainActor in
            if let headerFields = response.allHeaderFields as? [String: String],
               let url = response.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
                cookies.forEach {
                    WKWebsiteDataStore.default().httpCookieStore.setCookie($0)
                }
            }
        }
        
        completionHandler(request)
    }
}

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
import TWSModels
import SwiftUI

@MainActor
public class TWSOverlayProvider: NSObject, UISceneDelegate {
    private var hostingControllers: [TWSSnippet : UIHostingController<TWSOverlayView>] = [:]

    public static let shared = TWSOverlayProvider()
    private var queuedSnippets: [(TWSSnippet, TWSManager)] = []

    private override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(tryPresentingOverlay),
            name: UIScene.didActivateNotification,
            object: nil)
    }

    // MARK: Public
    
    ///
    /// Tries so display provided snippet as a full screen overlay over current window. If window does not yet exist it is queued and displayed when the application notifies that UIScene has appeared.
    /// - Parameter snippet: An instance of TWSSnippet that will be displayed
    ///
    public func showOverlay(snippet: TWSSnippet, manager: TWSManager) {
        queuedSnippets.append((snippet, manager))
        tryPresentingOverlay()
    }
    
    // MARK: Private
    
    @objc private func tryPresentingOverlay() {
        guard let window = getWindowScene() else {
            logger.info("TWSNotificationsOverlay: No active window found")
            return
        }
        
        while let snippet = queuedSnippets.first {
            var controller: UIHostingController<TWSOverlayView>!
            let notificationView = TWSOverlayView(snippet: snippet.0, twsManager: snippet.1, dismiss: { snippet in
                self.removeHostingController(snippet)
            })
            controller = UIHostingController(rootView: notificationView)
            controller.view.backgroundColor = .clear
            controller.view.frame = window.bounds
            controller.view.isUserInteractionEnabled = true
            
            window.addSubview(controller.view)
            window.bringSubviewToFront(controller.view)
            hostingControllers.updateValue(controller, forKey: snippet.0)
            
            queuedSnippets.remove(at: 0)
        }
    }
    
    private func removeHostingController(_ snippet: TWSSnippet) {
        guard let controller = hostingControllers[snippet] else { return }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()

        hostingControllers.removeValue(forKey: snippet)
        
        print("after removing remains \(hostingControllers.count) hosting controllers \(hostingControllers)")
    }
    
    private func getWindowScene() -> UIWindow? {
        if let windowScene = UIApplication.shared
            .connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
               return window
        }
        
        return nil
    }
}

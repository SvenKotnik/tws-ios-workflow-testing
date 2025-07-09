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
import NotificationCenter

struct LocalNotificationProvider {
    private let notificationCenter = UNUserNotificationCenter.current()
    
    func sendNotification(completionHandler: @escaping ((PermissionStatus) -> Void)) async {
        let uuid = UUID().uuidString
        let request = UNNotificationRequest(identifier: uuid, content: createNotification(), trigger: nil)
        
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .ephemeral, .provisional:
                completionHandler(.allowed)
                return
            case .denied:
                completionHandler(.notAllowed)
                return
            case .notDetermined:
                Task {
                    await requestAuthorization { granted, error in
                        if granted {
                            Task {
                                await sendNotification { result in completionHandler(result) }
                            }
                        }
                    }
                }
            @unknown default:
                break
            }
        }
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Notification could not be shown: \(error.localizedDescription)")
        }
    }
    
    private func requestAuthorization(completionHandler: @escaping (Bool, Error?) -> Void) async {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                completionHandler(false, nil)
                return
            }
            
            if granted {
                completionHandler(true, nil)
            } else {
                completionHandler(false, nil)
            }
        }
    }
    
    private func createNotification() -> UNMutableNotificationContent {
        let notification = UNMutableNotificationContent()
        notification.title = String(localized: "notification.title")
        notification.body = String(localized: "notification.body")
        
        notification.userInfo.updateValue("snippet_push", forKey: "type")
        notification.userInfo.updateValue("example/notificationExample", forKey: "path")
        
        notification.sound = .default
        
        return notification
    }
    
    enum PermissionStatus {
        case allowed, notAllowed
    }
}

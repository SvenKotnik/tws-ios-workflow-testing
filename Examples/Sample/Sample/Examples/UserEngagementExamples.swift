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

import SwiftUI
import TWS

struct UserEngagementExamples: View {
    @Environment(TWSManager.self) var tws
    @State private var displayAlert: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 16) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text(String(localized: "engagement.title.top"))
                    Text(String(localized: "engagement.title.bottom"))
                }
                .bold()
                .font(.title)
                    
                Spacer()
            }
            .padding()
            Divider()
                .frame(maxWidth: .infinity, idealHeight: 1)
            
            VStack {
                UserEngagementButton(
                    title: String(localized: "engagement.notification.title"),
                    content: String(localized: "engagement.notification.body"),
                    action: {
                        Task { await LocalNotificationProvider().sendNotification { status in
                            switch status {
                            case .notAllowed:
                                displayAlert = true
                            case .allowed:
                                break
                            }
                        } }
                    })
                UserEngagementButton(
                    title: String(localized: "engagement.campaign.title"),
                    content: String(localized: "engagement.campaign.body"),
                    action: {
                        tws.logEvent("campaign_example")
                    })
            }
            .alert(String(localized: "notification.denied.title"), isPresented: $displayAlert) {
                Button(String(localized: "alert.settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(String(localized: "alert.cancel"), role: .cancel) {
                    displayAlert = false
                }
            } message: {
                Text(String(localized: "notification.denied.body"))
            }
            .padding()
            Spacer()
        }
    }
}


private struct UserEngagementButton: View {
    var title: String
    var content: String
    var action: () -> Void
    
    var body: some View {
        Button { action() } label: {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(content)
                    .font(.callout)
                    .opacity(0.6)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .foregroundStyle(.primary)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.foreground.opacity(0.1), lineWidth: 1)
        }
    }
}

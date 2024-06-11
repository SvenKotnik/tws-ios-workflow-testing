//
//  SettingsView.swift
//  TWSDemo
//
//  Created by Miha Hozjan on 23. 05. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI
import TWSKit

struct SettingsView: View {

    var body: some View {
        NavigationStack {
            VStack {
                Text("v\(_appVersion())")
                Button("Get logs") {
                    Task {
                        shareLogReport()
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Settings")
        }
    }
}

private func _appVersion() -> String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    return "\(version) (\(build))"
}

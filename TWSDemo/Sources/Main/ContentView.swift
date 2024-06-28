//
//  ContentView.swift
//  TWSDemo
//
//  Created by Miha Hozjan on 23. 05. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI
import TWSKit

struct ContentView: View {

    @State private var viewModel = ContentViewModel()
    @Environment(TWSViewModel.self) private var twsViewModel

    var body: some View {
        TabView(
            selection: $viewModel.tab,
            content: {
                SnippetsView()
                    .tabItem {
                        Text("List")
                        Image(systemName: "list.bullet")
                    }
                    .tag(ContentViewModel.Tab.snippets)

                SnippetsTabView()
                    .tabItem {
                        Text("Tab")
                        Image(systemName: "house")
                    }

                SettingsView()
                    .tabItem {
                        Text("Settings")
                        Image(systemName: "gear")
                    }
                    .tag(ContentViewModel.Tab.settings)
            }
        )
        .onChange(of: twsViewModel.qrLoadedSnippet, { _, _ in
            viewModel.fullscreenSnippet = twsViewModel.qrLoadedSnippet
            viewModel.displayFullscreenSnippet = twsViewModel.qrLoadedSnippet != nil
        })
        .onOpenURL(perform: { url in
            twsViewModel.handleIncomingUrl(url)
        })
        .fullScreenCover(isPresented: $viewModel.displayFullscreenSnippet) {
            if let snippet = viewModel.fullscreenSnippet {
                VStack {
                    HStack {
                        Text("TWS - \(viewModel.webViewTitle)")
                        Spacer()
                        Button(action: {
                            twsViewModel.qrLoadedSnippet = nil
                        }, label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 22))
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(.black)
                        })
                    }
                    .padding()
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.black),
                        alignment: .bottom
                    )
                    TWSView(
                        snippet: snippet,
                        using: twsViewModel.manager,
                        displayID: snippet.id.uuidString,
                        onPageTitleChanged: { newTitle in
                            viewModel.webViewTitle = newTitle
                        })
                }
            }
        }
    }
}

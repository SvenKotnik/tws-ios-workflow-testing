//
//  SnippetsTabView.swift
//  TWS
//
//  Created by Miha Hozjan on 5. 06. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI
import TWS
import TWSModels

@MainActor
struct SnippetsTabView: View {

    @Environment(TWSManager.self) var twsManager
    @State private var selectedId: TWSSnippet.ID?

    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    ForEach(
                        Array(zip(
                            twsManager.tabs.indices,
                            twsManager.tabs
                        )),
                        id: \.1.id
                    ) { idx, snippet in
                        ZStack {
                            SnippetView(snippet: snippet)
                                .zIndex(Double(selectedId == snippet.id ? twsManager.tabs.count : idx))
                                .opacity(selectedId != snippet.id ? 0 : 1)
                        }
                    }
                }

                ViewThatFits {
                    _selectionView()

                    ScrollView(.horizontal, showsIndicators: false) {
                        _selectionView()
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .onAppear {
                // Safe to force cast, because of the first segment
                guard selectedId == nil || !twsManager.tabs.map(\.id).contains(selectedId!) else { return }
                selectedId = twsManager.tabs.first?.id
            }
            .onChange(of: twsManager.tabs.first?.id) { _, newValue in
                guard selectedId == nil else { return }
                selectedId = newValue
            }
        }
    }

    @ViewBuilder
    private func _selectionView() -> some View {
        if twsManager.tabs.count > 1 {
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(
                    Array(zip(
                        twsManager.tabs.indices,
                        twsManager.tabs
                    )),
                    id: \.1.id
                ) { _, item in
                    Button {
                        selectedId = item.id
                    } label: {
                        VStack {
                            if let icon = item.props?[.tabIcon, as: \.string] {
                                Group {
                                    if UIImage(named: icon) != nil {
                                        Image(icon)
                                    } else if UIImage(systemName: icon) != nil {
                                        Image(systemName: icon)
                                    } else {
                                        Image("broken_image")
                                    }
                                }
                                .foregroundColor(selectedId == item.id ? Color.accentColor : Color.gray)
                            }

                            if let tabName = item.props?[.tabName, as: \.string] {
                                Text(tabName)
                                    .foregroundColor(selectedId == item.id ? Color.accentColor : Color.gray)
                            }

                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(height: selectedId == item.id ? 1 : 0)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 1)
                        }
                        .frame(minWidth: 75, maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

private struct SnippetView: View {

    let snippet: TWSSnippet
    @State private var info = TWSViewInfo()
    @State private var navigator = TWSViewNavigator()

    var body: some View {
        @Bindable var info = info

        VStack(alignment: .leading) {
            HStack {
                Button {
                    navigator.goBack()
                } label: {
                    Image(systemName: "arrowshape.backward.fill")
                }
                .disabled(!navigator.canGoBack)

                Button {
                    navigator.goForward()
                } label: {
                    Image(systemName: "arrowshape.forward.fill")
                }
                .disabled(!navigator.canGoForward)

                Button {
                    navigator.reload()
                } label: {
                    Image(systemName: "repeat")
                }
            }

            Divider()

            TWSView(
                snippet: snippet,
                info: $info
            )
            .twsBind(navigator: navigator)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .border(Color.black)
        }
    }
}

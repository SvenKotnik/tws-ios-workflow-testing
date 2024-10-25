//
//  PrrojectView.swift
//  TWSKit
//
//  Created by Miha Hozjan on 25. 07. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI
import TWSKit
import TWSUI

@MainActor
struct ProjectView: View {

    @State private var viewModel: ProjectViewModel
    @State private var selectedID: TWSSnippet.ID

    init(viewModel: ProjectViewModel, selectedID: TWSSnippet.ID) {
        _viewModel = .init(initialValue: viewModel)
        _selectedID = .init(initialValue: selectedID)
    }

    var body: some View {
        TabView(selection: $selectedID) {
            ForEach(viewModel.tabSnippets) { snippet in
                ProjectSnippetView(
                    snippet: snippet,
                    organizationID: "\(viewModel.manager.id.hashValue)"
                )
                .tabItem {
                    Text("\(snippet.props?[.tabName, as: \.string] ?? "")")
                    if let icon = snippet.props?[.tabIcon, as: \.string] {
                        Image(systemName: icon)
                    }
                }
                .tag(snippet.id)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            await viewModel.start()
            await viewModel.startupInitTasks()
        }
        .sheet(item: $viewModel.universalLinkLoadedProject) {
            ProjectView(viewModel: $0.viewModel, selectedID: $0.selectedID)
                .twsEnable(using: viewModel.universalLinkLoadedProject!.viewModel.manager)
        }
        .fullScreenCover(isPresented: $viewModel.presentPopups, content: {
            TWSPopupView(isPresented: $viewModel.presentPopups, manager: viewModel.manager)
                .twsEnable(using: viewModel.manager)
        })
    }
}

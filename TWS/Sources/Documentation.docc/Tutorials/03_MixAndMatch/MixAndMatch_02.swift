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

import SwiftUI
import TWS

struct HomeView: View {

    @Environment(TWSManager.self) var tws

    var  body: some View {
        TabView {
            ForEach(tws.snippets()) { snippet in
                RemoteSnippetTab(snippet: snippet)
            }
        }
    }
}

struct RemoteSnippetTab: View {

    let snippet: TWSSnippet

    var body: some View {
        VStack {
            TWSView(snippet: snippet)

            DevelopmentView(id: snippet.id)
        }
    }
}

struct DevelopmentView: View {

    let id: String

    var body: some View {
        TWSView(
            // A local snippet
            snippet: .init(
                id: id,
                target: URL(string: "https://dev.tws.io?id=\(id)")
            )
        )
    }
}

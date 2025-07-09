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

struct ContentView: View {

    @Environment(TWSManager.self) var tws
    @State private var interceptor = CustomInterceptor()

    var body: some View {
        ZStack {
            if let snippet = tws.snippets().first(where: { $0.id == "customInterceptors" }) {
                TWSView(snippet: snippet)
                    .twsBind(interceptor: interceptor)
                    .sheet(item: $interceptor.destination) { destination in
                        switch destination {
                        case .customTabsExample:
                            CustomTabsExample()
                                .twsBind(interceptor: DefaultInterceptor())
                            
                        case .mustacheExample:
                            CustomMustacheExample()
                                .twsBind(interceptor: DefaultInterceptor())
                            
                        case .injectionExample:
                            CustomInjectionExample()
                                .twsBind(interceptor: DefaultInterceptor())

                        case .permissionsExample:
                            CustomPermissionExample()
                                .twsBind(interceptor: DefaultInterceptor())
                        case .userEngagementExample:
                            UserEngagementExamples()
                        }
                    }
            }
        }
    }
}

@MainActor
@Observable
class CustomInterceptor: TWSViewInterceptor {

    var destination: Destination?

    func handleUrl(
        _ url: URL
    ) -> Bool {
        if let destination = Destination(rawValue: url.lastPathComponent) {
            self.destination = destination
            return true
        }

        return false
    }
}

extension CustomInterceptor {

    enum Destination: String, Identifiable {
        var id: String { rawValue }

        case customTabsExample
        case mustacheExample
        case injectionExample
        case permissionsExample
        case userEngagementExample
    }
}

@MainActor
@Observable
class DefaultInterceptor: TWSViewInterceptor {

    func handleUrl(
        _ url: URL
    ) -> Bool {
        return false
    }
}

extension [TWSSnippet] {
    func sortByTabSortKey() -> [TWSSnippet] {
        return self.sorted(by: { $0.props?["tabSortKey"]?.string ?? "" < $1.props?["tabSortKey"]?.string ?? "" })
    }
}

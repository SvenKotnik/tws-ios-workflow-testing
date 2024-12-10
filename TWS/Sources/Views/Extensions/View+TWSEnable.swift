//
//  View+EnableTWS.swift
//  TWSAPI
//
//  Created by Miha Hozjan on 22. 10. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI

extension View {

    public func twsEnable(
        using manager: TWSManager
    ) -> some View {
        self
            .environment(manager)
            .environment(\.presenter, LivePresenter(manager: manager))
    }

    public func twsEnable(
        configuration: TWSConfiguration
    ) -> some View {
        ModifiedContent(
            content: self,
            modifier: _TWSPlaceholder(
                manager: TWSFactory.new(with: configuration)
            )
        )
    }

    public func twsEnable(
        sharedSnippet: TWSProject
    ) -> some View {
        ModifiedContent(
            content: self,
            modifier: _TWSPlaceholder(
                manager: TWSFactory.new(with: sharedSnippet)
            )
        )
    }
}

private struct _TWSPlaceholder: ViewModifier {

    @State private var manager: TWSManager

    init(manager: TWSManager) {
        self._manager = .init(initialValue: manager)
    }

    func body(content: Content) -> some View {
        content
            .twsEnable(using: manager)
    }
}

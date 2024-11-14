//
//  View+TWSInterceptor.swift
//  TheWebSnippet
//
//  Created by Luka Kit on 13. 11. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import SwiftUI

extension EnvironmentValues {

    @Entry var interceptor: TWSViewInterceptor?
}

extension View {

    public func twsBind(
        interceptor: TWSViewInterceptor
    ) -> some View {
        self
            .environment(\.interceptor, interceptor)
    }
}

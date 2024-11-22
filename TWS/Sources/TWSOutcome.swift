//
//  TWSOutcome.swift
//  TWS
//
//  Created by Miha Hozjan on 15. 11. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import TWSModels

/// A generic outcome class for managing a collection of items and their loading state.
@MainActor
@Observable
public class TWSOutcome<T>: @preconcurrency CustomDebugStringConvertible {

    /// The items currently managed by this outcome.
    public internal(set) var items: T

    /// The loading state of the items.
    public internal(set) var state: TWSLoadingState

    /// Initializes a new `TWSOutcome` instance.
    ///
    /// - Parameters:
    ///   - items: The initial items to manage.
    ///   - state: The initial loading state of the items.
    public init(items: T, state: TWSLoadingState) {
        self.items = items
        self.state = state
    }

    /// A callable function that returns the items.
    ///
    /// This allows the `TWSOutcome` instance to be used like a function to retrieve its items.
    ///
    /// - Returns: The items managed by this outcome.
    ///
    /// ```swift
    /// tws.snippets()
    /// // Instead of:
    /// // tws.snippets.items
    /// ```
    public func callAsFunction() -> T {
        items
    }

    /// A debug description of the current state of the outcome.
    ///
    /// - Returns: A string representation of the outcome's current state and items.
    public var debugDescription: String {
        switch state {
        case .idle:
            return "Idle"

        case .loading:
            return "Loading..."

        case .loaded:
            if let items = items as? [TWSSnippet] {
                return "Loaded (\(items.count))"
            } else {
                return "Loaded"
            }

        case let .failed(error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

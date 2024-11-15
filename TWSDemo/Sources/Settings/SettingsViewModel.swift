//
//  SettingsViewModel.swift
//  TWS
//
//  Created by Miha Hozjan on 6. 06. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation

@MainActor
@Observable
class SettingsViewModel {

    var selection: Selection {
        didSet {
            UserDefaults.standard.set(
                selection.rawValue,
                forKey: "_settingsSourceSelection"
            )
        }
    }

    var logsGenerationInProgress: Bool = false
    var validUrls: [URL] = []
    var invalidFootnote: String?

    init() {
        if
            let value = UserDefaults.standard.string(forKey: "_settingsSourceSelection"),
            let type = Selection(rawValue: value) {
            self.selection = type
        } else {
            self.selection = .apiResponse
        }
    }

    func validate(localURLs: String) {
        var invalidUrls = [String]()
        var validUrls = [URL]()

        for line in localURLs.split(separator: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedLine), url.scheme != nil {
                validUrls.append(url)
            } else if !trimmedLine.isEmpty {
                invalidUrls.append(trimmedLine)
            }
        }

        self.validUrls = validUrls

        if !invalidUrls.isEmpty {
            let listFormatter = ListFormatter()
            var invalidFootnote = "The following URLs will be ignored because they are not valid:"
            invalidFootnote += listFormatter.string(from: invalidUrls) ?? ""

            self.invalidFootnote = invalidFootnote
        } else {
            invalidFootnote = nil
        }
    }
}

extension SettingsViewModel {

    enum Selection: String, CaseIterable {
        case apiResponse = "API Response"
        case localURLs = "Local URLs"
    }
}

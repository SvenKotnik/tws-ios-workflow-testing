//
//  WeakBox.swift
//  TWSKit
//
//  Created by Miha Hozjan on 25. 07. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation

final class WeakBox<T: AnyObject> {
    weak var box: T?

    init(_ box: T) {
        self.box = box
    }
}

//
//  TCAPipelineAdapter+Main.swift
//  TWSKit
//
//  Created by Miha Hozjan on 6. 08. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import Combine
@_implementationOnly import TWSCore
@_implementationOnly import ComposableArchitecture

struct MainReducer: MVVMAdapter {

    let publisher: PassthroughSubject<TWSStreamEvent, Never>
    let casePath: AnyCasePath<TWSCoreFeature.Action, TWSStreamEvent> = .tws
    let childReducer: any Reducer<TWSCoreFeature.State, TWSCoreFeature.Action> = TWSCoreFeature()
}

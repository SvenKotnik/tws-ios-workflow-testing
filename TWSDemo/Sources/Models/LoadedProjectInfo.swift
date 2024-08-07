//
//  LoadedProjectInfo.swift
//  TWSAPI
//
//  Created by Miha Hozjan on 26. 07. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation
import TWSKit

struct LoadedProjectInfo: Identifiable {

    let viewModel: ProjectViewModel
    let selectedID: UUID

    var id: TWSManager.ID {
        viewModel.manager.id
    }
}

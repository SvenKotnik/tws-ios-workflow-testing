////
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

import Foundation
import ComposableArchitecture
import TWSModels

let cacheFolder = ".Cache"

private extension URL {
    
    static func resources() -> URL {
        .documentsDirectory
        .appendingPathComponent(cacheFolder)
        .appending(component: "local_resources.json")
    }
}

extension SharedKey where Self == Sharing.FileStorageKey<[TWSSnippet.Attachment: ResourceResponse]>.Default {
    // periphery:ignore - used with compiler flg
    static func resources() -> Self {
        Self[.fileStorage(.resources()), default: [:]]
    }
}

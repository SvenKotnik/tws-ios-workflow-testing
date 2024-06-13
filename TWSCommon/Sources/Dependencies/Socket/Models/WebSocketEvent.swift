//
//  WebSocketEvent.swift
//  TWSAPI
//
//  Created by Miha Hozjan on 13. 06. 24.
//  Copyright © 2024 Inova IT, d.o.o. All rights reserved.
//

import Foundation

public enum WebSocketEvent {
    case didConnect, didDisconnect, receivedMessage(Data)
}

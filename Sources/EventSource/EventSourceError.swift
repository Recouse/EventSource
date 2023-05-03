//
//  EventSourceError.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public enum EventSourceError: Error {
    case undefinedConnectionError
    case connectionError(statusCode: Int, response: Data)
}

//
//  EventSourceError.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public enum EventSourceError: LocalizedError {
    case undefinedConnectionError
    
    case connectionError(statusCode: Int, response: Data)

    /// The ``EventSource/EventSource/DataTask`` event stream is already being consumed by another task.
    /// A stream can only be consumed by one task at a time.
    case alreadyConsumed

    public var errorDescription: String? {
        switch self {
        case .alreadyConsumed:
            "The `DataTask` events stream is already being consumed by another task."
        default:
            nil
        }
    }
}

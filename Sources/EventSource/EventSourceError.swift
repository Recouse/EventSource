//
//  EventSourceError.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//

import Foundation

enum EventSourceError: Error {
    case undefinedConnectionError
    case connectionError(statusCode: Int, response: Data)
}

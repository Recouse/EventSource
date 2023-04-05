//
//  EventSourceError.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//

enum EventSourceError: Error {
    case connectionError(Error)
    case undefinedConnectionError
}

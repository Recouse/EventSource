//
//  Extensions.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//

extension Sequence {
    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
    }
}

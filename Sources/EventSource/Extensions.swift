//
//  Extensions.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
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

extension Task where Success == Never, Failure == Never {
    static func sleep(duration: Double) async throws {
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}

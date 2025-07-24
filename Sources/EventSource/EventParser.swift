//
//  EventParser.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public protocol EventParser: Sendable {
    mutating func parse(_ data: Data) -> [EVEvent]
}

/// ``ServerEventParser`` is used to parse text data into ``ServerEvent``.
struct ServerEventParser: EventParser {
    private let mode: EventSource.Mode
    private var buffer = Data()

    init(mode: EventSource.Mode = .default) {
        self.mode = mode
    }


    mutating func parse(_ data: Data) -> [EVEvent] {
        let (separatedMessages, remainingData) = (buffer + data).split(separators: doubleSeparators)
        
        buffer = remainingData
        return parseBuffer(for: separatedMessages)
    }

    private func parseBuffer(for rawMessages: [Data]) -> [EVEvent] {
        // Parse data to ServerMessage model
        let messages: [ServerEvent] = rawMessages.compactMap { ServerEvent.parse(from: $0, mode: mode) }

        return messages
    }
}

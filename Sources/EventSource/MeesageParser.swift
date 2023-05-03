//
//  MessageParser.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public class MessageParser {
    public static let lf: UInt8 = 0x0A
    public static let semicolon: UInt8 = 0x3a
    
    public private(set) var lastMessageId: String = ""
    
    public init() {
        
    }
    
    public func parsed(from data: Data) -> [ServerMessage] {
        // Split message with double newline
        let rawMessages: [Data]
        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            rawMessages = data.split(separator: [Self.lf, Self.lf])
        } else {
            rawMessages = data.split(by: [Self.lf, Self.lf])
        }
        
        // Parse data to ServerMessage model
        let messages: [ServerMessage] = rawMessages.compactMap(ServerMessage.parse(from:))
        
        // Update last message ID
        if let lastMessageWithId = messages.last(where: { $0.id != nil }) {
            lastMessageId = lastMessageWithId.id ?? ""
        }
        
        return messages
    }
    
    public func reset() {
        lastMessageId = ""
    }
}

fileprivate extension Data {
    @available(macOS, deprecated: 13.0, obsoleted: 13.0, message: "This method is not recommended on macOS 13.0+")
    @available(iOS, deprecated: 16.0, obsoleted: 16.0, message: "This method is not recommended on iOS 16.0+")
    @available(watchOS, deprecated: 9.0, obsoleted: 9.0, message: "This method is not recommended on watchOS 9.0+")
    @available(tvOS, deprecated: 16.0, obsoleted: 16.0, message: "This method is not recommended on tvOS 16.0+")
    func split(by separator: [UInt8]) -> [Data] {
        let doubleNewline = Data(separator)
        var splits: [Data] = []
        var currentIndex = 0
        var range: Range<Data.Index>?

        while true {
            range = self.range(of: doubleNewline, options: [], in: currentIndex..<self.count)
            if let foundRange = range {
                splits.append(self.subdata(in: currentIndex..<foundRange.lowerBound))
                currentIndex = foundRange.upperBound
            } else {
                splits.append(self.subdata(in: currentIndex..<self.count))
                break
            }
        }

        return splits
    }
}

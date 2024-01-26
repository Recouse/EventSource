//
//  ServerMessage.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public struct ServerMessage {
    public var id: String?
    public var event: String?
    public var data: String?
    public var time: String?
    
    init(
        id: String? = nil,
        event: String? = nil,
        data: String? = nil,
        time: String? = nil
    ) {
        self.id = id
        self.event = event
        self.data = data
        self.time = time
    }
    
    private func isEmpty() -> Bool {
        if let id, !id.isEmpty {
            return false
        }
        
        if let event, !event.isEmpty {
            return false
        }
        
        if let data, !data.isEmpty {
            return false
        }
        
        if let time, !time.isEmpty {
            return false
        }
        
        return true
    }
    
    public static func parse(from data: Data) -> ServerMessage? {
        let rows = data.split(separator: MessageParser.lf) // Separate message fields
        
        var message = ServerMessage()
        
        for row in rows {
            let keyValue = row.split(separator: MessageParser.colon, maxSplits: 1)
            let key = keyValue[0].utf8String.trimmingCharacters(in: .whitespaces)
            let value = keyValue[1].utf8String.trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "id":
                message.id = value.trimmingCharacters(in: .whitespacesAndNewlines)
            case "event":
                message.event = value.trimmingCharacters(in: .whitespacesAndNewlines)
            case "data":
                if let existingData = message.data {
                    message.data = existingData + "\n" + value.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    message.data = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case "time":
                message.time = value.trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                continue
            }
        }
        
        if message.isEmpty() {
            return nil
        }
        
        return message
    }
}

fileprivate extension Data {
    var utf8String: String {
        String(decoding: self, as: UTF8.self)
    }
}

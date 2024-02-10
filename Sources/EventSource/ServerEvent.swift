//
//  ServerEvent.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public struct ServerEvent {
    public var id: String?
    public var event: String?
    public var data: String?
    public var other: [String: String]?
    public var time: String?
    
    init(
        id: String? = nil,
        event: String? = nil,
        data: String? = nil,
        other: [String: String]? = nil,
        time: String? = nil
    ) {
        self.id = id
        self.event = event
        self.data = data
        self.other = other
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
        
        if let other, !other.isEmpty {
            return false
        }
        
        if let time, !time.isEmpty {
            return false
        }
        
        return true
    }
    
    public static func parse(from data: Data) -> ServerEvent? {
        let rows = data.split(separator: EventParser.lf) // Separate message fields
        
        var message = ServerEvent()
        
        for row in rows {
            // Skip the line if it is empty or it starts with a colon character
            if row.isEmpty, row.first == EventParser.colon {
                continue
            }
            
            let keyValue = row.split(separator: EventParser.colon, maxSplits: 1)
            let key = keyValue[0].utf8String.trimmingCharacters(in: .whitespaces)
            let value = keyValue[safe: 1]?.utf8String.trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "id":
                message.id = value?.trimmingCharacters(in: .whitespaces)
            case "event":
                message.event = value?.trimmingCharacters(in: .whitespaces)
            case "data":
                if let existingData = message.data {
                    message.data = existingData + "\n" + (value?.trimmingCharacters(in: .whitespaces) ?? "")
                } else {
                    message.data = value?.trimmingCharacters(in: .whitespaces)
                }
            case "time":
                message.time = value?.trimmingCharacters(in: .whitespaces)
            default:
                // If the line is not empty but does not contain a color character
                // add it to the other fields using the whole line as the field name,
                // and the empty string as the field value.
                if row.contains(EventParser.colon) == false {
                    let string = row.utf8String
                    if var other = message.other {
                        other[string] = ""
                        message.other = other
                    } else {
                        message.other = [string: ""]
                    }
                }
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

fileprivate extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }
        return self[index]
    }
}

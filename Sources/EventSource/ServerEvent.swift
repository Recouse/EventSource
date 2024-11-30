//
//  ServerEvent.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

/// Protocol for defining a basic event structure. It is used by the ``EventParser``
/// and should be implemented as a custom type when a custom ``EventParser`` is required.
public protocol EVEvent: Sendable {
    var id: String? { get }
    var event: String? { get }
    var data: String? { get }
    var other: [String: String]? { get }
    var time: String? { get }
}

public extension EVEvent {
    /// Checks if all event fields are empty.
    var isEmpty: Bool {
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
}

/// Default implementation of ``EventSourceEvent`` used in the package.
public struct ServerEvent: EVEvent {
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
    
    public static func parse(from data: Data, mode: EventSource.Mode = .default) -> ServerEvent? {
        let rows: [Data] = switch mode {
        case .default:
            data.split(separator: ServerEventParser.lf) // Separate event fields
        case .dataOnly:
            [data] // Do not split data in data-only mode
        }

        var message = ServerEvent()
        
        for row in rows {
            // Skip the line if it is empty or it starts with a colon character
            if row.isEmpty, row.first == ServerEventParser.colon {
                continue
            }
            
            let keyValue = row.split(separator: ServerEventParser.colon, maxSplits: 1)
            let key = keyValue[0].utf8String.trimmingCharacters(in: .whitespaces)
            let value = keyValue[safe: 1]?.utf8String.trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "id":
                message.id = value
            case "event":
                message.event = value
            case "data":
                if let existingData = message.data {
                    message.data = existingData + "\n" + (value ?? "")
                } else {
                    message.data = value
                }
            case "time":
                message.time = value
            default:
                // If the line is not empty but does not contain a colon character
                // add it to the other fields using the whole line as the field name,
                // and the empty string as the field value.
                if row.contains(ServerEventParser.colon) == false {
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
        
        if message.isEmpty {
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

package extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < endIndex else {
            return nil
        }
        return self[index]
    }
}

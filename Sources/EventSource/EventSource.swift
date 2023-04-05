//
//  EventSource.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//

import AsyncAlgorithms
import Foundation

///
/// An `EventSource` instance opens a persistent connection to an HTTP server,
/// which sends events in `text/event-stream` format.
/// The connection remains open until closed by calling `close()`.
///
public class EventSource: NSObject {
    /// State of the connection.
    public enum ReadyState: Int {
        case connecting = 0
        case open = 1
        case closed = 2
    }
    
    /// Events channel subject type.
    public enum ChannelSubject {
        case error(Error)
        case message(ServerMessage)
        case open
        case closed
    }
    
    private static let defaultTimeoutInterval: TimeInterval = 300
    
    private static let reconnectionInterval: TimeInterval = 1.0
        
    /// A number representing the state of the connection.
    public private(set) var readyState: ReadyState = .connecting
    
    /// A string representing the URL of the source.
    public let request: URLRequest
    
    private let messageParser: MessageParser
    
    /// Server-sent events channel.
    public let events: AsyncChannel<ChannelSubject> = .init()
    
    private var urlSessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            HTTPHeaderField.accept: Accept.eventStream,
            HTTPHeaderField.cacheControl: CacheControl.noStore,
            HTTPHeaderField.lastEventID: messageParser.lastMessageId
        ]
        configuration.timeoutIntervalForRequest = Self.defaultTimeoutInterval
        configuration.timeoutIntervalForResource = Self.defaultTimeoutInterval
        return configuration
    }
    
    private var urlSession: URLSession?
        
    private var dataTask: URLSessionDataTask?
    
    // Reconnection manage
    
    private let maxReconnectionInterval: TimeInterval
    
    private let backoffResetDelay: TimeInterval
    
    private var backoffCount: Int = 0
    
    private var lastConnected: Date?
    
    public init(
        request: URLRequest,
        messageParser: MessageParser = .init(),
        maxReconnectionInterval: TimeInterval = 30.0,
        backoffResetDelay: TimeInterval = 60.0
    ) {
        self.request = request
        self.messageParser = messageParser
        self.maxReconnectionInterval = maxReconnectionInterval
        self.backoffResetDelay = backoffResetDelay
                
        super.init()
    }
    
    public func connect() {
        urlSession = URLSession(
            configuration: urlSessionConfiguration,
            delegate: self,
            delegateQueue: nil
        )
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
        readyState = .connecting
    }
    
    /// Closes the connection, if one is made,
    /// and sets the `readyState` property to `.closed`.
    public func close() {
        let previousState = readyState
        readyState = .closed
        messageParser.reset()
        dataTask?.cancel()
        if previousState == .open {
            Task {
                await events.send(.closed)
                events.finish()
            }
        }
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }
    
    private func parseMessages(from data: Data) {
        let messages = messageParser.parsed(from: data)
        
        Task {
            await messages.asyncForEach {
                await events.send(.message($0))
            }
        }
    }
    
    // MARK: - Fileprivate
    
    fileprivate func reconnectionDelay() -> TimeInterval {
        backoffCount += 1
        
        if let lastConnected, Date().timeIntervalSince(lastConnected) >= backoffResetDelay {
            backoffCount = 0
        }
        
        lastConnected = nil
        return min(backoffResetDelay, Self.reconnectionInterval + Double(backoffCount))
    }
    
    fileprivate func setClosed() {
        readyState = .closed
        
        Task {
            await events.send(.closed)
        }
    }
    
    fileprivate func setOpen() {
        readyState = .open
        
        Task {
            await events.send(.open)
        }
    }
    
    fileprivate func sendErrorEvent(with error: Error) {
        Task {
            await events.send(.error(error))
        }
    }
}

extension EventSource: URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard readyState != .closed else {
            return
        }
        
        guard readyState != .open else {
            setClosed()
            return
        }
        
        if let error {
            sendErrorEvent(with: error)
        }
        
        let delay = reconnectionDelay()
        Task.delayed(interval: delay) {
            connect()
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard readyState != .closed else {
            completionHandler(.cancel)
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        
        // Stop connection when 204 response code, otherwise keep open
        if httpResponse.statusCode != 204, 200...299 ~= httpResponse.statusCode {
            lastConnected = Date()
            
            if readyState != .open {
                setOpen()
            }
            
            completionHandler(.allow)
        } else {
            setClosed()
            completionHandler(.cancel)
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        parseMessages(from: data)
    }
}

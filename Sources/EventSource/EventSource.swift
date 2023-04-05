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
public final class EventSource {
    /// State of the connection.
    public enum ReadyState: Int {
        case none = -1
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
            
    /// A number representing the state of the connection.
    public private(set) var readyState: ReadyState = .none
    
    /// A string representing the URL of the source.
    public let request: URLRequest
    
    private let messageParser: MessageParser
    
    public var maxRetryCount: Int
    
    public var retryDelay: Double
    
    private var currentRetryCount: Int = 0
    
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
    
    private var sessionDelegate = SessionDelegate()
    
    private var sesionDelegateTask: Task<Void, Error>?
    
    public init(
        request: URLRequest,
        messageParser: MessageParser = .init(),
        maxRetryCount: Int = 3,
        retryDelay: Double = 1.0
    ) {
        self.request = request
        self.messageParser = messageParser
        self.maxRetryCount = maxRetryCount
        self.retryDelay = retryDelay
    }
    
    deinit {
        sesionDelegateTask?.cancel()
        dataTask?.cancel()
        urlSession?.invalidateAndCancel()
    }
    
    public func connect() {
        guard readyState == .none || readyState == .closed else {
            return
        }
        
        urlSession = URLSession(
            configuration: urlSessionConfiguration,
            delegate: sessionDelegate,
            delegateQueue: nil
        )
        dataTask = urlSession?.dataTask(with: request)
        
        handleDelegateUpdates()
        
        dataTask?.resume()
        readyState = .connecting
    }
    
    private func handleDelegateUpdates() {
        let stream = AsyncStream<SessionDelegate.Event> { continuation in
            sessionDelegate.onEvent = { event in
                continuation.yield(event)
            }
        }
        
        sesionDelegateTask = Task {
            try Task.checkCancellation()
            
            for await event in stream {
                switch event {
                case let .didCompleteWithError(error):
                    // Retry if error occured
                    do {
                        try await handleSessionError(error)
                    } catch {
                        guard currentRetryCount < maxRetryCount else {
                            return
                        }
                        currentRetryCount += 1
                        connect()
                    }
                case let .didReceiveResponse(response, completionHandler):
                    await handleSessionResponse(response, completionHandler: completionHandler)
                case let .didReceiveData(data):
                    await parseMessages(from: data)
                }
            }
        }
    }
    
    private func handleSessionError(_ error: Error?) async throws {
        guard readyState != .closed else {
            return
        }
        
        guard readyState != .open else {
            await setClosed()
            return
        }
        
        if let error {
            await sendErrorEvent(with: error)
            throw EventSourceError.connectionError(error)
        } else {
            throw EventSourceError.undefinedConnectionError
        }
    }
    
    private func handleSessionResponse(
        _ response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) async {
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
            if readyState != .open {
                await setOpen()
            }
            
            completionHandler(.allow)
        } else {
            await setClosed()
            completionHandler(.cancel)
        }
    }
    
    /// Closes the connection, if one is made,
    /// and sets the `readyState` property to `.closed`.
    public func close() async {
        let previousState = readyState
        readyState = .closed
        messageParser.reset()
        sesionDelegateTask?.cancel()
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        
        if previousState == .open {
            await events.send(.closed)
            events.finish()
        }
    }
    
    private func parseMessages(from data: Data) async {
        let messages = messageParser.parsed(from: data)
        
        await messages.asyncForEach {
            await events.send(.message($0))
        }
    }
    
    // MARK: - Fileprivate
        
    fileprivate func setClosed() async {
        readyState = .closed
        
        await events.send(.closed)
    }
    
    fileprivate func setOpen() async {
        readyState = .open
        
        await events.send(.open)
    }
    
    fileprivate func sendErrorEvent(with error: Error) async {
        await events.send(.error(error))
    }
}

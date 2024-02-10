//
//  EventSource.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

///
/// An `EventSource` instance opens a persistent connection to an HTTP server,
/// which sends events in `text/event-stream` format.
/// The connection remains open until closed by calling `close()`.
///
public struct EventSource {
    /// State of the connection.
    public enum ReadyState: Int {
        case none = -1
        case connecting = 0
        case open = 1
        case closed = 2
    }
    
    /// Event type.
    public enum EventType {
        case error(Error)
        case event(ServerEvent)
        case open
        case closed
    }
    
    private let eventParser: EventParser
    
    public var timeoutInterval: TimeInterval
    
    public init(
        eventParser: EventParser = .live,
        timeoutInterval: TimeInterval = 300
    ) {
        self.eventParser = eventParser
        self.timeoutInterval = timeoutInterval
    }
    
    public func dataTask(for urlRequest: URLRequest) -> DataTask {
        DataTask(
            urlRequest: urlRequest,
            eventParser: eventParser,
            timeoutInterval: timeoutInterval
        )
    }
}

public extension EventSource {
    /// An EventSource task that handles connecting to the URLRequest and creating an event stream.
    ///
    /// Creation of a task is exclusively handled by ``EventSource``. A new task can be created by calling
    /// ``EventSource/EventSource/dataTask(for:)`` method on the EventSource instance. After creating a task,
    /// it can be started by iterating event stream returned by ``DataTask/events()``.
    final class DataTask {
        /// A value representing the state of the connection.
        public private(set) var readyState: ReadyState = .none
        
        /// Last event's ID string value.
        ///
        /// Sent in a HTTP request header and used when a user is to reestablish the connection.
        public private(set) var lastMessageId: String = ""
        
        /// A URLRequest of the events source.
        public let urlRequest: URLRequest
        
        private let eventParser: EventParser
        
        private let timeoutInterval: TimeInterval
        
        private var urlSession: URLSession?
        
        private var sessionDelegate = SessionDelegate()
        
        private var sessionDelegateTask: Task<Void, Error>?
        
        private var urlSessionDataTask: URLSessionDataTask?
                        
        private var httpResponseErrorStatusCode: Int?
        
        private var urlSessionConfiguration: URLSessionConfiguration {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = [
                HTTPHeaderField.accept: Accept.eventStream,
                HTTPHeaderField.cacheControl: CacheControl.noStore,
                HTTPHeaderField.lastEventID: lastMessageId
            ]
            configuration.timeoutIntervalForRequest = self.timeoutInterval
            configuration.timeoutIntervalForResource = self.timeoutInterval
            return configuration
        }
                
        internal init(
            urlRequest: URLRequest,
            eventParser: EventParser,
            timeoutInterval: TimeInterval
        ) {
            self.urlRequest = urlRequest
            self.eventParser = eventParser
            self.timeoutInterval = timeoutInterval
        }
        
        /// Creates and returns event stream.
        public func events() -> AsyncStream<EventType> {
            AsyncStream { continuation in
                continuation.onTermination = { @Sendable _ in
                    close()
                }
                
                urlSession = URLSession(
                    configuration: urlSessionConfiguration,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                
                sessionDelegate.onEvent = { event in
                    switch event {
                    case let .didCompleteWithError(error):
                        handleSessionError(error)
                    case let .didReceiveResponse(response, completionHandler):
                        handleSessionResponse(response, completionHandler: completionHandler)
                    case let .didReceiveData(data):
                        parseMessages(from: data)
                    }
                }
                
                urlSessionDataTask = urlSession!.dataTask(with: urlRequest)
                urlSessionDataTask!.resume()
                readyState = .connecting
                
                func handleSessionError(_ error: Error?) {
                    guard readyState != .closed else {
                        close()
                        return
                    }
                    
                    // Send error event
                    if let error {
                        sendErrorEvent(with: error)
                    }
                            
                    // Close connection
                    close()
                }
                
                func handleSessionResponse(
                    _ response: URLResponse,
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
                    guard httpResponse.statusCode != 204 else {
                        completionHandler(.cancel)
                        close()
                        return
                    }
                    
                    if 200...299 ~= httpResponse.statusCode {
                        if readyState != .open {
                            setOpen()
                        }
                    } else {
                        httpResponseErrorStatusCode = httpResponse.statusCode
                    }
                    
                    completionHandler(.allow)
                }
                
                /// Closes the connection, if one was made,
                /// and sets the `readyState` property to `.closed`.
                /// - Returns: State before closing.
                @Sendable func close() {
                    let previousState = self.readyState
                    cancel()
                    if previousState == .open {
                        continuation.yield(.closed)
                    }
                }
                
                func parseMessages(from data: Data) {
                    if let httpResponseErrorStatusCode {
                        self.httpResponseErrorStatusCode = nil
                        handleSessionError(
                            EventSourceError.connectionError(statusCode: httpResponseErrorStatusCode, response: data)
                        )
                        return
                    }
                    
                    let events = eventParser.parse(data)
                    
                    // Update last message ID
                    if let lastMessageWithId = events.last(where: { $0.id != nil }) {
                        lastMessageId = lastMessageWithId.id ?? ""
                    }
                    
                    events.forEach {
                        continuation.yield(.event($0))
                    }
                }
                
                func setOpen() {
                    readyState = .open
                    continuation.yield(.open)
                }
                
                func sendErrorEvent(with error: Error) {
                    continuation.yield(.error(error))
                }
            }
        }
        
        /// Cancels the task.
        ///
        /// ## Notes:
        /// The event stream supports cooperative task cancellation. However, it should be noted that
        /// canceling the parent Task only cancels the underlying `URLSessionDataTask` of
        /// ``EventSource/EventSource/DataTask``; this does not actually stop the ongoing request.
        public func cancel() {
            readyState = .closed
            lastMessageId = ""
            sessionDelegateTask?.cancel()
            urlSessionDataTask?.cancel()
            urlSession?.invalidateAndCancel()
        }
    }
}

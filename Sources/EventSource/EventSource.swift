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
        case message(ServerMessage)
        case open
        case closed
    }
    
    private let messageParser: MessageParser
    
    public var timeoutInterval: TimeInterval
    
    public init(
        messageParser: MessageParser = .live,
        timeoutInterval: TimeInterval = 300
    ) {
        self.messageParser = messageParser
        self.timeoutInterval = timeoutInterval
    }
    
    public func dataTask(for urlRequest: URLRequest) -> DataTask {
        DataTask(
            urlRequest: urlRequest,
            messageParser: messageParser,
            timeoutInterval: timeoutInterval
        )
    }
}

public extension EventSource {
    class DataTask {
        /// A number representing the state of the connection.
        public private(set) var readyState: ReadyState = .none
        
        public private(set) var lastMessageId: String = ""
        
        /// A string representing the URL of the source.
        public let urlRequest: URLRequest
        
        private let messageParser: MessageParser
        
        private let timeoutInterval: TimeInterval
        
        private var continuation: AsyncStream<EventType>.Continuation?
        
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
            messageParser: MessageParser,
            timeoutInterval: TimeInterval
        ) {
            self.urlRequest = urlRequest
            self.messageParser = messageParser
            self.timeoutInterval = timeoutInterval
        }
        
        public func events() -> AsyncStream<EventType> {
            AsyncStream { continuation in
                continuation.onTermination = { @Sendable [weak self] _ in
                    self?.close()
                }
                
                self.continuation = continuation
                
                urlSession = URLSession(
                    configuration: urlSessionConfiguration,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                
                sessionDelegate.onEvent = { [weak self] event in
                    guard let self else { return }
                    
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
            }
        }
        
        private func handleSessionError(_ error: Error?) {
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
        
        private func handleSessionResponse(
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
        @Sendable private func close() {
            let previousState = self.readyState
            if previousState != .closed {
                continuation?.yield(.closed)
                continuation?.finish()
            }
            cancel()
        }
        
        private func parseMessages(from data: Data) {
            if let httpResponseErrorStatusCode {
                self.httpResponseErrorStatusCode = nil
                handleSessionError(
                    EventSourceError.connectionError(statusCode: httpResponseErrorStatusCode, response: data)
                )
                return
            }
            
            let messages = messageParser.parse(data)
            
            // Update last message ID
            if let lastMessageWithId = messages.last(where: { $0.id != nil }) {
                lastMessageId = lastMessageWithId.id ?? ""
            }
            
            messages.forEach {
                continuation?.yield(.message($0))
            }
        }
        
        private func setOpen() {
            readyState = .open
            continuation?.yield(.open)
        }
        
        private func sendErrorEvent(with error: Error) {
            continuation?.yield(.error(error))
        }
        
        public func cancel() {
            readyState = .closed
            lastMessageId = ""
            sessionDelegateTask?.cancel()
            urlSessionDataTask?.cancel()
            urlSession?.invalidateAndCancel()
        }
    }
}

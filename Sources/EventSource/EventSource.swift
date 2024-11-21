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

/// The global actor used for isolating ``EventSource/EventSource/DataTask``.
@globalActor public actor EventSourceActor: GlobalActor {
    public static let shared = EventSourceActor()
}

///
/// An `EventSource` instance opens a persistent connection to an HTTP server,
/// which sends events in `text/event-stream` format.
/// The connection remains open until closed by calling `close()`.
///
public struct EventSource: Sendable {
    public enum Mode: Sendable {
        case `default`
        case dataOnly
    }

    /// State of the connection.
    public enum ReadyState: Int {
        case none = -1
        case connecting = 0
        case open = 1
        case closed = 2
    }
    
    /// Event type.
    public enum EventType: Sendable {
        case error(Error)
        case event(EVEvent)
        case open
        case closed
    }

    private let mode: Mode

    private let eventParser: EventParser
    
    public var timeoutInterval: TimeInterval
    
    public init(
        mode: Mode = .default,
        eventParser: EventParser? = nil,
        timeoutInterval: TimeInterval = 300
    ) {
        self.mode = mode
        if let eventParser {
            self.eventParser = eventParser
        } else {
            self.eventParser = ServerEventParser(mode: mode)
        }
        self.timeoutInterval = timeoutInterval
    }

    @EventSourceActor
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
    @EventSourceActor final class DataTask {
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

        private var continuation: AsyncStream<EventType>.Continuation?

        private var urlSession: URLSession?

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
            if urlSessionDataTask != nil {
                return AsyncStream { continuation in
                    continuation.yield(.error(EventSourceError.alreadyConsumed))
                    continuation.finish()
                }
            }

            return AsyncStream { continuation in
                let sessionDelegate = SessionDelegate()
                let sesstionDelegateTask = Task { [weak self] in
                    for await event in sessionDelegate.eventStream {
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
                }

                #if compiler(>=6.0)
                continuation.onTermination = { @Sendable [weak self] _ in
                    sesstionDelegateTask.cancel()
                    Task { await self?.close() }
                }
                #else
                continuation.onTermination = { @Sendable _ in
                    sesstionDelegateTask.cancel()
                    Task { [weak self] in
                        await self?.close()
                    }
                }
                #endif

                self.continuation = continuation


                urlSession = URLSession(
                    configuration: urlSessionConfiguration,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )

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
        private func close() {
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
            
            let events = eventParser.parse(data)

            // Update last message ID
            if let lastMessageWithId = events.last(where: { $0.id != nil }) {
                lastMessageId = lastMessageWithId.id ?? ""
            }
            
            events.forEach {
                continuation?.yield(.event($0))
            }
        }
        
        private func setOpen() {
            readyState = .open
            continuation?.yield(.open)
        }

        private func sendErrorEvent(with error: Error) {
            continuation?.yield(.error(error))
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
            urlSessionDataTask?.cancel()
            urlSession?.invalidateAndCancel()
        }
    }
}

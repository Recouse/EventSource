//
//  SessionDelegate.swift
//  EventSource
//
//  Copyright © 2023 Firdavs Khaydarov (Recouse). All rights reserved.
//  Licensed under the MIT License.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class SessionDelegate: NSObject, URLSessionDataDelegate {
    enum Event: Sendable {
        case didCompleteWithError(Error?)
        case didReceiveResponse(URLResponse, @Sendable (URLSession.ResponseDisposition) -> Void)
        case didReceiveData(Data)
    }

    private let internalStream = AsyncStream<Event>.makeStream()

    var eventStream: AsyncStream<Event> { internalStream.stream }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        internalStream.continuation.yield(.didCompleteWithError(error))
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @Sendable @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        internalStream.continuation.yield(.didReceiveResponse(response, completionHandler))
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        internalStream.continuation.yield(.didReceiveData(data))
    }
}

//
//  MMNetworkReachabilityManager.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

#if !os(watchOS)

import Foundation
import Network

public class MMNetworkReachabilityManager {

    public enum NetworkReachabilityStatus {
        case unknown
        case notReachable
        case reachable(ConnectionType)
    }

    public enum ConnectionType {
        case ethernetOrWiFi
        case wwan
    }

    public typealias Listener = (NetworkReachabilityStatus) -> Void

    // MARK: - Properties

    public var isReachable: Bool { return isReachableOnWWAN || isReachableOnEthernetOrWiFi }

    var isReachableOnWWAN: Bool { return networkReachabilityStatus == .reachable(.wwan) }

    var isReachableOnEthernetOrWiFi: Bool { return networkReachabilityStatus == .reachable(.ethernetOrWiFi) }

    var networkReachabilityStatus: NetworkReachabilityStatus {
        guard let currentPath = currentPath else { return .unknown }
        return statusForPath(currentPath)
    }

    var listenerQueue: DispatchQueue = DispatchQueue.main

    public var listener: Listener?

    private var monitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.mobile-messaging.reachability", qos: .utility)
    private var currentPath: NWPath?
    private var previousStatus: NetworkReachabilityStatus = .unknown

    // MARK: - Initialization

    public init() {}

    deinit {
        stopListening()
    }

    // MARK: - Listening

    @discardableResult
    public func startListening() -> Bool {
        stopListening()
        previousStatus = .unknown
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.currentPath = path
            let newStatus = self.statusForPath(path)
            guard newStatus != self.previousStatus else { return }
            self.previousStatus = newStatus
            self.listenerQueue.async {
                self.listener?(newStatus)
            }
        }
        monitor.start(queue: monitorQueue)
        self.monitor = monitor
        return true
    }

    public func stopListening() {
        monitor?.cancel()
        monitor = nil
    }

    // MARK: - Internal

    private func statusForPath(_ path: NWPath) -> NetworkReachabilityStatus {
        guard path.status == .satisfied else { return .notReachable }
        if path.usesInterfaceType(.cellular) {
            return .reachable(.wwan)
        }
        return .reachable(.ethernetOrWiFi)
    }
}

// MARK: -

extension MMNetworkReachabilityManager.NetworkReachabilityStatus: Equatable {}

public func ==(
    lhs: MMNetworkReachabilityManager.NetworkReachabilityStatus,
    rhs: MMNetworkReachabilityManager.NetworkReachabilityStatus)
    -> Bool
{
    switch (lhs, rhs) {
    case (.unknown, .unknown):
        return true
    case (.notReachable, .notReachable):
        return true
    case let (.reachable(lhsConnectionType), .reachable(rhsConnectionType)):
        return lhsConnectionType == rhsConnectionType
    default:
        return false
    }
}

#endif

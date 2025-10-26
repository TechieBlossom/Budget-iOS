//
//  NetworkMonitor.swift
//  Budget
//
//  Created for Supabase integration
//

import Foundation
import Network

/// Monitor network connectivity status
@MainActor
@Observable
class NetworkMonitor {
    // MARK: - Properties

    /// Whether device is connected to network
    private(set) var isConnected = false

    /// Whether device is using cellular connection
    private(set) var isExpensive = false

    /// Current connection type
    private(set) var connectionType: ConnectionType = .unknown

    /// Network path monitor
    private let monitor: NWPathMonitor

    /// Monitor queue
    private let queue = DispatchQueue(label: "NetworkMonitor")

    /// Callback for connection changes
    var onConnectionChange: ((Bool) -> Void)?

    // MARK: - Connection Type

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown
    }

    // MARK: - Initialization

    init() {
        monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Monitoring

    /// Start monitoring network status
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.connectionType = self.getConnectionType(from: path)

                // Notify if connection changed
                if wasConnected != self.isConnected {
                    self.onConnectionChange?(self.isConnected)
                }
            }
        }

        monitor.start(queue: queue)
    }

    /// Stop monitoring network status
    private func stopMonitoring() {
        monitor.cancel()
    }

    /// Get connection type from network path
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        } else {
            return .unknown
        }
    }
}

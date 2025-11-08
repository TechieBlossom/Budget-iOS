//
//  SyncState.swift
//  Budget
//
//  Sync state for optimistic UI pattern
//

import Foundation

enum SyncState: Equatable {
    case syncing
    case synced(Date)
    case offline
    case error(String)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.syncing, .syncing), (.offline, .offline):
            return true
        case (.synced(let d1), .synced(let d2)):
            return d1 == d2
        case (.error(let e1), .error(let e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

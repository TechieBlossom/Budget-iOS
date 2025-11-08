//
//  BudgetError.swift
//  Budget
//
//  Created for sync refactor
//

import Foundation

enum BudgetError: Error, LocalizedError {
    case noInternet
    case notAuthenticated
    case supabaseFailed(String)
    case localDBFailed(String)
    case dataInconsistent

    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No internet connection. Please check your network and try again."
        case .notAuthenticated:
            return "Please sign in to continue."
        case .supabaseFailed(let msg):
            return "Server error: \(msg)"
        case .localDBFailed(let msg):
            return "Local cache error: \(msg). Your data is safe on the server."
        case .dataInconsistent:
            return "Data sync issue. Please try reloading the app."
        }
    }
}

//
//  SupabaseClient.swift
//  Budget
//
//  Created for Supabase integration
//

import Foundation
import Supabase

/// Singleton manager for Supabase client
@MainActor
class SupabaseClientManager {
    /// Shared instance
    static let shared = SupabaseClientManager()

    /// Supabase client instance
    let client: SupabaseClient

    private init() {
        // Initialize Supabase client with URL and anon key
        let url: URL = SupabaseConfig.url
        let key: String = SupabaseConfig.anonKey

        // Configure custom JSON encoder/decoder for proper date formatting
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        // Custom date decoding that handles both DATE (yyyy-MM-dd) and TIMESTAMPTZ (ISO8601)
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with time first (for TIMESTAMPTZ fields)
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try DATE format (yyyy-MM-dd) for DATE fields
            iso8601Formatter.formatOptions = [.withFullDate]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string: \(dateString)"
            )
        }

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                db: .init(
                    schema: "public",
                    encoder: encoder,
                    decoder: decoder
                ),
                auth: .init(
                    autoRefreshToken: true
                )
            )
        )
    }
}

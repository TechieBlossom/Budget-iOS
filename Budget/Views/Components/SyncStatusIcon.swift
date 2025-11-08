//
//  SyncStatusIcon.swift
//  Budget
//
//  Sync status indicator for navigation bar
//

import SwiftUI

struct SyncStatusIcon: View {
    let syncState: SyncState
    @State private var showPopup = false

    var body: some View {
        Button {
            showPopup = true
        } label: {
            Group {
                switch syncState {
                case .syncing:
                    Image(systemName: "icloud.and.arrow.down")
                        .symbolEffect(.rotate, options: .repeating)
                case .synced:
                    Image(systemName: "checkmark.icloud")
                case .offline:
                    Image(systemName: "icloud.slash")
                case .error:
                    Image(systemName: "exclamationmark.icloud")
                }
            }
            .foregroundColor(iconColor)
            .imageScale(.large)
        }
        .popover(isPresented: $showPopup) {
            SyncStatusPopup(syncState: syncState)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var iconColor: Color {
        switch syncState {
        case .syncing: return .blue
        case .synced: return .green
        case .offline: return .orange
        case .error: return .red
        }
    }
}

struct SyncStatusPopup: View {
    let syncState: SyncState
    @Environment(\.appTheme) private var theme

    var message: String {
        switch syncState {
        case .syncing:
            return "Syncing with cloud..."
        case .synced(let date):
            return "Last synced: \(date.formatted(.relative(presentation: .named)))"
        case .offline:
            return "No internet connection\nViewing offline data"
        case .error(let message):
            return "Sync failed: \(message)\nViewing cached data"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            syncStateIcon
                .font(.title)
                .foregroundColor(iconColor)

            DSText(
                message,
                font: .dsCaption,
                color: theme.colors.textSecondary
            )
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private var syncStateIcon: some View {
        switch syncState {
        case .syncing:
            Image(systemName: "icloud.and.arrow.down")
                .symbolEffect(.rotate, options: .repeating)
        case .synced:
            Image(systemName: "checkmark.icloud")
        case .offline:
            Image(systemName: "icloud.slash")
        case .error:
            Image(systemName: "exclamationmark.icloud")
        }
    }

    private var iconColor: Color {
        switch syncState {
        case .syncing: return .blue
        case .synced: return .green
        case .offline: return .orange
        case .error: return .red
        }
    }
}

#Preview("Syncing") {
    SyncStatusIcon(syncState: .syncing)
}

#Preview("Synced") {
    SyncStatusIcon(syncState: .synced(Date()))
}

#Preview("Offline") {
    SyncStatusIcon(syncState: .offline)
}

#Preview("Error") {
    SyncStatusIcon(syncState: .error("Connection timeout"))
}

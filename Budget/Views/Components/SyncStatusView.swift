//
//  SyncStatusView.swift
//  Budget
//
//  Created for Supabase integration
//

import SwiftUI

struct SyncStatusView: View {
    let state: SyncState
    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            switch state {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(theme.colors.textPrimary)

            case .synced(let date):
                Image(systemName: "checkmark.icloud")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)

            case .error:
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 16))
                    .foregroundStyle(.red)

            case .offline:
                Image(systemName: "icloud.slash")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SyncStatusView(state: .syncing)
        SyncStatusView(state: .synced(Date()))
        SyncStatusView(state: .error("Test error"))
        SyncStatusView(state: .offline)
    }
    .padding()
    .environment(\.appTheme, AppTheme.shared)
}

//
//  BudgetApp.swift
//  Budget
//
//  Created by Prateek Sharma on 05/09/2025.
//

import SwiftUI
import SwiftData

@main
struct BudgetApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BudgetDataModel.self,
            CategoryDataModel.self,
            TransactionDataModel.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            // For development phase: if schema incompatible, delete and recreate
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))

            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                return container
            } catch {
                fatalError("Could not create ModelContainer after cleanup: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

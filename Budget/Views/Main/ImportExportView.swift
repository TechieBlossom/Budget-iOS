import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    let budgetManager: BudgetManager
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importExportManager = ImportExportManager()
    @State private var notificationManager = NotificationManager()
    @State private var showingFilePicker = false
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    @State private var isExporting = false
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DSSpacing.xl) {
                    // Export Section
                    VStack(spacing: DSSpacing.md) {
                        HStack {
                            DSText("Export Data", font: .dsSmallTitle, color: theme.colors.textPrimary)
                            Spacer()
                        }
                        
                        ExportSection(
                            title: "Backup Budget Data",
                            description: "Export all budget data and transactions to a .budget file",
                            iconName: "square.and.arrow.up",
                            isLoading: isExporting
                        ) {
                            exportBudgetData()
                        }
                    }
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.top, DSSpacing.xl)
                    
                    // Import Section
                    VStack(spacing: DSSpacing.md) {
                        HStack {
                            DSText("Import Data", font: .dsSmallTitle, color: theme.colors.textPrimary)
                            Spacer()
                        }

                        ImportSection(
                            title: "Restore Budget Data",
                            description: "Import budget data from a .budget file",
                            iconName: "square.and.arrow.down",
                            isLoading: isImporting
                        ) {
                            showingFilePicker = true
                        }

                        #if DEBUG
                        // Debug: Test import with bundled file
                        Button(action: {
                            testImportFromBundle()
                        }) {
                            DSCard {
                                HStack(spacing: DSSpacing.md) {
                                    Image(systemName: "ant.circle")
                                        .font(.dsSmallTitle)
                        .fontWeight(.light)
                                        .foregroundColor(theme.colors.textSecondary)
                                        .frame(width: 40, height: 40)

                                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                        DSText("Test Import (Debug)", font: .dsBody, color: theme.colors.textSecondary)
                                        DSText("Load from-prateek-phone.budget from bundle", font: .dsCaption, color: theme.colors.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.dsSubtitle)
                        .fontWeight(.medium)
                                        .foregroundColor(theme.colors.textSecondary)
                                }
                                .padding(.horizontal, DSSpacing.md)
                                .padding(.vertical, DSSpacing.sm)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        #endif
                    }
                    .padding(.horizontal, DSSpacing.md)
                    
                    // Info Section
                    VStack(spacing: DSSpacing.md) {
                        HStack {
                            DSText("Information", font: .dsSmallTitle, color: theme.colors.textPrimary)
                            Spacer()
                        }
                        
                        InfoCard(
                            title: "About .budget Files",
                            items: [
                                "Contains all budget information and transaction history",
                                "Secure JSON format that can be shared safely",
                                "Compatible only with this Budget app",
                                "Imported data will be added to existing budgets"
                            ]
                        )
                    }
                    .padding(.horizontal, DSSpacing.md)
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }
            }
        }
        .background(theme.colors.background)
        .navigationTitle("Import/Export")
        .navigationBarTitleDisplayMode(.inline)
        .customNavigationBarAppearance()
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    DSText("Import/Export", font: .dsBody, color: theme.colors.textPrimary)
                        .fontWeight(.semibold)
                    DSText("Backup & Restore Data", font: .dsCaption, color: theme.colors.textSecondary)
                }
            }
        }
        .snackbar(notificationManager)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "budget") ?? UTType.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportFileURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportBudgetData() {
        guard !isExporting else { return }
        
        isExporting = true
        
        Task {
            defer { isExporting = false }
            
            // Get all budgets and transactions
            let allBudgets = [budgetManager.budget] // For now, just current budget
            let allTransactions = budgetManager.getAllTransactions()
            
            // Export data
            guard let data = importExportManager.exportBudgetData(budgets: allBudgets, transactions: allTransactions) else {
                await MainActor.run {
                    notificationManager.showError("Failed to export budget data")
                }
                return
            }
            
            // Create temporary file
            let fileName = importExportManager.generateFileName()
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                await MainActor.run {
                    exportFileURL = tempURL
                    showingShareSheet = true
                    notificationManager.showSuccess("Budget data exported successfully!")
                }
            } catch {
                await MainActor.run {
                    notificationManager.showError("Failed to save export file")
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard !isImporting else { return }
        
        isImporting = true
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isImporting = false
                notificationManager.showError("No file selected")
                return
            }
            
            importBudgetData(from: url)
            
        case .failure(let error):
            isImporting = false
            notificationManager.showError("Failed to select file: \(error.localizedDescription)")
        }
    }
    
    private func importBudgetData(from url: URL) {
        Task {
            defer {
                Task {
                    await MainActor.run {
                        isImporting = false
                    }
                }
            }

            do {
                // Ensure we can access the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        notificationManager.showError("Cannot access file")
                    }
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)

                guard let importResult = importExportManager.importBudgetData(from: data) else {
                    await MainActor.run {
                        notificationManager.showError("Invalid budget file format")
                    }
                    return
                }

                // Import the budget and transactions
                let budgetCount = importResult.budgets.count
                let transactionCount = importResult.transactions.count

                // Import each budget and its transactions
                guard let firstBudget = importResult.budgets.first else {
                    await MainActor.run {
                        notificationManager.showError("No budget data found in file")
                    }
                    return
                }

                await MainActor.run {
                    // Check if a budget with the same ID already exists
                    let existingBudgets = budgetManager.getAllBudgets()
                    let budgetExists = existingBudgets.contains(where: { $0.id == firstBudget.id })

                    if budgetExists {
                        // Delete existing budget and its transactions
                        _ = budgetManager.deleteBudget(firstBudget.id)
                    }

                    // Create the imported budget
                    guard budgetManager.createBudget(firstBudget) else {
                        notificationManager.showError("Failed to create imported budget")
                        return
                    }

                    // Add all imported transactions to the budget
                    for transaction in importResult.transactions {
                        _ = budgetManager.addTransaction(transaction, to: firstBudget.id)
                    }

                    let action = budgetExists ? "Re-imported" : "Imported"
                    notificationManager.showSuccess("\(action) \(budgetCount) budget(s) and \(transactionCount) transaction(s)")

                    // Dismiss the view to show the imported data
                    dismiss()
                }

            } catch {
                await MainActor.run {
                    notificationManager.showError("Failed to read file: \(error.localizedDescription)")
                }
            }
        }
    }

    #if DEBUG
    private func testImportFromBundle() {
        guard let url = Bundle.main.url(forResource: "from-prateek-phone", withExtension: "budget") else {
            notificationManager.showError("from-prateek-phone.budget not found in bundle")
            return
        }

        isImporting = true
        importBudgetData(from: url)
    }
    #endif
}

struct ExportSection: View {
    let title: String
    let description: String
    let iconName: String
    let isLoading: Bool
    let action: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            DSCard {
                HStack(spacing: DSSpacing.md) {
                    Image(systemName: iconName)
                        .font(.dsSmallTitle)
                        .fontWeight(.light)
                        .foregroundColor(theme.colors.textPrimary)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText(title, font: .dsHeadline, color: theme.colors.textPrimary)
                        DSText(description, font: .dsBody, color: theme.colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.dsSubtitle)
                        .fontWeight(.medium)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.md)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ImportSection: View {
    let title: String
    let description: String
    let iconName: String
    let isLoading: Bool
    let action: () -> Void
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Button(action: {
            if !isLoading {
                action()
            }
        }) {
            DSCard {
                HStack(spacing: DSSpacing.md) {
                    Image(systemName: iconName)
                        .font(.dsSmallTitle)
                        .fontWeight(.light)
                        .foregroundColor(theme.colors.textPrimary)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        DSText(title, font: .dsHeadline, color: theme.colors.textPrimary)
                        DSText(description, font: .dsBody, color: theme.colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.dsSubtitle)
                        .fontWeight(.medium)
                            .foregroundColor(theme.colors.textSecondary)
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.vertical, DSSpacing.md)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InfoCard: View {
    let title: String
    let items: [String]
    
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                DSText(title, font: .dsHeadline, color: theme.colors.textPrimary)
                
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: DSSpacing.xs) {
                            Image(systemName: "circle.fill")
                                .font(.dsCaption)
                                .foregroundColor(theme.colors.textSecondary)
                                .padding(.top, DSSpacing.xs)
                            
                            DSText(item, font: .dsBody, color: theme.colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.md)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Preview disabled due to BudgetManager initialization complexity
// #Preview {
//     ImportExportView(budgetManager: BudgetManager(...))
// }
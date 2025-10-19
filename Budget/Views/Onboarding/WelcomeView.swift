import SwiftUI
import UniformTypeIdentifiers

struct WelcomeView: View {
    @Bindable var onboardingState: OnboardingState
    var onImportBudget: ((Budget, [Transaction]) -> Void)?

    @Environment(\.appTheme) private var theme
    @StateObject private var importExportManager = ImportExportManager()
    @State private var notificationManager = NotificationManager()
    @State private var showingFilePicker = false
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: DSSpacing.md) {
                DSText("Dhaarã", font: .dsLargeTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xxl)
                
                DSText("The mindful flow of your money", font: .dsTitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSSpacing.xxl)
            }
            
            Spacer()
                .frame(maxHeight: 60)
            
            // Action Buttons
            VStack(spacing: DSSpacing.lg) {
                // Get Started Button
                DSButtonCard("CREATE NEW", subtitle: "Begin with a fresh budget setup", style: .primary) {
                    onboardingState.userChoice = .start
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onboardingState.goToNextStep()
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
                
                // OR Separator
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(theme.colors.textSecondary.opacity(0.3))

                    DSText("OR", font: .dsCaption, color: theme.colors.textSecondary)
                        .padding(.horizontal, DSSpacing.sm)

                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(theme.colors.textSecondary.opacity(0.3))
                }
                .padding(.horizontal, DSSpacing.xl)
                
                // Import Button
                DSButtonCard("IMPORT EXISTING", subtitle: "Continue with existing budget data", style: .outline) {
                    onboardingState.userChoice = .exportExisting
                    showingFilePicker = true
                }
                .padding(.horizontal, DSSpacing.xl)
                .disabled(isImporting)
                .opacity(isImporting ? 0.6 : 1.0)
            }
            
            Spacer()
        }
        .background(theme.colors.background)
        .snackbar(notificationManager)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType(filenameExtension: "budget") ?? UTType.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Helper Methods

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
                guard let firstBudget = importResult.budgets.first else {
                    await MainActor.run {
                        notificationManager.showError("No budget data found in file")
                    }
                    return
                }

                let transactionCount = importResult.transactions.count

                await MainActor.run {
                    // Call the completion handler with imported budget and transactions
                    onImportBudget?(firstBudget, importResult.transactions)
                    notificationManager.showSuccess("Imported budget with \(transactionCount) transaction(s)")
                }

            } catch {
                await MainActor.run {
                    notificationManager.showError("Failed to read file: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    WelcomeView(onboardingState: OnboardingState())
}

# Supabase + SwiftData Offline-First Integration Plan

## Architecture Overview

### Simplified Active Budget Model
- **One active budget per user at a time**
- **SwiftData stores only active budget** (minimal local DB)
- **Historical budgets in Supabase only** (cloud archive, read-only)
- **Supabase is source of truth**
- **Delta sync for active budget only**
- **Apple + Google Sign In**

### Data Flow
```
Current Flow:
User action → BudgetManager → DatabaseService → SwiftData (disk)

New Flow with Supabase:
User action → BudgetManager → DatabaseService → SwiftData (disk)
                                              ↓
                                         SyncManager
                                              ↓
                                         Supabase (cloud)
```

### Sync Strategy
```
Active Budget:
├─ Full bidirectional sync (SwiftData ↔ Supabase)
├─ Delta sync on app launch/changes
└─ Offline-first with queue

Historical Budgets:
├─ Stored only in Supabase
├─ Fetched on-demand when user views
└─ No local persistence, no sync
```

---

## Phase 1: Supabase Project Setup (2-3 hours)

### 1.1 Create Project
1. Sign up at supabase.com
2. Create new project
3. Save credentials:
   - Project URL
   - Anon/Public key
   - Service role key (for admin operations)

### 1.2 Database Schema

**Execute in Supabase SQL Editor:**

```sql
-- ============================================
-- PROFILES TABLE (Minimal)
-- ============================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  theme_preference TEXT DEFAULT 'system' CHECK (theme_preference IN ('light', 'dark', 'system')),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- BUDGETS TABLE (One Active Per User)
-- ============================================
CREATE TABLE budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  budget_type TEXT NOT NULL CHECK (budget_type IN ('monthly', 'custom')),
  budget_name TEXT NOT NULL,
  currency_code TEXT NOT NULL,
  currency_name TEXT NOT NULL,
  currency_symbol TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraint: Only one active budget per user
  CONSTRAINT unique_active_budget UNIQUE (user_id, is_active)
    DEFERRABLE INITIALLY DEFERRED
);

-- Partial unique index for active budgets only
CREATE UNIQUE INDEX idx_budgets_user_active
  ON budgets(user_id) WHERE (is_active = TRUE);

-- ============================================
-- CATEGORIES TABLE (Per Budget)
-- ============================================
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  budget_id UUID REFERENCES budgets(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  category_group TEXT NOT NULL CHECK (category_group IN ('essentials', 'lifestyle', 'occasional', 'financialGoals', 'miscellaneous')),
  category_type TEXT NOT NULL CHECK (category_type IN ('expense', 'savings')),
  allocated_amount DECIMAL(12,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- TRANSACTIONS TABLE (Denormalized)
-- ============================================
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES categories(id) ON DELETE CASCADE NOT NULL,
  category_group TEXT NOT NULL, -- Denormalized for query performance
  amount DECIMAL(12,2) NOT NULL,
  notes TEXT,
  transaction_date DATE NOT NULL,
  is_recurring BOOLEAN DEFAULT FALSE,
  recurrence_type TEXT DEFAULT 'none',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================
CREATE INDEX idx_budgets_user_id ON budgets(user_id);
CREATE INDEX idx_budgets_dates ON budgets(start_date, end_date);
CREATE INDEX idx_budgets_active ON budgets(is_active) WHERE (is_active = TRUE);
CREATE INDEX idx_categories_budget_id ON categories(budget_id);
CREATE INDEX idx_categories_group ON categories(category_group);
CREATE INDEX idx_transactions_category_id ON transactions(category_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_category_group ON transactions(category_group);

-- ============================================
-- UPDATED_AT TRIGGERS
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_budgets_updated_at BEFORE UPDATE ON budgets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 1.3 Row Level Security (RLS) Policies

```sql
-- ============================================
-- ENABLE RLS
-- ============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PROFILES POLICIES
-- ============================================
CREATE POLICY "Users can view own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- ============================================
-- BUDGETS POLICIES
-- ============================================
CREATE POLICY "Users can view own budgets" ON budgets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own budgets" ON budgets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own budgets" ON budgets
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own budgets" ON budgets
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- CATEGORIES POLICIES
-- ============================================
CREATE POLICY "Users can view own categories" ON categories
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM budgets
      WHERE budgets.id = budget_id
      AND budgets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create own categories" ON categories
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM budgets
      WHERE budgets.id = budget_id
      AND budgets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own categories" ON categories
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM budgets
      WHERE budgets.id = budget_id
      AND budgets.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own categories" ON categories
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM budgets
      WHERE budgets.id = budget_id
      AND budgets.user_id = auth.uid()
    )
  );

-- ============================================
-- TRANSACTIONS POLICIES
-- ============================================
CREATE POLICY "Users can view own transactions" ON transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM categories c
      JOIN budgets b ON c.budget_id = b.id
      WHERE c.id = category_id
      AND b.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create own transactions" ON transactions
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM categories c
      JOIN budgets b ON c.budget_id = b.id
      WHERE c.id = category_id
      AND b.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own transactions" ON transactions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM categories c
      JOIN budgets b ON c.budget_id = b.id
      WHERE c.id = category_id
      AND b.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own transactions" ON transactions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM categories c
      JOIN budgets b ON c.budget_id = b.id
      WHERE c.id = category_id
      AND b.user_id = auth.uid()
    )
  );
```

### 1.4 Configure Authentication Providers

**In Supabase Dashboard → Authentication → Providers:**

**Apple Sign In:**
1. Enable Apple provider
2. Add iOS Bundle ID: `com.yourapp.budget`
3. Configure redirect URL: `com.yourapp.budget://auth/callback`
4. Get Service ID and Key from Apple Developer

**Google OAuth:**
1. Enable Google provider
2. Create OAuth Client ID in Google Cloud Console
3. Add redirect URL: `com.yourapp.budget://auth/callback`
4. Copy Client ID and Secret to Supabase

**Configure redirect URLs in Supabase:**
- Add `com.yourapp.budget://auth/callback`

---

## Phase 2: iOS Project Setup (1-2 hours)

### 2.1 Add Swift Package Dependencies

**In Xcode → File → Add Package Dependencies:**

1. **Supabase Swift SDK:**
   - URL: `https://github.com/supabase/supabase-swift`
   - Version: 2.0.0 or later
   - Add: `Supabase`, `Auth`, `PostgREST`, `Realtime` (optional)

2. **Google Sign In (if using native flow):**
   - URL: `https://github.com/google/GoogleSignIn-iOS`
   - Version: Latest

### 2.2 Configure Xcode Project

**Update Info.plist:**

```xml
<!-- URL Scheme for OAuth callbacks -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.yourapp.budget</string>
    </array>
  </dict>
</array>

<!-- Google Sign In Client ID -->
<key>GIDClientID</key>
<string>YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com</string>

<!-- Query schemes for Google Sign In -->
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>googlechrome</string>
  <string>googleauth</string>
</array>
```

**Add Capabilities:**
- Sign in with Apple
- Keychain Sharing (group: `com.yourapp.budget`)

### 2.3 Create Configuration File

**New file: `Config/SupabaseConfig.swift`**

```swift
import Foundation

enum SupabaseConfig {
    static let url = URL(string: "https://YOUR_PROJECT.supabase.co")!
    static let anonKey = "YOUR_ANON_KEY"
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
}
```

**Add to .gitignore:**
```
Config/SupabaseConfig.swift
```

**Create template: `Config/SupabaseConfig.template.swift`**
(Commit this instead, developers copy and fill in values)

---

## Phase 3: SwiftData Model Updates (3-4 hours)

### 3.1 Add Sync Metadata to BudgetDataModel

**Update `Data/BudgetDataModel.swift`:**

Add new fields:
- `userId: UUID?` - Link to auth user
- `isActive: Bool` - Only one active per user
- `lastSyncedAt: Date?` - Track last sync
- `needsSync: Bool` - Dirty flag for sync

Remove:
- `categoriesData: Data` - Categories will be separate model
- `categoryAmountsData: Data` - Amounts stored in CategoryDataModel

Add relationship:
- `@Relationship var categories: [CategoryDataModel]`

### 3.2 Add Sync Metadata to TransactionDataModel

**Update `Data/TransactionDataModel.swift`:**

Add new fields:
- `categoryGroup: String` - Denormalized for performance
- `lastSyncedAt: Date?` - Track last sync
- `needsSync: Bool` - Dirty flag

### 3.3 Create CategoryDataModel

**New file: `Data/CategoryDataModel.swift`**

```swift
import Foundation
import SwiftData

@Model
final class CategoryDataModel {
    @Attribute(.unique) var categoryId: UUID
    var budgetId: UUID
    var name: String
    var categoryGroup: String
    var categoryType: String
    var allocatedAmount: Double

    // Sync metadata
    var lastSyncedAt: Date?
    var needsSync: Bool = false

    // Relationship
    var budget: BudgetDataModel?

    init(categoryId: UUID, budgetId: UUID, name: String,
         categoryGroup: String, categoryType: String,
         allocatedAmount: Double = 0) {
        self.categoryId = categoryId
        self.budgetId = budgetId
        self.name = name
        self.categoryGroup = categoryGroup
        self.categoryType = categoryType
        self.allocatedAmount = allocatedAmount
    }
}

// MARK: - Conversions
extension CategoryDataModel {
    func toSubCategory() -> SubCategory {
        let group = CategoryGroup(rawValue: categoryGroup) ?? .miscellaneous
        let type = CategoryType(rawValue: categoryType) ?? .expense
        return SubCategory(
            id: categoryId,
            name: name,
            categoryGroup: group,
            categoryType: type
        )
    }

    static func from(_ subCategory: SubCategory, budgetId: UUID, allocatedAmount: Double = 0) -> CategoryDataModel {
        return CategoryDataModel(
            categoryId: subCategory.id,
            budgetId: budgetId,
            name: subCategory.name,
            categoryGroup: subCategory.categoryGroup.rawValue,
            categoryType: subCategory.categoryType.rawValue,
            allocatedAmount: allocatedAmount
        )
    }
}
```

### 3.4 Update Schema in BudgetApp.swift

**Modify `BudgetApp.swift`:**

```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        BudgetDataModel.self,
        CategoryDataModel.self, // NEW
        TransactionDataModel.self
    ])
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
    )

    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        // Migration handling for schema changes
        print("⚠️ Database schema changed, recreating...")

        let storeURL = modelConfiguration.url
        try? FileManager.default.removeItem(at: storeURL)
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
        try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}()
```

---

## Phase 4: Authentication Implementation (4-6 hours)

### 4.1 Create Supabase Client Manager

**New file: `Services/SupabaseClient.swift`**

```swift
import Foundation
import Supabase

@MainActor
class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
}
```

### 4.2 Create AuthManager

**New file: `Services/AuthManager.swift`**

Key responsibilities:
- Manage authentication state
- Handle Apple Sign In (native)
- Handle Google Sign In (OAuth)
- Session management with auto-refresh
- Profile creation/management

Key methods:
- `checkSession() async`
- `signInWithApple() async throws`
- `signInWithGoogle(presenting: UIViewController) async throws`
- `signOut() async throws`
- `createProfileIfNeeded() async`

### 4.3 Create Auth Views

**New file: `Views/Auth/AuthView.swift`**

UI components:
- App logo/branding
- "Sign in with Apple" button (DSButton)
- "Sign in with Google" button (DSButton)
- Loading state
- Error message display
- Terms & Privacy links

### 4.4 Update ContentView for Auth Flow

**Modify `ContentView.swift`:**

Add auth state management:
```swift
@State private var authManager = AuthManager()
@State private var budgetManager: BudgetManager?

var body: some View {
    Group {
        if !authManager.isAuthenticated {
            AuthView()
        } else {
            if let budgetManager {
                if budgetManager.hasActiveBudget {
                    MainAppView()
                } else {
                    OnboardingCoordinator()
                }
            } else {
                ProgressView("Loading...")
                    .task {
                        await initializeBudgetManager()
                    }
            }
        }
    }
    .environment(authManager)
}
```

---

## Phase 5: Sync Engine Implementation (8-10 hours)

### 5.1 Create Network Monitor

**New file: `Services/NetworkMonitor.swift`**

Use `Network` framework to detect connectivity:
- Monitor network status
- @Observable for reactive updates
- Auto-trigger sync when connection restored

### 5.2 Create Supabase Data Models

**New file: `Services/SupabaseModels.swift`**

Create Codable models matching Supabase schema:
- `SupabaseBudget`
- `SupabaseCategory`
- `SupabaseTransaction`
- `Profile`

All with proper `CodingKeys` for snake_case ↔ camelCase conversion.

### 5.3 Create Sync Manager

**New file: `Services/SupabaseSyncManager.swift`**

**Core responsibilities:**
- Pull sync: Download active budget from Supabase → update SwiftData
- Push sync: Upload local changes → Supabase
- Conflict resolution: Server always wins
- Error handling & retry logic
- Batch operations for efficiency

**Key methods:**

**Main Sync:**
- `syncActiveBudget() async` - Full sync (pull then push)
- `pullActiveBudget(userId:) async throws` - Download from server
- `pushLocalChanges(userId:) async throws` - Upload to server

**Pull Methods:**
- `pullActiveBudget()` - Fetch active budget with nested data
- `saveBudgetLocally()` - Convert Supabase models → SwiftData
- Delta sync using `updated_at > lastSyncTimestamp`

**Push Methods:**
- `pushBudget()` - Upsert budget to Supabase
- `pushCategory()` - Upsert category to Supabase
- `pushTransaction()` - Upsert transaction to Supabase
- Only push items with `needsSync = true`

**Budget Management:**
- `deactivateCurrentBudget() async throws` - Mark as inactive, delete from local

**Sync State:**
```swift
enum SyncState: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(String)
    case offline
}
```

**Delta Sync Strategy:**
```swift
func pullChanges() async throws {
    let lastSync = UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date ?? Date.distantPast

    // Only fetch ACTIVE budget for current user
    let response = try await supabase
        .from("budgets")
        .select("""
            *,
            categories(*),
            categories(transactions(*))
        """)
        .eq("user_id", value: userId)
        .eq("is_active", value: true)
        .gte("updated_at", value: lastSync.iso8601String)
        .execute()

    // Parse and save to SwiftData
    // Update lastSyncTimestamp
}
```

---

## Phase 6: Update DatabaseService (3-4 hours)

### 6.1 Add Sync Support Methods

**Add to `Data/DatabaseService.swift`:**

**Fetch Methods:**
- `fetchActiveBudget() -> Budget?` - Get current active budget
- `fetchUnsyncedBudgets() -> [Budget]` - Get budgets with `needsSync = true`
- `fetchUnsyncedCategories() -> [SubCategory]` - Categories needing sync
- `fetchUnsyncedTransactions() -> [Transaction]` - Transactions needing sync

**Mark as Synced:**
- `markBudgetAsSynced(_ id: UUID)`
- `markCategoryAsSynced(_ id: UUID)`
- `markTransactionAsSynced(_ id: UUID)`

### 6.2 Modify CRUD Operations

Update all create/update/delete methods to:
1. Set `needsSync = true`
2. Set `userId` from current auth user
3. Trigger sync after save

Example:
```swift
func createBudget(_ budget: Budget) -> Bool {
    do {
        var budgetDataModel = try BudgetDataModel.from(budget)
        budgetDataModel.needsSync = true // NEW
        budgetDataModel.userId = authManager.currentUser?.id // NEW

        modelContext.insert(budgetDataModel)
        try modelContext.save()

        // Trigger sync
        Task { await syncManager?.pushLocalChanges() }

        return true
    } catch {
        print("Failed to create budget: \(error)")
        return false
    }
}
```

### 6.3 Add User Filtering

Update all fetch queries to filter by current user:
```swift
func fetchBudgets() -> [Budget] {
    let currentUserId = authManager.currentUser?.id
    let descriptor = FetchDescriptor<BudgetDataModel>(
        predicate: #Predicate { budget in
            budget.userId == currentUserId && budget.isActive == true
        }
    )
    // ... fetch ...
}
```

### 6.4 Handle Categories Separately

Since categories are now separate models:
- Update `createBudget()` to create CategoryDataModels
- Update `fetchBudget()` to load categories relationship
- Update `updateBudget()` to handle category changes

---

## Phase 7: Update BudgetManager (2-3 hours)

### 7.1 Integrate Sync Manager

**Modify `ViewModels/BudgetManager.swift`:**

Add properties:
- `var syncState: SyncState = .idle`
- `private let syncManager: SupabaseSyncManager`
- `private let networkMonitor = NetworkMonitor()`
- `var hasActiveBudget: Bool { activeBudget != nil }`

Update initializer:
```swift
init(databaseService: DatabaseService, syncManager: SupabaseSyncManager) {
    self.databaseService = databaseService
    self.syncManager = syncManager
    loadActiveBudget()
}
```

### 7.2 Add Sync Methods

**Load with Sync:**
```swift
func loadActiveBudget() {
    // Load from local SwiftData first (instant)
    if let budget = databaseService.fetchActiveBudget() {
        self.activeBudget = budget
        // Load related data...
    }

    // Then sync in background
    Task {
        await syncActiveBudget()
    }
}

func syncActiveBudget() async {
    await syncManager.syncActiveBudget()
    syncState = syncManager.syncState

    // Reload local data after sync
    loadActiveBudget()
}
```

### 7.3 Add Transaction Date Validation

```swift
func addTransaction(_ transaction: Transaction) {
    // Validate date is within budget range
    guard let budget = activeBudget else { return }
    guard transaction.date >= budget.period.startDate &&
          transaction.date <= budget.period.endDate else {
        // Show error: "Transaction date must be within budget period"
        return
    }

    // Save locally (marks needsSync automatically)
    let success = databaseService.createTransaction(transaction, budgetId: budget.id)

    if success && networkMonitor.isConnected {
        // Push to server
        Task {
            try? await syncManager.pushLocalChanges()
        }
    }

    // Reload
    loadActiveBudget()
}
```

### 7.4 Handle Budget Switching

```swift
func createNewBudget(_ budget: Budget) async {
    // Deactivate current budget
    if let currentBudget = activeBudget {
        try? await syncManager.deactivateCurrentBudget()
    }

    // Save new active budget
    _ = databaseService.createBudget(budget)

    // Sync to server
    await syncActiveBudget()
}
```

---

## Phase 8: UI Updates (3-4 hours)

### 8.1 Create Sync Status Indicator

**New file: `Views/Components/SyncStatusView.swift`**

```swift
import SwiftUI

struct SyncStatusView: View {
    let state: SyncState

    var body: some View {
        HStack(spacing: 4) {
            switch state {
            case .idle:
                EmptyView()
            case .syncing:
                ProgressView()
                    .scaleEffect(0.7)
            case .success(let date):
                Image(systemName: "checkmark.icloud")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(.red)
            case .offline:
                Image(systemName: "icloud.slash")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
    }
}
```

### 8.2 Update MainAppView

**Modify `Views/Main/MainAppView.swift`:**

Add sync indicator to toolbar:
```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        SyncStatusView(state: budgetManager.syncState)
    }
}
```

Add pull-to-refresh:
```swift
.refreshable {
    await budgetManager.syncActiveBudget()
}
```

### 8.3 Update Settings View

**Add to `Views/Main/SettingsView.swift` or create new SettingsView:**

Account section:
- Sign Out button (red, destructive)
- Sync Now button
- Last sync timestamp display
- Theme preference selector (synced to Supabase profile)

### 8.4 Create Historical Budgets View

**New file: `Views/Main/HistoricalBudgetsView.swift`**

Features:
- List of past budgets (fetched from Supabase only)
- Lightweight query (just budget metadata)
- Navigation to detail view

**New file: `Views/Main/HistoricalBudgetDetailView.swift`**

Features:
- Read-only view of historical budget
- Full data fetched from Supabase on-demand
- Not saved to SwiftData
- Show budget summary, categories, transactions

---

## Phase 9: Production Preparation (2-3 hours)

### 9.1 Security Checklist

- [ ] Add `Config/SupabaseConfig.swift` to .gitignore
- [ ] Create `Config/SupabaseConfig.template.swift` for team
- [ ] Verify all RLS policies work correctly
- [ ] Test that users can't access other users' data
- [ ] Use Keychain for token storage (Supabase SDK handles this)
- [ ] Ensure all API calls use HTTPS only

### 9.2 Performance Optimization

- [ ] Database indexes already created ✅
- [ ] Test with 1000+ transactions
- [ ] Optimize batch sync size (limit to 100 records per query)
- [ ] Add pagination for large transaction lists
- [ ] Use `.select()` with specific columns when needed

### 9.3 Error Handling

**Graceful offline mode:**
- Show offline indicator
- Queue changes locally
- Auto-sync when connection restored
- User-friendly error messages

**Retry logic:**
```swift
func pushChanges(retryCount: Int = 0) async throws {
    do {
        try await uploadToSupabase()
    } catch {
        if retryCount < 3 {
            try await Task.sleep(for: .seconds(2))
            try await pushChanges(retryCount: retryCount + 1)
        } else {
            throw error
        }
    }
}
```

**Network errors:**
- Detect timeout vs auth vs RLS errors
- Show appropriate messages
- Don't lose user data on failure

### 9.4 Data Migration

**For existing users upgrading:**
1. On first auth, check for existing local budgets
2. Assign `userId` to existing data
3. Mark all as `needsSync = true`
4. Push to Supabase
5. Show migration success message

---

## Estimated Timeline

| Phase | Task | Hours |
|-------|------|-------|
| 1 | Supabase setup | 2-3 |
| 2 | iOS project config | 1-2 |
| 3 | SwiftData updates | 3-4 |
| 4 | Authentication | 4-6 |
| 5 | Sync engine | 8-10 |
| 6 | DatabaseService updates | 3-4 |
| 7 | BudgetManager updates | 2-3 |
| 8 | UI updates | 3-4 |
| 9 | Production prep | 2-3 |
| **Total** | | **28-39 hours** |

**Estimated: 4-5 days of focused development**

---

## File Summary

### New Files (13)

**Configuration:**
- `Config/SupabaseConfig.swift` - API keys and configuration
- `Config/SupabaseConfig.template.swift` - Template for team

**Services:**
- `Services/SupabaseClient.swift` - Singleton client manager
- `Services/AuthManager.swift` - Authentication management
- `Services/SupabaseSyncManager.swift` - Sync engine
- `Services/NetworkMonitor.swift` - Network connectivity monitoring
- `Services/SupabaseModels.swift` - Codable models for Supabase

**Data:**
- `Data/CategoryDataModel.swift` - SwiftData model for categories

**Views:**
- `Views/Auth/AuthView.swift` - Sign in screen
- `Views/Components/SyncStatusView.swift` - Sync indicator
- `Views/Main/HistoricalBudgetsView.swift` - Past budgets list
- `Views/Main/HistoricalBudgetDetailView.swift` - Past budget detail

### Modified Files (8)

- `BudgetApp.swift` - Add CategoryDataModel to schema
- `ContentView.swift` - Add auth flow
- `Data/BudgetDataModel.swift` - Add sync fields, remove JSON-encoded categories
- `Data/TransactionDataModel.swift` - Add sync fields and category_group
- `Data/DatabaseService.swift` - Add sync methods, user filtering
- `ViewModels/BudgetManager.swift` - Integrate sync manager
- `Views/Main/MainAppView.swift` - Add sync indicator, pull-to-refresh
- `Views/Main/SettingsView.swift` - Add account management

---

## Key Architectural Decisions

### 1. Active Budget Only in SwiftData
- Keeps local DB minimal and fast
- Historical data in cloud only
- Simple sync logic

### 2. Server Always Wins
- Simple conflict resolution
- No complex merge logic
- Predictable for users

### 3. Denormalized category_group in Transactions
- Better query performance
- Acceptable trade-off for read-heavy workload
- Category groups rarely change

### 4. Delta Sync with Timestamps
- Only sync changes since last sync
- Uses Supabase `updated_at` field
- Efficient for large datasets

### 5. Offline-First with Queue
- All writes go to local DB first
- Auto-push when online
- User never blocked by network

---

## Next Steps

1. **Start with Phase 1:** Set up Supabase project and database
2. **Test RLS policies:** Ensure security is correct before building client
3. **Implement auth first:** Get sign-in working before sync
4. **Build sync incrementally:** Start with budgets, then categories, then transactions
5. **Test multi-device:** Use TestFlight or multiple simulators

---

## Troubleshooting Common Issues

### Sync conflicts
- Server always wins, so local changes may be overwritten
- Solution: Show last sync time, let user know when data was updated

### Token expiration
- Supabase SDK handles refresh automatically
- Ensure session listener is set up in AuthManager

### RLS policy issues
- Use Supabase SQL logs to debug
- Test policies with different user IDs
- Check foreign key relationships

### SwiftData migration errors
- Schema changes require DB recreation during development
- Use the error handler in BudgetApp.swift
- For production, add proper migration logic

---

## Resources

- [Supabase Swift SDK Docs](https://supabase.com/docs/reference/swift)
- [Supabase Auth Guide](https://supabase.com/docs/guides/auth)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Apple Sign In Guide](https://developer.apple.com/documentation/authenticationservices)

# Debugging SwiftData Database

## View Database Location

When you run the app in debug mode, you'll see the database location printed in the console:

```
📂 SwiftData Database Location:
   /path/to/database/default.store
```

## Option 1: Using DB Browser for SQLite (Recommended)

1. **Download DB Browser for SQLite**: https://sqlitebrowser.org/
2. **Copy the database path** from the console output
3. **Open the database** in DB Browser:
   - File → Open Database
   - Paste the path to `default.store`
4. **Browse the data**:
   - Click "Browse Data" tab
   - Select tables: `BudgetDataModel`, `CategoryDataModel`, `TransactionDataModel`
   - View all records and their columns

## Option 2: Using sqlite3 CLI

```bash
# Copy the database path from console, then:
sqlite3 /path/to/database/default.store

# Inside sqlite3:
.tables                          # Show all tables
.schema BudgetDataModel          # Show table structure
SELECT * FROM BudgetDataModel;   # View all budgets
SELECT * FROM CategoryDataModel; # View all categories
SELECT * FROM TransactionDataModel; # View all transactions
.quit                            # Exit
```

## Option 3: Using Xcode Debug Console

The scheme now has SQL debug logging enabled. You'll see:

```
CoreData: sql: SELECT ...
CoreData: annotation: ...
```

This shows all SQL queries being executed in real-time.

## Inspecting Data After Logout

To verify logout clears data:

1. **Before logout**: Open DB Browser, check record counts
2. **Logout**: Tap logout button
3. **After logout**: Refresh DB Browser (Ctrl+R or Cmd+R), verify tables are empty
4. **After re-login**: Refresh again, verify data is synced from Supabase

## Useful SQL Queries

```sql
-- Count records in each table
SELECT COUNT(*) FROM BudgetDataModel;
SELECT COUNT(*) FROM CategoryDataModel;
SELECT COUNT(*) FROM TransactionDataModel;

-- View budget with details
SELECT budgetId, budgetName, startDate, endDate, userId
FROM BudgetDataModel;

-- View categories for a budget
SELECT categoryId, name, categoryGroup, allocatedAmount, budgetId
FROM CategoryDataModel
WHERE budgetId = 'YOUR-BUDGET-UUID';

-- View all transactions
SELECT transactionId, name, amount, date, categoryId
FROM TransactionDataModel
ORDER BY date DESC;

-- Check sync status
SELECT budgetId, needsSync, lastSyncedAt, updatedAt
FROM BudgetDataModel;
```

## Checking UserDefaults (Sync Timestamp)

```bash
# In Terminal:
defaults read com.prateeksharma.Budget

# Look for:
lastSyncTimestamp = "2025-10-29 07:04:35 +0000";
```

After logout, this should be removed.

## Console Logs Not Showing?

If you're not seeing print statements in Xcode console:

1. **Check Console Filter**: Make sure it's not filtered
   - Bottom of console: Click filter icon
   - Select "All Output" or "Debugger Output"

2. **Check Device Selection**:
   - Make sure you're viewing the correct simulator/device logs

3. **Restart Xcode**: Sometimes console gets stuck

4. **Use OSLog instead of print** (optional):
   ```swift
   import os
   let logger = Logger(subsystem: "com.budget", category: "sync")
   logger.info("Starting sync...")
   ```

## Debug Workflow

1. **Launch app** → Check console for database path
2. **Open DB Browser** → Point to database file
3. **Perform actions** (add transaction, logout, etc.)
4. **Refresh DB Browser** → Verify changes
5. **Check console logs** → See debug output
6. **Check UserDefaults** → Verify sync timestamp

This helps verify:
- ✅ Local data is cleared on logout
- ✅ Sync timestamp is removed
- ✅ Data is pulled from Supabase on next login
- ✅ No orphaned records remain

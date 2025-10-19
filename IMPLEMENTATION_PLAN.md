# Category/Sub-Category Implementation Plan - FINAL

## Key Design Decisions
✅ **Colors**: 5 group colors (not sub-categories)
✅ **No Icons**: No icons for groups or sub-categories
✅ **Full Screen Sheets**: Like currency selector (not dropdowns)
✅ **Migration**: Option B - Manual migration for existing data
✅ **CategoryExpendableCard**: Groups → Sub-category aggregates → Navigate to filtered transactions

## Category Groups & Sub-Categories

### Fixed Category Groups (5):
1. **Essentials** (#FF6B6B - Red): Rent, Utilities, Groceries, Transportation, Insurance, Healthcare
2. **Lifestyle** (#DDA0DD - Purple): Food & Dining, Entertainment, Shopping, Fitness, Personal Care
3. **Occasional** (#45B7D1 - Blue): Vacation, Education, Subscriptions
4. **Financial Goals** (#96CEB4 - Green): Savings, Investments, Retirement
5. **Miscellaneous** (#F7DC6F - Yellow): Others

**Total**: 18 default sub-categories (user can add up to 15 total)

## Completed (14/22) ✅
1. CategoryGroup model with colors/descriptions
2. CategoryColors.swift → hex extension only
3. Category → SubCategory with categoryGroup
4. Budget model with group methods
5. BudgetManager with group calculations
6. OnboardingState references
7. DSCategoryGroupSelectionSheet
8. DSAddCategorySheet (group selection)
9. DSCategoryRowWithAmount
10. SubCategorySelectionSheet
11. CategorySetupView (sectioned)
12. CategorySettingsView (sectioned)
13. CategoryGroupExpendableCard
14. MockBudgetManager

## Remaining (8) 🚧
15. **MainAppView** - Use CategoryGroupExpendableCard, iterate over groups
16. **BudgetOverviewCard** - Remove toggle, show 5 group bars
17. **AddTransactionSheet** - Full-screen sub-category picker
18. **BudgetAnalysisView** - Remove toggle, single group chart
19. **AllTransactionsView** - Add group & sub-category filters
20. **MigrationService** - Map old categories to new groups
21. **BudgetApp.swift** - Add migration check
22. **Fix compilation errors** - Update all references

## Migration Mapping
```
Housing → Essentials/Rent
Healthcare → Essentials/Healthcare
Transportation → Essentials/Transportation
Utility → Essentials/Utilities
Groceries → Essentials/Groceries
Food & Dining → Lifestyle/Food & Dining
Entertainment → Lifestyle/Entertainment
Others → Miscellaneous/Others
```

## Key UI Changes
- **CategoryExpendableCard** behavior:
  - Header: Shows group aggregate
  - Expanded: Shows sub-category aggregates (not transactions)
  - Tap sub-category → Navigate to AllTransactionsView with filters

- **BudgetOverviewCard**: 5 group bars, no toggle, width relative to max
- **BudgetAnalysisView**: Single chart, no toggle (removed By Progress/By Amount)
- **AllTransactionsView**: Add filter chips for group and sub-category

## Files Modified (~25 total)
Models, ViewModels, Design System, Views (Onboarding, Main, Analysis)

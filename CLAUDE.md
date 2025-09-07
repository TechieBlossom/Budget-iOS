# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI iOS budget tracking application built with Xcode. The app features a comprehensive onboarding flow, custom design system, and category-based expense tracking.

### Key Architecture Components

- **Custom Design System**: Strict color palette with theme support
- **Reactive UI**: Uses @StateObject/@ObservableObject for state management
- **Component-Based Architecture**: Reusable design system components throughout
- **Onboarding Flow**: Multi-step user setup with currency and category selection

### Project Structure

```
Budget/
├── Theme/
│   ├── AppTheme.swift         # Light/dark theme management
│   └── CategoryColors.swift   # 15 fixed category colors
├── DesignSystem/
│   ├── Components/            # Button, TextField, Card, List
│   └── Typography/            # Text styles using theme colors
├── Models/
│   ├── Currency.swift         # Currency selection model
│   ├── Category.swift         # Category with color assignment
│   ├── BudgetPeriod.swift     # Date calculation logic
│   ├── OnboardingState.swift  # Flow state management
│   ├── Budget.swift           # Budget data model with totals/formatting
│   └── Transaction.swift      # Transaction model for expenses
├── Views/
│   ├── Onboarding/            # 4-step onboarding flow
│   └── Main/                  # Budget overview and category cards
├── ViewModels/                # ObservableObject classes
├── BudgetApp.swift           # App entry point
└── ContentView.swift         # Navigation coordinator
```

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -scheme Budget -configuration Debug build

# Build for release
xcodebuild -scheme Budget -configuration Release build

# Clean build folder
xcodebuild -scheme Budget clean
```

### Testing
```bash
# Run all tests
xcodebuild -scheme Budget test

# Run only unit tests
xcodebuild -scheme Budget -only-testing:BudgetTests test

# Run only UI tests  
xcodebuild -scheme Budget -only-testing:BudgetUITests test
```

### Available Targets
- `Budget` - Main app target
- `BudgetTests` - Unit tests
- `BudgetUITests` - UI automation tests

### Available Schemes
- `Budget` - Primary development scheme

## Design System Requirements

### CRITICAL: Component Usage Enforcement
**NEVER create new UI components or use SwiftUI primitives directly. ALWAYS use existing DS (Design System) components:**

#### Required Components (Use ONLY These)
- **DSText**: All text rendering - replaces Text, Label
- **DSButton**: All buttons - replaces Button 
- **DSSquareButton**: Navigation buttons with progress indicators
- **DSCard**: All card containers - replaces VStack/HStack with backgrounds
- **DSTextField**: All text input - replaces TextField
- **DSList**: All list displays - replaces List
- **DSButtonCard**: Tappable card components

#### Forbidden SwiftUI Primitives
❌ **NEVER USE**: Text, Button, TextField, VStack/HStack with .background(), List, Card
✅ **ALWAYS USE**: DSText, DSButton, DSCard, DSTextField, DSList

### Color Palette (STRICT - No Other Colors Allowed)
```swift
// Theme Colors (change with light/dark theme)
Primary Text: #402D31
Secondary Text: #5D4147  
Background: #D5D5D5
Card: #F2F2F2

// Category Colors (15 fixed colors, theme-independent)
// 9 pre-assigned to default categories, 6 available for user categories
```

### Component Color Usage
- **DSButton**: Uses theme colors automatically via @Environment(\.appTheme)
- **DSTextField**: Background `Card`, Input `Primary Text`, Placeholder `Secondary Text`  
- **DSCard**: Background `Card`, uses theme colors for content
- **DSText**: References theme colors via color parameter

### Design System Rules
1. **MANDATORY: Use only DS components - never create new UI components**
2. **NEVER use system colors or any colors outside the 4 theme colors**
3. **All DS components automatically reference theme colors via @Environment**
4. **Category colors are separate and theme-independent**
5. **When adding new functionality, extend existing DS components rather than creating new ones**

## Onboarding Flow Requirements

### 4-Step Flow
1. **Welcome**: Start vs Export existing options
2. **Currency Selection**: Search box + filtered currency list
3. **Date Selection**: Budget start date → auto-calculate end date and budget name
4. **Categories**: Default 9 categories + ability to add up to 6 more with color picker

### Budget Naming Logic
- If end date ≤ 10th of current month → Previous month budget
- Otherwise → Current month budget

### Category Management
- 9 Default categories: Housing, Healthcare, Transportation, Utility, Groceries, Food & Dining, Entertainment, Medical, Others
- Each has pre-assigned color from 15-color palette
- Users can add max 6 additional categories
- Color picker shows only unused colors from remaining palette

## Architecture Patterns

### State Management
- **BudgetManager**: Central ObservableObject managing budget state and transactions
- **@Environment(\.appTheme)**: Theme injection for consistent styling across components
- **@StateObject/@ObservableObject**: Reactive UI updates for data changes

### Main App Components
- **BudgetOverviewCard**: Summary card showing total budget, spent, remaining with vertical progress
- **CategoryExpendableCard**: Expandable category cards showing transactions and progress bars
- **TransactionRow**: Individual transaction display within expanded categories

### ViewModels Pattern
- Each complex view has corresponding ViewModel as ObservableObject
- Centralized business logic separate from UI components
- Reactive updates via @Published properties

## Development Notes

- Focus on performant, reactive SwiftUI architecture
- UI-only implementation (no database integration yet) 
- Component reusability through strict DS component usage
- Tests use Swift Testing framework (not XCTest)
- Follow atomic design principles: DS components include atoms (smallest elements), molecules (combinations of atoms), organisms (combinations of atoms and molecules), and templates
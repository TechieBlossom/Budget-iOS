# Xcode Manual Setup Steps

These are the manual steps you need to complete in Xcode to finish Phase 1 and Phase 2 setup.

---

## Step 1: Add Swift Package Dependencies

### A. Add Supabase Swift SDK

1. **Open** `Budget.xcodeproj` in Xcode
2. **File** → **Add Package Dependencies...**
3. In the search bar, paste:
   ```
   https://github.com/supabase/supabase-swift
   ```
4. **Dependency Rule**: Select "Up to Next Major Version"
   - Minimum version: `2.0.0`
5. Click **Add Package**
6. **Select libraries to add:**
   - ✅ **Supabase** (required)
   - ✅ **Auth** (required)
   - ✅ **PostgREST** (required)
   - ✅ **Realtime** (optional - for future real-time features)
   - ✅ **Storage** (optional - for file uploads)
7. Click **Add Package**

### B. Add Google Sign-In SDK

1. **File** → **Add Package Dependencies...**
2. Paste:
   ```
   https://github.com/google/GoogleSignIn-iOS
   ```
3. **Dependency Rule**: "Up to Next Major Version"
   - Minimum version: `8.0.0`
4. Click **Add Package**
5. **Select BOTH libraries to add:**
   - ✅ **GoogleSignIn** (required - core authentication)
   - ✅ **GoogleSignInSwift** (required - SwiftUI button component)
6. Click **Add Package**

> **Important:** GoogleSignInSwift provides the native `GoogleSignInButton` view for SwiftUI. Both libraries are needed for the official Google Sign-In button.

---

## Step 2: Add SupabaseConfig.swift to Project

The configuration file exists but isn't in your Xcode project yet:

1. In Xcode's **Project Navigator** (left sidebar)
2. **Right-click** on the `Budget` folder (the blue one with the app icon)
3. Select **Add Files to "Budget"...**
4. Navigate to: `Budget/Config/`
5. **Select** `SupabaseConfig.swift`
6. ✅ Check **"Copy items if needed"**
7. ✅ Check **"Create groups"**
8. ✅ Make sure `Budget` target is selected
9. Click **Add**

---

## Step 3: Verify Info.plist

1. In Xcode, click on `Budget/Info.plist` in the Project Navigator
2. Verify these entries exist (they should already be there from the automated setup):

**URL Types (CFBundleURLTypes):**
- Item 0:
  - URL Schemes: `com.techieblossom.Budget`
- Item 1:
  - URL Schemes: `com.googleusercontent.apps.880808744457-ggrurqeqih9oh6msnk19jri55vj4gpl0`

**Google Client ID (GIDClientID):**
- Value: `880808744457-ggrurqeqih9oh6msnk19jri55vj4gpl0.apps.googleusercontent.com`

**Query Schemes (LSApplicationQueriesSchemes):**
- Item 0: `googlechrome`
- Item 1: `googleauth`

---

## Step 4: Build the Project

1. **Product** → **Clean Build Folder** (Shift + Cmd + K)
2. **Product** → **Build** (Cmd + B)
3. Verify there are no errors

**Common issues:**
- If you get "No such module 'Supabase'", make sure the package was added correctly in Step 1
- If you get "No such module 'GoogleSignIn'" or "No such module 'GoogleSignInSwift'", make sure both Google Sign-In libraries were added in Step 1B
- If build succeeds but with warnings, that's okay for now

---

## Step 5: Verify Package Dependencies

1. In Xcode Project Navigator, look for **"Package Dependencies"** section
2. You should see:
   - ✅ `supabase-swift`
   - ✅ `GoogleSignIn-iOS`

If missing, repeat Step 1.

---

## Step 6: Check Bundle ID

1. Click on your project name (Budget) at the top of the Project Navigator
2. Select the **Budget** target
3. Go to **Signing & Capabilities** tab
4. Verify **Bundle Identifier** is: `com.techieblossom.Budget`

---

## ✅ Verification

Once complete, verify:

- [ ] Package Dependencies shows both `supabase-swift` and `GoogleSignIn-iOS`
- [ ] `SupabaseConfig.swift` appears in Project Navigator under `Budget/Config/`
- [ ] Info.plist contains all URL schemes and Google Client ID
- [ ] Bundle ID is `com.techieblossom.Budget`
- [ ] Project builds successfully (Cmd + B)

---

## 🎯 Next Steps

Once these steps are complete, you're ready for:
- **Phase 3**: SwiftData Model Updates
- **Phase 4**: Authentication Implementation

---

## 💡 Tips

- If packages fail to download, check your internet connection
- You can view package versions by clicking on the package in Project Navigator
- The `.gitignore` will prevent `SupabaseConfig.swift` from being committed
- Team members should use `SupabaseConfig.template.swift` as a starting point

---

## 🆘 Troubleshooting

**Problem: "Failed to resolve package"**
- Solution: File → Packages → Reset Package Caches

**Problem: "No such module 'Supabase'"**
- Solution: Clean build folder (Shift + Cmd + K), then rebuild

**Problem: Can't find SupabaseConfig.swift**
- Solution: Make sure you're adding from the correct path: `Budget/Config/SupabaseConfig.swift`

**Problem: Info.plist changes not showing**
- Solution: Close and reopen Xcode, or clean build folder

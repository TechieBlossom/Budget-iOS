-- ============================================
-- SUPABASE ROW LEVEL SECURITY POLICIES
-- Budget App - Phase 1
-- ============================================
-- Execute this AFTER supabase_schema.sql
-- ============================================

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
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

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
  )
  WITH CHECK (
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
  )
  WITH CHECK (
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

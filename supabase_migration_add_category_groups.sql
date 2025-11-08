-- ============================================
-- MIGRATION: Add New Category Groups
-- Date: 2025-10-26
-- Description: Adds 4 new category groups (debtObligations, businessExpenses, familyDependents, homeProperty)
-- ============================================

-- Step 1: Drop the existing constraint
ALTER TABLE categories
DROP CONSTRAINT IF EXISTS categories_category_group_check;

-- Step 2: Add the new constraint with additional category groups
ALTER TABLE categories
ADD CONSTRAINT categories_category_group_check
CHECK (category_group IN (
  'essentials',
  'lifestyle',
  'occasional',
  'financialGoals',
  'debtObligations',
  'businessExpenses',
  'familyDependents',
  'homeProperty',
  'miscellaneous'
));

-- ============================================
-- VERIFICATION QUERY
-- ============================================
-- Run this to verify the constraint was updated successfully:
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conname = 'categories_category_group_check';

-- ============================================
-- ADD NAME COLUMN TO TRANSACTIONS TABLE
-- Execute this in Supabase SQL Editor
-- ============================================

-- Check if the 'name' column exists, if not add it
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'transactions'
        AND column_name = 'name'
    ) THEN
        -- Add the name column
        ALTER TABLE transactions
        ADD COLUMN name TEXT DEFAULT '';

        RAISE NOTICE 'Column "name" added to transactions table';
    ELSE
        RAISE NOTICE 'Column "name" already exists in transactions table';
    END IF;
END $$;

-- Verify the column was added
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'transactions'
ORDER BY ordinal_position;

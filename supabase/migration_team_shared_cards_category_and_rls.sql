-- Migration: Enable team_shared_cards category assignment from Team Management
-- Run this in Supabase SQL Editor on existing environments.

-- 1) Add category_id column used by the app UI.
ALTER TABLE team_shared_cards
  ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES categories(id) ON DELETE SET NULL;

-- 2) Ensure RLS supports category updates and shared-card deletion by owner/member roles.
DROP POLICY IF EXISTS "Team owner and members can update shared cards" ON team_shared_cards;
CREATE POLICY "Team owner and members can update shared cards" ON team_shared_cards
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = team_shared_cards.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role IN ('owner', 'member')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = team_shared_cards.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role IN ('owner', 'member')
    )
  );

DROP POLICY IF EXISTS "Team owner and members can delete shared cards" ON team_shared_cards;
CREATE POLICY "Team owner and members can delete shared cards" ON team_shared_cards
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = team_shared_cards.team_id
        AND team_members.user_id = auth.uid()
        AND team_members.role IN ('owner', 'member')
    )
  );

-- Migration: Add snapshot columns to team_shared_cards
-- Run this in Supabase SQL Editor to update existing database

-- 1) Add card snapshot columns
ALTER TABLE team_shared_cards
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS company TEXT,
  ADD COLUMN IF NOT EXISTS position TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS email TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS mobile TEXT,
  ADD COLUMN IF NOT EXISTS fax TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS website TEXT,
  ADD COLUMN IF NOT EXISTS sns_url TEXT,
  ADD COLUMN IF NOT EXISTS memo TEXT,
  ADD COLUMN IF NOT EXISTS image_url TEXT,
  ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES categories(id) ON DELETE SET NULL;

-- 2) Backfill existing shared cards with data from collected_cards
UPDATE team_shared_cards tsc
SET
  name       = cc.name,
  company    = cc.company,
  position   = cc.position,
  department = cc.department,
  email      = cc.email,
  phone      = cc.phone,
  mobile     = cc.mobile,
  fax        = cc.fax,
  address    = cc.address,
  website    = cc.website,
  sns_url    = cc.sns_url,
  memo       = cc.memo,
  image_url  = cc.image_url
FROM collected_cards cc
WHERE tsc.card_id = cc.id
  AND tsc.name IS NULL;

-- 3) Change FK from CASCADE to SET NULL so shared cards survive original deletion
ALTER TABLE team_shared_cards
  DROP CONSTRAINT IF EXISTS team_shared_cards_card_id_fkey;
ALTER TABLE team_shared_cards
  ALTER COLUMN card_id DROP NOT NULL;
ALTER TABLE team_shared_cards
  ADD CONSTRAINT team_shared_cards_card_id_fkey
    FOREIGN KEY (card_id) REFERENCES collected_cards(id) ON DELETE SET NULL;

-- 4) Update role system: admin -> observer
ALTER TABLE team_members
  DROP CONSTRAINT IF EXISTS team_members_role_check;
ALTER TABLE team_members
  ADD CONSTRAINT team_members_role_check CHECK (role IN ('owner', 'member', 'observer'));
ALTER TABLE team_members
  ALTER COLUMN role SET DEFAULT 'observer';

-- Update existing 'admin' roles to 'member'
UPDATE team_members SET role = 'member' WHERE role = 'admin';

-- 5) Create helper functions (security definer = bypasses RLS)
CREATE OR REPLACE FUNCTION is_team_member(p_team_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = p_team_id AND user_id = auth.uid()
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION is_team_owner(p_team_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = p_team_id AND user_id = auth.uid() AND role = 'owner'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 6) Update RLS policies for new role system
DROP POLICY IF EXISTS "Team admins can manage members" ON team_members;
DROP POLICY IF EXISTS "Team owner can manage members" ON team_members;
DROP POLICY IF EXISTS "Team members can view members" ON team_members;
DROP POLICY IF EXISTS "Team owner can insert members" ON team_members;
DROP POLICY IF EXISTS "Team owner can update members" ON team_members;
DROP POLICY IF EXISTS "Team owner can delete members" ON team_members;

CREATE POLICY "Team members can view members" ON team_members
  FOR SELECT USING (is_team_member(team_id));
CREATE POLICY "Team owner can insert members" ON team_members
  FOR INSERT WITH CHECK (is_team_owner(team_id));
CREATE POLICY "Team owner can update members" ON team_members
  FOR UPDATE USING (is_team_owner(team_id));
CREATE POLICY "Team owner can delete members" ON team_members
  FOR DELETE USING (is_team_owner(team_id));

DROP POLICY IF EXISTS "Team members can share cards" ON team_shared_cards;
DROP POLICY IF EXISTS "Team owner and members can share cards" ON team_shared_cards;
DROP POLICY IF EXISTS "Team owner and members can update shared cards" ON team_shared_cards;
DROP POLICY IF EXISTS "Team owner and members can delete shared cards" ON team_shared_cards;
CREATE POLICY "Team owner and members can share cards" ON team_shared_cards FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
);
CREATE POLICY "Team owner and members can update shared cards" ON team_shared_cards FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
);
CREATE POLICY "Team owner and members can delete shared cards" ON team_shared_cards FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
);

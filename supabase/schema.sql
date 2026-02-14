-- NameCard App - Supabase Database Schema
-- Run this in the Supabase SQL Editor to set up all tables.

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ──────────────── Users ────────────────
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT,
  email TEXT UNIQUE,
  avatar_url TEXT,
  locale TEXT DEFAULT 'ko',
  is_dark_mode BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON users FOR INSERT WITH CHECK (auth.uid() = id);

-- ──────────────── My Business Cards ────────────────
CREATE TABLE IF NOT EXISTS my_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT,
  company TEXT,
  position TEXT,
  department TEXT,
  email TEXT,
  phone TEXT,
  mobile TEXT,
  fax TEXT,
  address TEXT,
  website TEXT,
  sns_url TEXT,
  memo TEXT,
  image_url TEXT,
  card_design_data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE my_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own cards" ON my_cards FOR ALL USING (auth.uid() = user_id);

-- ──────────────── Collected Cards (wallet) ────────────────
CREATE TABLE IF NOT EXISTS collected_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT,
  company TEXT,
  position TEXT,
  department TEXT,
  email TEXT,
  phone TEXT,
  mobile TEXT,
  fax TEXT,
  address TEXT,
  website TEXT,
  sns_url TEXT,
  memo TEXT,
  image_url TEXT,
  category_id UUID,
  source_card_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE collected_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage collected cards" ON collected_cards FOR ALL USING (auth.uid() = user_id);

-- ──────────────── Categories ────────────────
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  team_id UUID,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own categories" ON categories FOR ALL USING (auth.uid() = user_id);

-- Add FK from collected_cards to categories
ALTER TABLE collected_cards
  ADD CONSTRAINT fk_category FOREIGN KEY (category_id)
  REFERENCES categories(id) ON DELETE SET NULL;

-- ──────────────── Teams ────────────────
CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  description TEXT,
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Team owner can manage team" ON teams FOR ALL USING (auth.uid() = owner_id);

-- ──────────────── Team Members ────────────────
CREATE TABLE IF NOT EXISTS team_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  role TEXT DEFAULT 'observer' CHECK (role IN ('owner', 'member', 'observer')),
  user_name TEXT,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(team_id, user_id)
);

-- Helper functions (security definer = bypasses RLS to avoid infinite recursion)
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

ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Team members can view members" ON team_members
  FOR SELECT USING (is_team_member(team_id));
CREATE POLICY "Team owner can insert members" ON team_members
  FOR INSERT WITH CHECK (is_team_owner(team_id));
CREATE POLICY "Team owner can update members" ON team_members
  FOR UPDATE USING (is_team_owner(team_id));
CREATE POLICY "Team owner can delete members" ON team_members
  FOR DELETE USING (is_team_owner(team_id));

-- Add teams RLS policy that depends on team_members (created above)
CREATE POLICY "Team members can view team" ON teams FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = teams.id
    AND team_members.user_id = auth.uid()
  )
);

-- ──────────────── Team Shared Cards ────────────────
-- 공유 시점의 명함 데이터 스냅샷을 저장 (원본 삭제 시에도 유지)
CREATE TABLE IF NOT EXISTS team_shared_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id UUID REFERENCES collected_cards(id) ON DELETE SET NULL,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
  shared_by UUID REFERENCES users(id),
  shared_at TIMESTAMPTZ DEFAULT NOW(),
  -- 명함 데이터 스냅샷
  name TEXT,
  company TEXT,
  position TEXT,
  department TEXT,
  email TEXT,
  phone TEXT,
  mobile TEXT,
  fax TEXT,
  address TEXT,
  website TEXT,
  sns_url TEXT,
  memo TEXT,
  image_url TEXT,
  UNIQUE(card_id, team_id)
);

ALTER TABLE team_shared_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Team members can view shared cards" ON team_shared_cards FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
  )
);
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

-- ──────────────── Tag Templates ────────────────
CREATE TABLE IF NOT EXISTS tag_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  fields JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tag_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own templates" ON tag_templates FOR ALL USING (auth.uid() = user_id);

-- ──────────────── Context Tags ────────────────
CREATE TABLE IF NOT EXISTS context_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id UUID REFERENCES collected_cards(id) ON DELETE CASCADE NOT NULL,
  template_id UUID REFERENCES tag_templates(id) ON DELETE SET NULL,
  values JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE context_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own tags" ON context_tags FOR ALL USING (
  EXISTS (
    SELECT 1 FROM collected_cards
    WHERE collected_cards.id = context_tags.card_id
    AND collected_cards.user_id = auth.uid()
  )
);

-- ──────────────── Storage Buckets ────────────────
-- Run these in the Supabase Dashboard > Storage
-- 1. Create bucket 'card-images' (public)
-- 2. Create bucket 'profile-images' (public)

-- ──────────────── Indexes ────────────────
CREATE INDEX idx_my_cards_user ON my_cards(user_id);
CREATE INDEX idx_collected_cards_user ON collected_cards(user_id);
CREATE INDEX idx_collected_cards_category ON collected_cards(category_id);
CREATE INDEX idx_collected_cards_name ON collected_cards(name);
CREATE INDEX idx_categories_user ON categories(user_id);
CREATE INDEX idx_team_members_team ON team_members(team_id);
CREATE INDEX idx_team_members_user ON team_members(user_id);
CREATE INDEX idx_context_tags_card ON context_tags(card_id);
CREATE INDEX idx_tag_templates_user ON tag_templates(user_id);

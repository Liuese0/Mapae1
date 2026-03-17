-- ============================================================
-- Mapae - Full Database Schema (All-in-One)
-- Run this in the Supabase SQL Editor to set up the complete database.
-- Idempotent: safe to run multiple times on an existing database.
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ════════════════════════════════════════════════════════════
-- 1. CORE TABLES
-- ════════════════════════════════════════════════════════════

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

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can insert own profile" ON users;
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
DROP POLICY IF EXISTS "Users manage own cards" ON my_cards;
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
  is_favorite BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add is_favorite column if it doesn't exist (for existing databases)
ALTER TABLE collected_cards ADD COLUMN IF NOT EXISTS is_favorite BOOLEAN DEFAULT false;

ALTER TABLE collected_cards ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage collected cards" ON collected_cards;
CREATE POLICY "Users manage collected cards" ON collected_cards FOR ALL USING (auth.uid() = user_id);


-- ════════════════════════════════════════════════════════════
-- 2. TEAMS
-- ════════════════════════════════════════════════════════════

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
DROP POLICY IF EXISTS "Team owner can manage team" ON teams;
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

-- Helper functions (SECURITY DEFINER = bypasses RLS to avoid infinite recursion)
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
DROP POLICY IF EXISTS "Team members can view members" ON team_members;
CREATE POLICY "Team members can view members" ON team_members
  FOR SELECT USING (is_team_member(team_id));
DROP POLICY IF EXISTS "Team owner can insert members" ON team_members;
CREATE POLICY "Team owner can insert members" ON team_members
  FOR INSERT WITH CHECK (is_team_owner(team_id));
DROP POLICY IF EXISTS "Team owner can update members" ON team_members;
CREATE POLICY "Team owner can update members" ON team_members
  FOR UPDATE USING (is_team_owner(team_id));
DROP POLICY IF EXISTS "Team owner can delete members" ON team_members;
CREATE POLICY "Team owner can delete members" ON team_members
  FOR DELETE USING (is_team_owner(team_id));

-- Teams: members can view
DROP POLICY IF EXISTS "Team members can view team" ON teams;
CREATE POLICY "Team members can view team" ON teams FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = teams.id
    AND team_members.user_id = auth.uid()
  )
);

-- ──────────────── Team Invitations ────────────────
CREATE TABLE IF NOT EXISTS team_invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  inviter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  invitee_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(team_id, invitee_id, status)
);

ALTER TABLE team_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their invitations" ON team_invitations;
CREATE POLICY "Users can view their invitations" ON team_invitations
  FOR SELECT USING (
    auth.uid() = inviter_id OR auth.uid() = invitee_id
  );

DROP POLICY IF EXISTS "Team members can create invitations" ON team_invitations;
CREATE POLICY "Team members can create invitations" ON team_invitations
  FOR INSERT WITH CHECK (
    auth.uid() = inviter_id
    AND EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = team_invitations.team_id
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'member')
    )
  );

DROP POLICY IF EXISTS "Invitee can update invitation" ON team_invitations;
CREATE POLICY "Invitee can update invitation" ON team_invitations
  FOR UPDATE USING (
    auth.uid() = invitee_id OR auth.uid() = inviter_id
  );

DROP POLICY IF EXISTS "Inviter can delete invitation" ON team_invitations;
CREATE POLICY "Inviter can delete invitation" ON team_invitations
  FOR DELETE USING (auth.uid() = inviter_id);


-- ════════════════════════════════════════════════════════════
-- 3. CATEGORIES
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  team_id UUID,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own categories" ON categories;
CREATE POLICY "Users manage own categories" ON categories FOR ALL USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Team owner can manage team categories" ON categories;
CREATE POLICY "Team owner can manage team categories" ON categories FOR ALL USING (
  team_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = categories.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role = 'owner'
  )
);
DROP POLICY IF EXISTS "Team members can view team categories" ON categories;
CREATE POLICY "Team members can view team categories" ON categories FOR SELECT USING (
  team_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = categories.team_id
    AND team_members.user_id = auth.uid()
  )
);

-- FK from collected_cards to categories
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_category'
    AND table_name = 'collected_cards'
  ) THEN
    ALTER TABLE collected_cards
      ADD CONSTRAINT fk_category FOREIGN KEY (category_id)
      REFERENCES categories(id) ON DELETE SET NULL;
  END IF;
END $$;


-- ════════════════════════════════════════════════════════════
-- 4. TEAM SHARED CARDS
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS team_shared_cards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id UUID REFERENCES collected_cards(id) ON DELETE SET NULL,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  shared_by UUID REFERENCES users(id),
  shared_at TIMESTAMPTZ DEFAULT NOW(),
  category_id UUID,
  -- Card data snapshot
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
DROP POLICY IF EXISTS "Team members can view shared cards" ON team_shared_cards;
CREATE POLICY "Team members can view shared cards" ON team_shared_cards FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
  )
);
DROP POLICY IF EXISTS "Team owner and members can share cards" ON team_shared_cards;
CREATE POLICY "Team owner and members can share cards" ON team_shared_cards FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
);
DROP POLICY IF EXISTS "Team owner and members can update shared cards" ON team_shared_cards;
CREATE POLICY "Team owner and members can update shared cards" ON team_shared_cards FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
);
DROP POLICY IF EXISTS "Team owner and members can delete shared cards" ON team_shared_cards;
CREATE POLICY "Team owner and members can delete shared cards" ON team_shared_cards FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM team_members
    WHERE team_members.team_id = team_shared_cards.team_id
    AND team_members.user_id = auth.uid()
    AND team_members.role IN ('owner', 'member')
  )
);


-- ════════════════════════════════════════════════════════════
-- 5. TAGS & TEMPLATES
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS tag_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  fields JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE tag_templates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own templates" ON tag_templates;
CREATE POLICY "Users manage own templates" ON tag_templates FOR ALL USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS context_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  card_id UUID REFERENCES collected_cards(id) ON DELETE CASCADE NOT NULL,
  template_id UUID REFERENCES tag_templates(id) ON DELETE SET NULL,
  values JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE context_tags ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own tags" ON context_tags;
CREATE POLICY "Users manage own tags" ON context_tags FOR ALL USING (
  EXISTS (
    SELECT 1 FROM collected_cards
    WHERE collected_cards.id = context_tags.card_id
    AND collected_cards.user_id = auth.uid()
  )
);


-- ════════════════════════════════════════════════════════════
-- 6. SHARED LINKS (SNS sharing)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS shared_links (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  card_data jsonb NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE shared_links ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read shared links" ON shared_links;
CREATE POLICY "Anyone can read shared links"
  ON shared_links FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Authenticated users can create shared links" ON shared_links;
CREATE POLICY "Authenticated users can create shared links"
  ON shared_links FOR INSERT
  TO authenticated
  WITH CHECK (true);


-- ════════════════════════════════════════════════════════════
-- 7. QUICK SHARE (Nearby card exchange)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS quick_share_sessions (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  card_id UUID REFERENCES my_cards(id) ON DELETE SET NULL,
  name TEXT,
  company TEXT,
  position TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quick_share_exchanges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'requested',  -- requested/responded/completed
  from_card JSONB NOT NULL,
  to_card JSONB,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE quick_share_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_share_exchanges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view active quick share sessions" ON quick_share_sessions;
CREATE POLICY "Users can view active quick share sessions"
  ON quick_share_sessions FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Users can upsert own quick share sessions" ON quick_share_sessions;
CREATE POLICY "Users can upsert own quick share sessions"
  ON quick_share_sessions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own quick share sessions" ON quick_share_sessions;
CREATE POLICY "Users can update own quick share sessions"
  ON quick_share_sessions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own quick share sessions" ON quick_share_sessions;
CREATE POLICY "Users can delete own quick share sessions"
  ON quick_share_sessions FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view related quick share exchanges" ON quick_share_exchanges;
CREATE POLICY "Users can view related quick share exchanges"
  ON quick_share_exchanges FOR SELECT
  USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

DROP POLICY IF EXISTS "Users can create quick share request" ON quick_share_exchanges;
CREATE POLICY "Users can create quick share request"
  ON quick_share_exchanges FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);

DROP POLICY IF EXISTS "Receiver can respond quick share request" ON quick_share_exchanges;
CREATE POLICY "Receiver can respond quick share request"
  ON quick_share_exchanges FOR UPDATE
  USING (auth.uid() = to_user_id OR auth.uid() = from_user_id)
  WITH CHECK (auth.uid() = to_user_id OR auth.uid() = from_user_id);


-- ════════════════════════════════════════════════════════════
-- 8. CRM (Customer Relationship Management)
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS crm_contacts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  shared_card_id UUID REFERENCES team_shared_cards(id) ON DELETE SET NULL,
  created_by UUID REFERENCES users(id) NOT NULL,
  name TEXT,
  company TEXT,
  position TEXT,
  department TEXT,
  email TEXT,
  phone TEXT,
  mobile TEXT,
  status TEXT DEFAULT 'lead' CHECK (status IN ('lead', 'contact', 'meeting', 'proposal', 'contract', 'closed')),
  memo TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE crm_contacts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Team members can view crm contacts" ON crm_contacts;
CREATE POLICY "Team members can view crm contacts" ON crm_contacts
  FOR SELECT USING (is_team_member(team_id));

DROP POLICY IF EXISTS "Team owner and members can insert crm contacts" ON crm_contacts;
CREATE POLICY "Team owner and members can insert crm contacts" ON crm_contacts
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = crm_contacts.team_id
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'member')
    )
  );

DROP POLICY IF EXISTS "Team owner and members can update crm contacts" ON crm_contacts;
CREATE POLICY "Team owner and members can update crm contacts" ON crm_contacts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = crm_contacts.team_id
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'member')
    )
  );

DROP POLICY IF EXISTS "Team owner can delete crm contacts" ON crm_contacts;
CREATE POLICY "Team owner can delete crm contacts" ON crm_contacts
  FOR DELETE USING (is_team_owner(team_id));

CREATE TABLE IF NOT EXISTS crm_notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID REFERENCES crm_contacts(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES users(id) NOT NULL,
  author_name TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE crm_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Team members can view crm notes" ON crm_notes;
CREATE POLICY "Team members can view crm notes" ON crm_notes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM crm_contacts
      JOIN team_members ON team_members.team_id = crm_contacts.team_id
      WHERE crm_contacts.id = crm_notes.contact_id
      AND team_members.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Team owner and members can insert crm notes" ON crm_notes;
CREATE POLICY "Team owner and members can insert crm notes" ON crm_notes
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM crm_contacts
      JOIN team_members ON team_members.team_id = crm_contacts.team_id
      WHERE crm_contacts.id = crm_notes.contact_id
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'member')
    )
  );

DROP POLICY IF EXISTS "Author can delete own crm notes" ON crm_notes;
CREATE POLICY "Author can delete own crm notes" ON crm_notes
  FOR DELETE USING (auth.uid() = author_id);


-- ════════════════════════════════════════════════════════════
-- 9. RPC FUNCTIONS (Atomic transactions)
-- ════════════════════════════════════════════════════════════

-- Auto-create public.users on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, name, email, created_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = CASE WHEN public.users.name IS NULL OR public.users.name = ''
           THEN EXCLUDED.name ELSE public.users.name END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Sync existing auth.users to public.users
INSERT INTO public.users (id, name, email, created_at)
SELECT
  au.id,
  COALESCE(au.raw_user_meta_data->>'name', au.raw_user_meta_data->>'full_name', ''),
  au.email,
  au.created_at
FROM auth.users au
WHERE NOT EXISTS (
  SELECT 1 FROM public.users pu WHERE pu.id = au.id
);

-- Search users by email (SECURITY DEFINER to bypass RLS)
CREATE OR REPLACE FUNCTION search_users_by_email(search_query TEXT)
RETURNS TABLE (
  id UUID,
  name TEXT,
  email TEXT,
  avatar_url TEXT,
  locale TEXT,
  is_dark_mode BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  IF POSITION('@' IN search_query) > 0 THEN
    RETURN QUERY
    SELECT u.id, u.name, u.email, u.avatar_url, u.locale, u.is_dark_mode, u.created_at
    FROM users u
    WHERE u.email ILIKE search_query || '%'
    LIMIT 10;
  ELSE
    RETURN QUERY
    SELECT u.id, u.name, u.email, u.avatar_url, u.locale, u.is_dark_mode, u.created_at
    FROM users u
    WHERE SPLIT_PART(u.email, '@', 1) ILIKE search_query || '%'
    LIMIT 10;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Transfer team ownership (atomic)
CREATE OR REPLACE FUNCTION transfer_team_ownership(
  p_team_id UUID,
  p_current_owner_id UUID,
  p_new_owner_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM teams
    WHERE id = p_team_id AND owner_id = p_current_owner_id
  ) THEN
    RAISE EXCEPTION 'Not the team owner';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = p_team_id AND user_id = p_new_owner_id
  ) THEN
    RAISE EXCEPTION 'New owner is not a team member';
  END IF;

  UPDATE team_members SET role = 'owner'
  WHERE team_id = p_team_id AND user_id = p_new_owner_id;

  UPDATE team_members SET role = 'member'
  WHERE team_id = p_team_id AND user_id = p_current_owner_id;

  UPDATE teams SET owner_id = p_new_owner_id
  WHERE id = p_team_id;
END;
$$;

-- Unshare card from team (atomic: delete CRM + shared card)
CREATE OR REPLACE FUNCTION unshare_card_from_team(
  p_shared_card_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM crm_contacts WHERE shared_card_id = p_shared_card_id;
  DELETE FROM team_shared_cards WHERE id = p_shared_card_id;
END;
$$;

-- Share card to team (snapshot: SELECT + INSERT atomic)
CREATE OR REPLACE FUNCTION share_card_to_team(
  p_card_id UUID,
  p_team_id UUID,
  p_user_id UUID,
  p_category_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_card RECORD;
BEGIN
  SELECT * INTO v_card
  FROM collected_cards
  WHERE id = p_card_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Card not found';
  END IF;

  INSERT INTO team_shared_cards (
    card_id, team_id, shared_by, shared_at,
    name, company, position, department,
    email, phone, mobile, fax,
    address, website, sns_url, memo, image_url,
    category_id
  ) VALUES (
    p_card_id, p_team_id, p_user_id, NOW(),
    v_card.name, v_card.company, v_card.position, v_card.department,
    v_card.email, v_card.phone, v_card.mobile, v_card.fax,
    v_card.address, v_card.website, v_card.sns_url, v_card.memo, v_card.image_url,
    p_category_id
  );
END;
$$;


-- ════════════════════════════════════════════════════════════
-- 10. INDEXES
-- ════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_my_cards_user ON my_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_collected_cards_user ON collected_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_collected_cards_category ON collected_cards(category_id);
CREATE INDEX IF NOT EXISTS idx_collected_cards_name ON collected_cards(name);
CREATE INDEX IF NOT EXISTS idx_collected_cards_favorite ON collected_cards(user_id, is_favorite) WHERE is_favorite = true;
CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team ON team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_context_tags_card ON context_tags(card_id);
CREATE INDEX IF NOT EXISTS idx_tag_templates_user ON tag_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_team_invitations_invitee ON team_invitations(invitee_id, status);
CREATE INDEX IF NOT EXISTS idx_team_invitations_team ON team_invitations(team_id, status);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_team ON crm_contacts(team_id);
CREATE INDEX IF NOT EXISTS idx_crm_contacts_status ON crm_contacts(status);
CREATE INDEX IF NOT EXISTS idx_crm_notes_contact ON crm_notes(contact_id);


-- ════════════════════════════════════════════════════════════
-- STORAGE BUCKETS (Create manually in Supabase Dashboard > Storage)
-- 1. Create bucket 'card-images' (public)
-- 2. Create bucket 'profile-images' (public)
-- ════════════════════════════════════════════════════════════
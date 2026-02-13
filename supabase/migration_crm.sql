-- ──────────────── CRM Contacts ────────────────
-- 팀 기반 CRM 연락처 관리 테이블
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

CREATE POLICY "Team members can view crm contacts" ON crm_contacts
  FOR SELECT USING (is_team_member(team_id));

CREATE POLICY "Team owner and members can insert crm contacts" ON crm_contacts
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = crm_contacts.team_id
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'member')
    )
  );

CREATE POLICY "Team owner and members can update crm contacts" ON crm_contacts
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM team_members
      WHERE team_members.team_id = crm_contacts.team_id
      AND team_members.user_id = auth.uid()
      AND team_members.role IN ('owner', 'member')
    )
  );

CREATE POLICY "Team owner can delete crm contacts" ON crm_contacts
  FOR DELETE USING (is_team_owner(team_id));

CREATE INDEX idx_crm_contacts_team ON crm_contacts(team_id);
CREATE INDEX idx_crm_contacts_status ON crm_contacts(status);

-- ──────────────── CRM Notes ────────────────
-- CRM 연락처별 활동 노트
CREATE TABLE IF NOT EXISTS crm_notes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contact_id UUID REFERENCES crm_contacts(id) ON DELETE CASCADE NOT NULL,
  author_id UUID REFERENCES users(id) NOT NULL,
  author_name TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE crm_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Team members can view crm notes" ON crm_notes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM crm_contacts
      JOIN team_members ON team_members.team_id = crm_contacts.team_id
      WHERE crm_contacts.id = crm_notes.contact_id
      AND team_members.user_id = auth.uid()
    )
  );

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

CREATE POLICY "Author can delete own crm notes" ON crm_notes
  FOR DELETE USING (auth.uid() = author_id);

CREATE INDEX idx_crm_notes_contact ON crm_notes(contact_id);
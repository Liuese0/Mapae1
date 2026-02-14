-- Migration: Quick share session discovery + bilateral exchange queue

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
  status TEXT NOT NULL DEFAULT 'requested', -- requested/responded/completed
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
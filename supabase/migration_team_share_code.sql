-- Migration: Team Share Code
-- Adds a share code feature to teams so members can join via a code.
-- - share_code: unique 8-char alphanumeric code, NULL until owner activates
-- - share_code_enabled: owner toggles this to activate/deactivate the code

ALTER TABLE teams
  ADD COLUMN IF NOT EXISTS share_code TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS share_code_enabled BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_teams_share_code ON teams(share_code)
  WHERE share_code IS NOT NULL;

-- ─── Helper: generate a random 8-char code (uppercase alphanum, no I/O/1/0) ───
CREATE OR REPLACE FUNCTION _generate_share_code()
RETURNS TEXT AS $$
DECLARE
  chars  TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i      INT;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ─── RPC: owner activates (or re-generates) the share code ───────────────────
-- Returns the new share code string.
CREATE OR REPLACE FUNCTION enable_team_share_code(p_team_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
BEGIN
  IF NOT is_team_owner(p_team_id) THEN
    RAISE EXCEPTION 'Only the team owner can enable the share code';
  END IF;

  -- Generate a globally-unique code (collision loop, extremely rare)
  LOOP
    v_code := _generate_share_code();
    EXIT WHEN NOT EXISTS (SELECT 1 FROM teams WHERE share_code = v_code);
  END LOOP;

  UPDATE teams
  SET share_code         = v_code,
      share_code_enabled = true,
      updated_at         = NOW()
  WHERE id = p_team_id;

  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── RPC: owner disables the share code (code is kept, just deactivated) ─────
CREATE OR REPLACE FUNCTION disable_team_share_code(p_team_id UUID)
RETURNS void AS $$
BEGIN
  IF NOT is_team_owner(p_team_id) THEN
    RAISE EXCEPTION 'Only the team owner can disable the share code';
  END IF;

  UPDATE teams
  SET share_code_enabled = false,
      updated_at         = NOW()
  WHERE id = p_team_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── RPC: get share code info (owner/member only, not observer) ───────────────
-- Returns {share_code, share_code_enabled} or raises if not authorized.
CREATE OR REPLACE FUNCTION get_team_share_info(p_team_id UUID)
RETURNS TABLE(share_code TEXT, share_code_enabled BOOLEAN) AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = p_team_id
      AND user_id = auth.uid()
      AND role IN ('owner', 'member')
  ) THEN
    RAISE EXCEPTION 'Only team owners and members can view the share code';
  END IF;

  RETURN QUERY
    SELECT t.share_code, t.share_code_enabled
    FROM teams t
    WHERE t.id = p_team_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ─── RPC: join a team by entering the share code ─────────────────────────────
-- Returns the team_id that was joined.
CREATE OR REPLACE FUNCTION join_team_by_code(p_code TEXT)
RETURNS UUID AS $$
DECLARE
  v_team_id  UUID;
  v_username TEXT;
BEGIN
  SELECT id INTO v_team_id
  FROM teams
  WHERE share_code         = upper(trim(p_code))
    AND share_code_enabled = true;

  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or inactive share code';
  END IF;

  IF EXISTS (
    SELECT 1 FROM team_members
    WHERE team_id = v_team_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Already a team member';
  END IF;

  SELECT name INTO v_username FROM users WHERE id = auth.uid();

  INSERT INTO team_members (team_id, user_id, role, user_name, joined_at)
  VALUES (v_team_id, auth.uid(), 'observer', COALESCE(v_username, '이름 없음'), NOW());

  RETURN v_team_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

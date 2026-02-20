-- ──────────────── Team Share Code Migration ────────────────
-- Adds share_code and share_code_enabled columns to teams table.
-- Adds RPC functions to generate a share code and to join a team via share code.

-- 1. Add columns to teams table
ALTER TABLE teams ADD COLUMN IF NOT EXISTS share_code TEXT UNIQUE;
ALTER TABLE teams ADD COLUMN IF NOT EXISTS share_code_enabled BOOLEAN DEFAULT false;

-- 2. RPC: generate (or regenerate) a team share code — owner only
CREATE OR REPLACE FUNCTION generate_team_share_code(p_team_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_code TEXT;
BEGIN
  -- Only the team owner may call this
  IF NOT is_team_owner(p_team_id) THEN
    RAISE EXCEPTION 'Not authorized: only the team owner can generate a share code';
  END IF;

  -- Generate a unique 8-character uppercase alphanumeric code
  LOOP
    v_code := upper(substring(encode(gen_random_bytes(6), 'base64') from 1 for 8));
    -- Remove characters that can be confused (0, O, I, 1, +, /)
    v_code := regexp_replace(v_code, '[0OI1+/=]', '', 'g');
    -- Pad if necessary by appending from another random block
    WHILE length(v_code) < 8 LOOP
      v_code := v_code || upper(substring(encode(gen_random_bytes(4), 'base64') from 1 for 4));
      v_code := regexp_replace(v_code, '[0OI1+/=]', '', 'g');
    END LOOP;
    v_code := substring(v_code from 1 for 8);
    -- Make sure it is unique
    EXIT WHEN NOT EXISTS (SELECT 1 FROM teams WHERE share_code = v_code);
  END LOOP;

  UPDATE teams SET share_code = v_code WHERE id = p_team_id;

  RETURN v_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. RPC: toggle share code enabled/disabled — owner only
CREATE OR REPLACE FUNCTION toggle_team_share_code(p_team_id UUID, p_enabled BOOLEAN)
RETURNS VOID AS $$
BEGIN
  IF NOT is_team_owner(p_team_id) THEN
    RAISE EXCEPTION 'Not authorized: only the team owner can toggle the share code';
  END IF;

  -- Auto-generate a code if enabling for the first time and none exists
  IF p_enabled AND (SELECT share_code FROM teams WHERE id = p_team_id) IS NULL THEN
    PERFORM generate_team_share_code(p_team_id);
  END IF;

  UPDATE teams SET share_code_enabled = p_enabled WHERE id = p_team_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC: join a team using a share code — any authenticated user
--    On success inserts user as 'observer' and returns basic team info.
CREATE OR REPLACE FUNCTION join_team_by_share_code(p_share_code TEXT)
RETURNS JSONB AS $$
DECLARE
  v_team_id   UUID;
  v_team_name TEXT;
  v_user_id   UUID;
  v_user_name TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Look up active team by share code (case-insensitive)
  SELECT id, name
    INTO v_team_id, v_team_name
    FROM teams
   WHERE share_code = upper(p_share_code)
     AND share_code_enabled = true;

  IF v_team_id IS NULL THEN
    RAISE EXCEPTION 'Invalid or inactive share code';
  END IF;

  -- Check if user is already a member
  IF EXISTS (
    SELECT 1 FROM team_members
     WHERE team_id = v_team_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Already a member of this team';
  END IF;

  -- Fetch user display name
  SELECT name INTO v_user_name FROM users WHERE id = v_user_id;

  -- Insert as observer
  INSERT INTO team_members (team_id, user_id, role, user_name, joined_at)
  VALUES (v_team_id, v_user_id, 'observer', v_user_name, NOW());

  RETURN jsonb_build_object('team_id', v_team_id, 'team_name', v_team_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Index for share code lookup
CREATE INDEX IF NOT EXISTS idx_teams_share_code ON teams(share_code) WHERE share_code IS NOT NULL;

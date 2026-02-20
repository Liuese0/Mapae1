-- Migration: Fix RLS error when accepting a team invitation
-- Problem: team_members INSERT policy only allows team owners to insert rows.
--          When an invitee accepts an invitation the INSERT is blocked (42501).
-- Solution: A SECURITY DEFINER RPC function that validates the pending invitation
--           belongs to the calling user before performing both operations atomically.

CREATE OR REPLACE FUNCTION accept_team_invitation(invitation_id UUID)
RETURNS void AS $$
DECLARE
  v_inv  team_invitations%ROWTYPE;
  v_name TEXT;
BEGIN
  -- Validate: invitation must be pending and belong to the calling user
  SELECT * INTO v_inv
  FROM team_invitations
  WHERE id         = invitation_id
    AND invitee_id = auth.uid()
    AND status     = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invitation not found or already processed';
  END IF;

  -- Mark invitation as accepted
  UPDATE team_invitations
  SET status     = 'accepted',
      updated_at = NOW()
  WHERE id = invitation_id;

  -- Fetch caller's display name
  SELECT name INTO v_name FROM users WHERE id = auth.uid();

  -- Add caller to team_members (bypass team-owner-only INSERT policy)
  INSERT INTO team_members (team_id, user_id, role, user_name, joined_at)
  VALUES (
    v_inv.team_id,
    auth.uid(),
    'observer',
    COALESCE(v_name, '이름 없음'),
    NOW()
  )
  ON CONFLICT (team_id, user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

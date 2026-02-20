-- Migration: Fix RLS policies so invitees can see inviter name and team name
-- Problem: When invited users view their notifications, inviter name and team name
--          appear as null because:
--          1. users table RLS only allows viewing own profile
--          2. teams table RLS only allows viewing teams you are already a member of
-- Solution: Add policies to allow invitees to read the inviter's name and the
--           invited team's info when a pending invitation exists.

-- ──────────────── users table: allow invitee to see inviter's name ────────────────
DROP POLICY IF EXISTS "Invitees can view inviter profile" ON users;

CREATE POLICY "Invitees can view inviter profile" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM team_invitations
      WHERE team_invitations.status = 'pending'
        AND (
          -- 나(auth.uid())가 초대받은 경우 → 초대한 사람(inviter_id)의 프로필 조회 허용
          (team_invitations.invitee_id = auth.uid() AND team_invitations.inviter_id = users.id)
          OR
          -- 나(auth.uid())가 초대한 경우 → 초대받은 사람(invitee_id)의 프로필 조회 허용
          (team_invitations.inviter_id = auth.uid() AND team_invitations.invitee_id = users.id)
        )
    )
  );

-- ──────────────── teams table: allow invitee to see invited team info ────────────────
DROP POLICY IF EXISTS "Invitees can view invited team" ON teams;

CREATE POLICY "Invitees can view invited team" ON teams
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM team_invitations
      WHERE team_invitations.team_id = teams.id
        AND team_invitations.invitee_id = auth.uid()
        AND team_invitations.status = 'pending'
    )
  );

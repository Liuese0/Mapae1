-- Migration: Fix unique constraint on team_invitations to allow re-inviting
-- Problem: UNIQUE(team_id, invitee_id) prevents re-inviting a user who has
--          previously declined or whose prior invitation was in any other state.
--          The constraint name "team_invitations_team_id_invitee_id_key" confirms
--          that status is not part of the constraint.
-- Solution: Replace the overly-strict unique constraint with a partial unique index
--           that only prevents duplicate *pending* invitations.

-- Step 1: Remove the existing constraint (covers all status values)
ALTER TABLE team_invitations
  DROP CONSTRAINT IF EXISTS team_invitations_team_id_invitee_id_key;

-- Also drop the three-column variant in case it exists under that name
ALTER TABLE team_invitations
  DROP CONSTRAINT IF EXISTS team_invitations_team_id_invitee_id_status_key;

-- Step 2: Create a partial unique index – only one pending invitation per
--         (team, invitee) pair is allowed. Accepted / declined rows are not
--         constrained, so a user can be re-invited after declining.
CREATE UNIQUE INDEX IF NOT EXISTS team_invitations_team_id_invitee_id_pending_key
  ON team_invitations (team_id, invitee_id)
  WHERE status = 'pending';

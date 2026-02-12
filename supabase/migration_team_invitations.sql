-- Migration: Add team_invitations table and search_users_by_email RPC function
-- Run this in Supabase SQL Editor

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

-- 기존 정책 삭제 후 재생성 (이미 존재하는 경우 에러 방지)
DROP POLICY IF EXISTS "Users can view their invitations" ON team_invitations;
DROP POLICY IF EXISTS "Team members can create invitations" ON team_invitations;
DROP POLICY IF EXISTS "Invitee can update invitation" ON team_invitations;
DROP POLICY IF EXISTS "Inviter can delete invitation" ON team_invitations;

-- 초대를 보낸 사람과 받은 사람 모두 조회 가능
CREATE POLICY "Users can view their invitations" ON team_invitations
  FOR SELECT USING (
    auth.uid() = inviter_id OR auth.uid() = invitee_id
  );

-- 팀 소유자/멤버가 초대 생성 가능
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

-- 초대 상태 업데이트 (수락/거절)
CREATE POLICY "Invitee can update invitation" ON team_invitations
  FOR UPDATE USING (
    auth.uid() = invitee_id OR auth.uid() = inviter_id
  );

-- 초대 삭제 (취소)
CREATE POLICY "Inviter can delete invitation" ON team_invitations
  FOR DELETE USING (auth.uid() = inviter_id);

CREATE INDEX IF NOT EXISTS idx_team_invitations_invitee ON team_invitations(invitee_id, status);
CREATE INDEX IF NOT EXISTS idx_team_invitations_team ON team_invitations(team_id, status);

-- ──────────────── Auto-create public.users on signup ────────────────
-- auth.users에 가입 시 public.users에 자동 레코드 생성
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

-- 기존 트리거가 있으면 삭제 후 재생성
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 기존 auth.users 중 public.users에 없는 유저 동기화
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

-- ──────────────── Search Users by Email RPC ────────────────
-- SECURITY DEFINER로 생성하여 users 테이블의 RLS를 우회
-- @ 입력 전: 로컬파트(@ 앞부분)로만 검색 (예: "m" → mammonwin@gmail.com)
-- @ 입력 후: 전체 이메일로 검색 (예: "bang6bin@g" → bang6bin@gmail.com)
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
    -- @ 포함: 전체 이메일로 검색
    RETURN QUERY
    SELECT u.id, u.name, u.email, u.avatar_url, u.locale, u.is_dark_mode, u.created_at
    FROM users u
    WHERE u.email ILIKE search_query || '%'
    LIMIT 10;
  ELSE
    -- @ 미포함: 로컬파트(@ 앞부분)만 매칭
    RETURN QUERY
    SELECT u.id, u.name, u.email, u.avatar_url, u.locale, u.is_dark_mode, u.created_at
    FROM users u
    WHERE SPLIT_PART(u.email, '@', 1) ILIKE search_query || '%'
    LIMIT 10;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
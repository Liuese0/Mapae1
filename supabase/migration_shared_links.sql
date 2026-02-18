-- shared_links: SNS 공유 시 명함 데이터를 저장하고 딥링크 토큰으로 조회
CREATE TABLE IF NOT EXISTS shared_links (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  card_data jsonb NOT NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE shared_links ENABLE ROW LEVEL SECURITY;

-- 누구나 공유된 명함 조회 가능 (링크를 받은 사람)
CREATE POLICY "Anyone can read shared links"
  ON shared_links FOR SELECT
  USING (true);

-- 로그인한 사용자만 공유 링크 생성 가능
CREATE POLICY "Authenticated users can create shared links"
  ON shared_links FOR INSERT
  TO authenticated
  WITH CHECK (true);
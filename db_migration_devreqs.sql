-- ══════════════════════════════════════════════════════════════
-- 개발 요청 게시판: sc_devreqs (접수 → 처리 → 답변)
-- 대상: happysolar 프로젝트. 기존 무접촉. Supabase SQL Editor에 Run.
-- ══════════════════════════════════════════════════════════════
create table if not exists public.sc_devreqs (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text,
  category    text default '기능요청',      -- 기능요청 | 버그 | 개선 | 기타
  author      text, author_id uuid,
  status      text default '접수',          -- 접수 | 검토중 | 완료 | 보류
  reply       text, replied_by text, replied_at timestamptz,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- RLS: 기존 sc_* 와 동일 (로그인 사용자 읽기·쓰기 / 답변·상태변경은 프런트에서 관리자만 노출)
alter table public.sc_devreqs enable row level security;
drop policy if exists "sc_read" on public.sc_devreqs;
create policy "sc_read" on public.sc_devreqs for select to authenticated using (true);
drop policy if exists "sc_write" on public.sc_devreqs;
create policy "sc_write" on public.sc_devreqs for all to authenticated using (true) with check (true);

-- 실시간(다른 사용자 화면에 즉시 반영). 이미 등록돼 있으면 조용히 넘어감.
do $$ begin
  alter publication supabase_realtime add table public.sc_devreqs;
exception when duplicate_object then null; when undefined_object then null;
end $$;

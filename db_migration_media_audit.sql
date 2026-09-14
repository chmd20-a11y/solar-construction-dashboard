-- ══════════════════════════════════════════════════════════════
-- 추가 마이그레이션: 시공사진(sc_media) + 감사로그(sc_audit)
-- 대상: happysolar 프로젝트. 기존/기타 테이블 무접촉. SQL Editor에 Run.
-- (여러 번 실행해도 안전 — if not exists / drop policy 방식)
-- ══════════════════════════════════════════════════════════════

-- 시공 사진·영상
create table if not exists public.sc_media (
  id uuid primary key default gen_random_uuid(),
  site_id uuid references public.sc_sites on delete cascade,
  kind text,              -- image | video
  url text, name text, mime text, size bigint,
  uploaded_by uuid, uploader text,
  created_at timestamptz default now()
);
alter table public.sc_media enable row level security;
drop policy if exists "sc_media_read"  on public.sc_media;
create policy "sc_media_read"  on public.sc_media for select to authenticated using (true);
drop policy if exists "sc_media_write" on public.sc_media;
create policy "sc_media_write" on public.sc_media for all to authenticated using (true) with check (true);

-- 감사 로그 (누가·언제·무엇을)
create table if not exists public.sc_audit (
  id uuid primary key default gen_random_uuid(),
  user_id uuid, email text, role text,
  action text,            -- login/create/update/delete/send/ack ...
  entity text,            -- site/issue/inspection/media/preset/auth ...
  entity_name text,       -- 대상(현장명·제목 등)
  detail text,            -- 부가 설명
  created_at timestamptz default now()
);
alter table public.sc_audit enable row level security;
-- 기록: 로그인 사용자가 본인 것만 남길 수 있음
drop policy if exists "sc_audit_insert_self" on public.sc_audit;
create policy "sc_audit_insert_self" on public.sc_audit
  for insert to authenticated with check (user_id = auth.uid());
-- 열람: 관리자(profiles.role='admin')만
drop policy if exists "sc_audit_read_admin" on public.sc_audit;
create policy "sc_audit_read_admin" on public.sc_audit
  for select to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

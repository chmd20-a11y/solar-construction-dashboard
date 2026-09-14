-- ══════════════════════════════════════════════════════════════
-- 개인 로그인단: 회원(sc_members) + 관리자 승인제 (PLOT 방식)
-- 대상: happysolar 프로젝트. 기존 무접촉. SQL Editor에 Run.
-- ══════════════════════════════════════════════════════════════
create table if not exists public.sc_members (
  user_id    uuid primary key references auth.users on delete cascade,
  email      text, name text,
  role       text default 'user',      -- user | admin
  approved   boolean default false,     -- 관리자 승인 여부
  created_at timestamptz default now()
);

-- 관리자 판별 함수 (RLS 재귀 방지: security definer로 RLS 우회)
create or replace function public.sc_is_admin() returns boolean
  language sql security definer stable set search_path=public as $$
  select exists(select 1 from public.sc_members where user_id = auth.uid() and role='admin' and approved);
$$;

alter table public.sc_members enable row level security;
-- 본인 행 or 관리자 전체 읽기
drop policy if exists sc_mem_read on public.sc_members;
create policy sc_mem_read on public.sc_members for select to authenticated
  using (user_id = auth.uid() or public.sc_is_admin());
-- 가입: 본인 행만, 비관리자는 승인=false·역할=user 강제
drop policy if exists sc_mem_ins on public.sc_members;
create policy sc_mem_ins on public.sc_members for insert to authenticated
  with check (user_id = auth.uid() and (public.sc_is_admin() or (approved = false and role = 'user')));
-- 승인/역할 변경: 관리자만
drop policy if exists sc_mem_upd on public.sc_members;
create policy sc_mem_upd on public.sc_members for update to authenticated
  using (public.sc_is_admin()) with check (public.sc_is_admin());
-- 삭제: 관리자만
drop policy if exists sc_mem_del on public.sc_members;
create policy sc_mem_del on public.sc_members for delete to authenticated
  using (public.sc_is_admin());

-- 부트스트랩: master(+admin@) 계정을 관리자·승인으로 (이메일로 조회 — uid 하드코딩 회피)
insert into public.sc_members(user_id,email,name,role,approved)
  select id, email, coalesce(email,'admin'), 'admin', true
  from auth.users where email in ('master@example.com','admin@example.com')
  on conflict (user_id) do update set role='admin', approved=true;

-- 감사로그 열람 권한을 sc_members 관리자 기준으로 교체(신규 관리자도 열람 가능)
drop policy if exists "sc_audit_read_admin" on public.sc_audit;
create policy "sc_audit_read_admin" on public.sc_audit for select to authenticated
  using (public.sc_is_admin());

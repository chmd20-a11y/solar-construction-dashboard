-- ══════════════════════════════════════════════════════════════
-- 시공현장 대시보드 — 기존 Supabase 프로젝트에 "얹기"용 스키마
-- 대상: happysolar 프로젝트 (상담일지와 공용, ref cgthfwlswaohxolgixvv)
-- ★ 모든 객체에 sc_ 접두 → 기존 테이블(branches/profiles/promotions/
--   consultations)·트리거·정책을 절대 건드리지 않습니다.
-- Supabase SQL Editor에 전체 붙여넣고 Run.
-- ══════════════════════════════════════════════════════════════
create extension if not exists "pgcrypto";

create table if not exists public.sc_sites (
  id uuid primary key default gen_random_uuid(),
  name text not null, owner text, type text default '지붕', cap numeric default 0, loc text,
  mname text, mphone text, cname text, cphone text,
  start_date date, due_date date,
  stage int default 0, progress int default 0, status text default '정상', note text,
  module_model text, module_qty int default 0, inverter_model text, inverter_qty int default 0,
  builder text, civil text, process_chart text,
  permits jsonb default '[]',
  acks jsonb default '[]',          -- 확인 대상 명단(roster) [{name,email}]
  ack_version int default 1,
  created_at timestamptz default now(), updated_at timestamptz default now()
);
create table if not exists public.sc_issues (
  id uuid primary key default gen_random_uuid(),
  site_id uuid references public.sc_sites on delete cascade,
  date date, cat text, title text, content text, reporter text,
  actionby text, actiondate date, action text,
  status text default '접수', resolvedate date, resolution text,
  photos jsonb default '[]', created_at timestamptz default now()
);
create table if not exists public.sc_inspections (
  id uuid primary key default gen_random_uuid(),
  site_id uuid references public.sc_sites on delete cascade,
  date date, inspector text, result text, note text,
  photos jsonb default '[]', created_at timestamptz default now()
);
-- 담당자 확인: 본인 계정으로만 생성/삭제 (법적 근거)
create table if not exists public.sc_acks (
  id uuid primary key default gen_random_uuid(),
  site_id uuid references public.sc_sites on delete cascade,
  user_id uuid references auth.users on delete cascade,
  email text, ack_version int not null,
  acknowledged_at timestamptz default now(),
  unique(site_id, user_id, ack_version)
);
create table if not exists public.sc_presets (
  id uuid primary key default gen_random_uuid(),
  category text default '작업 전', title text not null, body text not null,
  sched jsonb default '{"on":false,"freq":"weekday","time":"07:00","weekday":"1"}',
  created_at timestamptz default now()
);
create table if not exists public.sc_send_logs (
  id uuid primary key default gen_random_uuid(),
  site_id uuid, category text, title text, name text, site_name text, phone text, msg_type text,
  status text, sent_by uuid, created_at timestamptz default now()
);
create table if not exists public.sc_app_settings (
  id int primary key default 1,
  data jsonb default '{"auto":false,"type":"auto","id":"","key":"","sender":""}'
);
insert into public.sc_app_settings(id) values (1) on conflict (id) do nothing;

-- RLS (sc_* 에만 적용)
alter table public.sc_sites        enable row level security;
alter table public.sc_issues       enable row level security;
alter table public.sc_inspections  enable row level security;
alter table public.sc_acks         enable row level security;
alter table public.sc_presets      enable row level security;
alter table public.sc_send_logs    enable row level security;
alter table public.sc_app_settings enable row level security;

do $$ declare t text;
begin
  foreach t in array array['sc_sites','sc_issues','sc_inspections','sc_acks','sc_presets','sc_send_logs','sc_app_settings']
  loop
    execute format('drop policy if exists "sc_read" on public.%I', t);
    execute format('create policy "sc_read" on public.%I for select to authenticated using (true)', t);
  end loop;
  foreach t in array array['sc_sites','sc_issues','sc_inspections','sc_presets','sc_send_logs','sc_app_settings']
  loop
    execute format('drop policy if exists "sc_write" on public.%I', t);
    execute format('create policy "sc_write" on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- 확인: 본인 것만
drop policy if exists "sc_ack_ins" on public.sc_acks;
create policy "sc_ack_ins" on public.sc_acks for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "sc_ack_del" on public.sc_acks;
create policy "sc_ack_del" on public.sc_acks for delete to authenticated using (user_id = auth.uid());

-- Storage: 전용 버킷 sc-photos (기존 버킷 무관)
insert into storage.buckets (id, name, public) values ('sc-photos','sc-photos', true) on conflict (id) do nothing;
drop policy if exists "scphotos_read" on storage.objects;
create policy "scphotos_read" on storage.objects for select using (bucket_id = 'sc-photos');
drop policy if exists "scphotos_write" on storage.objects;
create policy "scphotos_write" on storage.objects for insert to authenticated with check (bucket_id = 'sc-photos');
drop policy if exists "scphotos_update" on storage.objects;
create policy "scphotos_update" on storage.objects for update to authenticated using (bucket_id = 'sc-photos');

-- (선택) 예제 현장 1건 — 확인 후 삭제하세요: delete from public.sc_sites;
insert into public.sc_sites (name,owner,type,cap,loc,mname,mphone,cname,cphone,start_date,due_date,stage,progress,status,note,module_model,module_qty,inverter_model,inverter_qty,builder,civil,acks)
values ('(예제) 김포 물류창고 지붕태양광','(주)김포물류','지붕',480,'경기 김포','홍길동','010-1234-5678','김담당','010-2222-3333','2026-08-01','2026-10-25',6,58,'정상','예제 데이터입니다. 확인 후 삭제하세요.','한화 Q.PEAK 575W',835,'HD250',2,'해피솔라','대명토건','[]')
on conflict do nothing;

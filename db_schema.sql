-- ══════════════════════════════════════════════════════════════
-- 태양광 시공현장 종합 현황 대시보드 — Supabase 스키마
-- Supabase 대시보드 > SQL Editor 에 전체 붙여넣고 [Run] 하세요.
-- (여러 번 실행해도 안전하도록 IF NOT EXISTS / drop policy 처리)
-- ══════════════════════════════════════════════════════════════

-- 0) 확장
create extension if not exists "pgcrypto";

-- 1) 사용자 프로필 (auth.users 와 1:1)
create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  name       text not null,
  role       text default '담당자',
  created_at timestamptz default now()
);

-- 2) 현장
create table if not exists public.sites (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  owner         text,               -- 사업주 성명
  type          text default '지붕', -- 지붕/부지/축사
  cap           numeric default 0,   -- 용량 kW
  loc           text,
  mname         text, mphone text,   -- 소장
  cname         text, cphone text,   -- 담당자
  start_date    date, due_date date,
  stage         int default 0,       -- 0=계약 ... 9=준공검사
  progress      int default 0,
  status        text default '정상',  -- 정상/주의/지연
  note          text,
  module_model  text, module_qty int default 0,
  inverter_model text, inverter_qty int default 0,
  builder       text,                -- 시공업체
  civil         text,                -- 토목업체
  process_chart text,                -- 공정표 이미지 URL(스토리지)
  permits       jsonb default '[]',  -- [{name,status,date}]
  ack_version   int default 1,       -- 확인 재요청 시 +1
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- 3) 이슈 (발생 → 조치 → 처리)
create table if not exists public.issues (
  id          uuid primary key default gen_random_uuid(),
  site_id     uuid references public.sites on delete cascade,
  date        date, cat text, title text, content text, reporter text,
  actionby    text, actiondate date, action text,
  status      text default '접수', resolvedate date, resolution text,
  photos      jsonb default '[]',   -- [url,...]
  created_at  timestamptz default now()
);

-- 4) 현장 점검
create table if not exists public.inspections (
  id          uuid primary key default gen_random_uuid(),
  site_id     uuid references public.sites on delete cascade,
  date        date, inspector text, result text, note text,
  photos      jsonb default '[]',
  created_at  timestamptz default now()
);

-- 5) 담당자 확인 (본인 계정으로만 확인 → 법적 근거)
create table if not exists public.acknowledgments (
  id              uuid primary key default gen_random_uuid(),
  site_id         uuid references public.sites on delete cascade,
  user_id         uuid references auth.users on delete cascade,
  ack_version     int not null,       -- 확인 당시 현황 버전
  acknowledged_at timestamptz default now(),
  unique(site_id, user_id, ack_version)
);

-- 6) 안전 안내 프리셋
create table if not exists public.presets (
  id         uuid primary key default gen_random_uuid(),
  category   text default '작업 전',
  title      text not null,
  body       text not null,
  sched      jsonb default '{"on":false,"freq":"weekday","time":"07:00","weekday":"1"}',
  created_at timestamptz default now()
);

-- 7) 발송 로그
create table if not exists public.send_logs (
  id         uuid primary key default gen_random_uuid(),
  site_id    uuid references public.sites on delete set null,
  category   text, title text, name text, site_name text, phone text, msg_type text,
  status     text,
  sent_by    uuid references auth.users on delete set null,
  created_at timestamptz default now()
);

-- 8) 앱 설정 (문자나라 등, 단일 행)
create table if not exists public.app_settings (
  id   int primary key default 1,
  data jsonb default '{"auto":false,"type":"auto","id":"","key":"","sender":""}'
);
insert into public.app_settings(id) values (1) on conflict (id) do nothing;

-- ── 자동 프로필 생성: 회원가입 시 profiles 행 생성 ──
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles(id, name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)), coalesce(new.raw_user_meta_data->>'role','담당자'))
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ══════════════════════════════════════════════════════════════
-- RLS (행 수준 보안) : 로그인한 팀원은 읽기/쓰기 가능,
--   단 '확인(acknowledgments)'은 본인 것만 남길 수 있음
-- ══════════════════════════════════════════════════════════════
alter table public.profiles        enable row level security;
alter table public.sites           enable row level security;
alter table public.issues          enable row level security;
alter table public.inspections     enable row level security;
alter table public.acknowledgments enable row level security;
alter table public.presets         enable row level security;
alter table public.send_logs       enable row level security;
alter table public.app_settings    enable row level security;

-- 공통: 로그인(authenticated) 사용자 전체 읽기
do $$ declare t text;
begin
  foreach t in array array['profiles','sites','issues','inspections','acknowledgments','presets','send_logs','app_settings']
  loop
    execute format('drop policy if exists "read_auth" on public.%I', t);
    execute format('create policy "read_auth" on public.%I for select to authenticated using (true)', t);
  end loop;
end $$;

-- 현장/이슈/점검/프리셋/로그/설정: 로그인 사용자 쓰기 허용
do $$ declare t text;
begin
  foreach t in array array['sites','issues','inspections','presets','send_logs','app_settings']
  loop
    execute format('drop policy if exists "write_auth" on public.%I', t);
    execute format('create policy "write_auth" on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- 프로필: 본인 것만 수정, 누구나 삽입(트리거)
drop policy if exists "profiles_upsert_self" on public.profiles;
create policy "profiles_upsert_self" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self" on public.profiles
  for insert to authenticated with check (id = auth.uid());

-- 확인(ack): 본인(user_id=auth.uid()) 것만 생성/삭제
drop policy if exists "ack_insert_self" on public.acknowledgments;
create policy "ack_insert_self" on public.acknowledgments
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "ack_delete_self" on public.acknowledgments;
create policy "ack_delete_self" on public.acknowledgments
  for delete to authenticated using (user_id = auth.uid());

-- ══════════════════════════════════════════════════════════════
-- Storage : 현장 사진/공정표 버킷
-- ══════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public)
values ('photos','photos', true)
on conflict (id) do nothing;

drop policy if exists "photos_read" on storage.objects;
create policy "photos_read" on storage.objects
  for select using (bucket_id = 'photos');
drop policy if exists "photos_write" on storage.objects;
create policy "photos_write" on storage.objects
  for insert to authenticated with check (bucket_id = 'photos');
drop policy if exists "photos_update" on storage.objects;
create policy "photos_update" on storage.objects
  for update to authenticated using (bucket_id = 'photos');

-- ══════════════════════════════════════════════════════════════
-- (선택) 예제 데이터 — 처음 감 잡기용. 실제 운영 전 삭제하세요.
-- ══════════════════════════════════════════════════════════════
insert into public.sites (name,owner,type,cap,loc,mname,mphone,cname,cphone,start_date,due_date,stage,progress,status,note,module_model,module_qty,inverter_model,inverter_qty,builder,civil)
values
 ('평택 물류센터 지붕태양광','(주)평택물류','지붕',620,'경기 평택','윤소장','010-5501-2200','한담당','010-5501-3300','2026-06-10','2026-09-18',9,96,'정상','이번 주 사용전검사 예정.','한화 Q.PEAK DUO 580W',1069,'HD500',2,'해피솔라','대명토건'),
 ('화성 공장 지붕태양광','화성산업(주)','지붕',750,'경기 화성','최소장','010-8888-9999','정담당','010-1010-2020','2026-05-20','2026-09-30',8,85,'지연','한전 계통연계 승인 대기.','한화 Q.PEAK 575W',1304,'선그로우 SG250HX',3,'해피솔라','정우토목'),
 ('이천 부지 태양광','이천에너지(주)','부지',990,'경기 이천','강소장','','백담당','010-9090-8080','2026-09-10','2027-01-31',1,10,'정상','개발행위허가 접수 단계.','미정',0,'미정',0,'해피솔라','미정')
on conflict do nothing;

insert into public.presets (category,title,body,sched) values
 ('작업 전','작업 전 안전점검(TBM) 안내','[{{날짜}} 작업 전 안전점검]\n{{현장명}} {{소장명}} 소장님, 안전한 하루 되십시오.\n1) 5분 TBM 실시\n2) 안전모·안전화·안전대 착용\n3) 고소작업 발판·난간 고정\n4) 감전예방 활선 이격 유지','{"on":true,"freq":"weekday","time":"07:00","weekday":"1"}'),
 ('작업 중','고소작업 안전대 체결 안내','[작업 중 안전 리마인드]\n{{현장명}} 2m 이상 고소작업 시 안전대 반드시 체결. 개구부·채광창 접근 금지.','{"on":false,"freq":"daily","time":"13:00","weekday":"1"}')
on conflict do nothing;

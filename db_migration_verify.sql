-- ══════════════════════════════════════════════════════════════
-- 공문 검증 기준값: sc_sites에 사업자번호·면적 컬럼 추가
-- 대상: happysolar. 기존 무접촉(컬럼 추가만). SQL Editor에 Run.
-- ══════════════════════════════════════════════════════════════
alter table public.sc_sites add column if not exists bizno text;   -- 사업자번호
alter table public.sc_sites add column if not exists area  numeric; -- 면적(㎡)

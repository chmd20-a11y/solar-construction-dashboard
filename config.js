/* ═══════════════════════════════════════════════════════════════
   Supabase 연결 설정
   ───────────────────────────────────────────────────────────────
   현재 '클라우드 모드' — happysolar 프로젝트에 얹음(sc_* 테이블).
   상담일지와 같은 프로젝트/계정을 공유합니다(로그인 계정 공용).
   비우면 '로컬 데모 모드'로 전환됩니다.

   ※ anon 키는 공개돼도 안전(설계상). 데이터는 sc_* 테이블의 RLS로 보호.
   ═══════════════════════════════════════════════════════════════ */
window.SUPABASE_URL = "https://cgthfwlswaohxolgixvv.supabase.co";
window.SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNndGhmd2xzd2FvaHhvbGdpeHZ2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc4NTE2MjMsImV4cCI6MjEwMzQyNzYyM30.zdd2BQI4UQv8WuFBddYI050r-PWGPSgVmUo53OEGims";

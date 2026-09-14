# 태양광 시공현장 종합 현황 대시보드 (실제 웹앱)

시공관리팀이 **진행 현장의 계약~준공 전 단계·이슈·점검·안전문자·담당자 확인**을
한 화면에서 관리하는 웹앱입니다. Supabase(DB·로그인·저장소) + 정적 프론트엔드.

## 📁 구성
| 파일 | 설명 |
|---|---|
| `index.html` | 앱 본체 (이 파일 하나만 열면 실행) |
| `config.js` | Supabase 주소·키 입력하는 곳 |
| `db_schema.sql` | Supabase에 붙여넣어 실행할 DB 설계·보안·저장소 |

## ⚡ 두 가지 모드 (자동 전환)
- **로컬 데모 모드** — `config.js`가 비어 있으면 자동. 설정 없이 `index.html`을 브라우저로 열면 바로 사용. 데이터는 그 브라우저에만 저장됩니다. (혼자 보기/시연용)
- **클라우드 모드** — `config.js`에 키를 채우면 자동. 로그인, 여러 명 실시간 공유, 사진 클라우드 저장, 확인 체크가 본인 계정으로 기록(법적 근거).

> 지금 당장은 아무것도 안 해도 **로컬 데모 모드로 바로 작동**합니다.
> 팀에서 함께 쓰려면 아래 5단계를 한 번만 하면 됩니다.

## 🚀 클라우드 모드 설치 (한 번만, 약 10분)

### 1. Supabase 프로젝트 생성
1. https://supabase.com 접속 → 로그인(무료) → **New project**
2. 이름/비밀번호 아무거나, 지역은 **Northeast Asia (Seoul)** 권장 → 생성(1~2분 대기)

### 2. 데이터베이스 설정 (SQL 실행)
1. 왼쪽 메뉴 **SQL Editor** → **New query**
2. `db_schema.sql` 파일 내용을 **전부 복사해 붙여넣기** → **Run**
3. "Success" 나오면 완료 (테이블·보안·저장소·예제데이터 자동 생성)

### 3. 키 입력
1. 왼쪽 **Settings → API**
2. **Project URL** 과 **anon public** 키를 복사
3. `config.js` 열어 두 값을 붙여넣고 저장:
   ```js
   window.SUPABASE_URL = "https://xxxx.supabase.co";
   window.SUPABASE_ANON_KEY = "eyJhbGci...";
   ```

### 4. 팀원 계정 만들기
1. Supabase **Authentication → Users → Add user** (이메일/비밀번호)
2. 팀원 수만큼 추가. (로그인하면 확인 체크에 그 사람 이름·시각이 기록됩니다)
   - 이름을 지정하려면 Add user 시 **User Metadata**에 `{"name":"홍길동","role":"현장소장"}` 입력

### 5. 배포 (팀원이 주소로 접속)
- **가장 쉬움:** `index.html`+`config.js`를 사내 공유폴더/PC에 두고 열기
- **주소로 공유(권장):** GitHub Pages
  1. 새 GitHub 저장소 만들고 세 파일 업로드
  2. Settings → Pages → Branch `main` 선택 → 저장
  3. 나오는 주소를 팀원에게 공유

## 🔐 보안 메모
- `anon` 키는 공개돼도 안전(설계상). 실제 데이터 보호는 DB의 **RLS 정책**이 담당합니다(로그인 사용자만 접근).
- **문자나라 실발송**은 API 키 발급 후 별도 서버 연동이 필요합니다. 그전까지는 앱에서 시뮬레이션(발송 기록만)으로 동작합니다.

## 🗑 예제 데이터 지우기
운영 시작 전, Supabase SQL Editor에서:
```sql
delete from public.sites; delete from public.presets;
```

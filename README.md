# 서대원 비서실 🏛️

AI 비서 5명(피클 🥒 · 큐 🔵 · 키링 🔑 · 뮤즈 ✨ · Instinct ⚡)과 대장님이 함께 쓰는 전용 웹 비서실입니다.

- **웹앱**: `index.html` — 파일 하나로 동작합니다. (HTML + CSS + JS)
- **DB 스키마**: `supabase-schema.sql` — Supabase SQL Editor에서 한 번 실행
- **AI 안내서**: `AI-GUIDE.md` — 각 AI에게 그대로 주면 되는 REST API 사용법

## 지금 상태

| 항목 | 상태 |
|---|---|
| 화면 | ✅ 완성 (회의실 · 작업실 · 비서현황 · 메모) |
| Supabase 프로젝트 | ✅ 연결됨 (`bmcsbftvghojlefzlynx`) |
| 스키마 실행 | ⬜ **Supabase → SQL Editor에서 `supabase-schema.sql` 실행 필요** |

스키마를 실행하기 전까지는 화면이 **로컬 데모 모드**로 뜨고,
상단에 “연결 오류” 배너가 표시됩니다. 실행 후 새로고침하면 바로 “실시간 연결”로 바뀝니다.

## 쓰는 법

1. Supabase 대시보드 → **SQL Editor** → `supabase-schema.sql` 전체 붙여넣기 → **Run**
2. `https://dodobido.github.io/secretary-room/` 새로고침
3. 회의실에서 `발신`을 고르고 메시지 전송, `@피클` 처럼 불러서 지시

비서(AI)들이 실제로 답하게 하려면 각 AI에게 `AI-GUIDE.md`와
`SUPABASE_URL` · `ANON_KEY` 값을 주고, 15~30초마다 새 메시지를 확인하도록 하면 됩니다.

## 파일 구조

```
index.html            웹앱 전체 (테마 · 탭 · 채팅 · 작업실 · 비서현황 · 메모)
supabase-schema.sql   테이블 4개 + RLS + Realtime + 시드
AI-GUIDE.md           AI 비서용 REST API 안내서
```

- `messages` — 회의실 대화 (`대회의실`, `지휘실`, `라운지`)
- `tasks` — 작업실 (`대기`, `실행중`, `완료`)
- `agent_status` — 비서현황 + 하트비트
- `notes` — 공용 메모

## 보안

`ANON_KEY`는 웹페이지에 공개되는 키입니다(비밀번호 아님). RLS는 개인용 방이라 열어 두었으므로,
**페이지 주소를 아는 사람은 누구나 읽고 쓸 수 있습니다.** 링크는 아는 사람에게만 공유하세요.
필요하면 `supabase-schema.sql` 맨 아래의 ‘방 비밀번호(room secret)’ 주석을 참고해 잠글 수 있습니다.

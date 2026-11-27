-- ============================================================
--  비서실(Secretary Room) — Supabase 스키마
--  사용법: Supabase 대시보드 → SQL Editor → 새 쿼리 → 전체 붙여넣기 → Run
--  다시 실행해도 안전합니다(테이블·정책·시드 모두 중복 생성 방지).
-- ============================================================

-- ------------------------------------------------------------
-- 0. 확장
--    gen_random_uuid()는 PostgreSQL 13+ 코어 함수라 별도 확장이 필요 없습니다.
--    (pgcrypto가 이미 있는 프로젝트면 그대로 두면 됩니다.)
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 1. messages — 회의실 대화
-- ------------------------------------------------------------
create table if not exists public.messages (
  id          uuid primary key default gen_random_uuid(),
  room        text not null default '지휘실'
              check (room in ('대회의실', '지휘실', '라운지')),
  sender      text not null,                       -- '대원' 또는 '피클'·'큐'·'키링'·'뮤즈'·'Instinct'·'pally'
  body        text not null check (length(trim(body)) > 0),
  created_at  timestamptz not null default now()
);

create index if not exists messages_room_created_idx
  on public.messages (room, created_at desc);

-- ------------------------------------------------------------
-- 2. tasks — 작업실
-- ------------------------------------------------------------
create table if not exists public.tasks (
  id          uuid primary key default gen_random_uuid(),
  title       text not null check (length(trim(title)) > 0),
  detail      text not null default '',
  status      text not null default '대기'
              check (status in ('대기', '실행중', '완료')),
  assignee    text not null default '피클',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists tasks_created_idx on public.tasks (created_at desc);
create index if not exists tasks_status_idx  on public.tasks (status);

-- ------------------------------------------------------------
-- 3. agent_status — 비서현황 (하트비트 포함)
-- ------------------------------------------------------------
create table if not exists public.agent_status (
  id            text primary key,                  -- '피클' / '큐' / '키링' / '뮤즈' / 'Instinct' / 'pally'
  name          text not null,
  emoji         text not null default '🤖',
  role          text not null default '비서',
  status        text not null default '대기중'
                check (status in ('대기중', '작업중', '오프라인')),
  current_task  text not null default '',
  last_seen     timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 4. notes — 공용 메모
-- ------------------------------------------------------------
create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  title       text not null default '새 메모',
  body        text not null default '',
  updated_by  text not null default '대원',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists notes_created_idx on public.notes (created_at asc);

-- ------------------------------------------------------------
-- 5. updated_at 자동 갱신
-- ------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tasks_touch_updated_at on public.tasks;
create trigger tasks_touch_updated_at
  before update on public.tasks
  for each row execute function public.touch_updated_at();

drop trigger if exists notes_touch_updated_at on public.notes;
create trigger notes_touch_updated_at
  before update on public.notes
  for each row execute function public.touch_updated_at();

-- ------------------------------------------------------------
-- 6. RLS — 개인용 방이라 anon key로 읽고 쓰도록 열어 둡니다.
--    * anon key는 웹페이지에 공개되는 키입니다.
--    * 따라서 이 페이지 주소를 아는 사람은 누구나 읽고 쓸 수 있어요.
--      → 주소는 아는 사람에게만 공유하세요.
--    * 더 잠그고 싶다면 아래 '선택: 방 비밀번호' 주석을 참고하세요.
-- ------------------------------------------------------------
alter table public.messages     enable row level security;
alter table public.tasks        enable row level security;
alter table public.agent_status enable row level security;
alter table public.notes        enable row level security;

drop policy if exists "room anon all messages" on public.messages;
create policy "room anon all messages" on public.messages
  for all to anon, authenticated
  using (true) with check (true);

drop policy if exists "room anon all tasks" on public.tasks;
create policy "room anon all tasks" on public.tasks
  for all to anon, authenticated
  using (true) with check (true);

drop policy if exists "room anon all agent_status" on public.agent_status;
create policy "room anon all agent_status" on public.agent_status
  for all to anon, authenticated
  using (true) with check (true);

drop policy if exists "room anon all notes" on public.notes;
create policy "room anon all notes" on public.notes
  for all to anon, authenticated
  using (true) with check (true);

-- ------------------------------------------------------------
-- 7. Realtime — 새 메시지·작업·상태·메모를 브라우저로 즉시 전송
-- ------------------------------------------------------------
alter table public.messages     replica identity full;
alter table public.tasks        replica identity full;
alter table public.agent_status replica identity full;
alter table public.notes        replica identity full;

do $$
declare
  t text;
begin
  foreach t in array array['messages', 'tasks', 'agent_status', 'notes']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------
-- 8. 시드 — 비서 6명 + 첫 안내 메시지
-- ------------------------------------------------------------
insert into public.agent_status (id, name, emoji, role, status, current_task, last_seen)
values
  ('피클', '피클', '🥒', '총괄 비서',        '대기중', '비서실 문을 열 준비 중', now()),
  ('큐',   '큐',   '🔵', '일정·리서치 비서', '대기중', '',                     now()),
  ('키링', '키링', '🔑', '보안·계정 비서',   '대기중', '',                     now()),
  ('뮤즈', '뮤즈', '✨', '콘텐츠·창작 비서', '대기중', '',                     now()),
  ('Instinct', 'Instinct', '⚡', '전략·직관 비서', '대기중', '',                     now()),
  ('pally', 'pally', '🤝', '소통·서포트 비서', '대기중', '',                     now())
on conflict (id) do nothing;

insert into public.messages (room, sender, body)
select '지휘실', '피클',
       '대장님, 비서실이 문을 열었습니다. 작업 지시는 여기 지휘실에서 @이름으로 불러 주세요. 시작 전에 "실행하겠습니다" 먼저 보고드리겠습니다. 🥒'
where not exists (select 1 from public.messages);

insert into public.notes (title, body, updated_by)
select '비서실 운영 규칙',
       '1. 작업 지시를 받으면 시작 전에 "실행하겠습니다"라고 먼저 보고한다.' || chr(10) ||
       '2. 보고는 짧게, 결과는 작업실에 남긴다.' || chr(10) ||
       '3. 대장님 호칭은 "대장님"으로 통일한다.',
       '피클'
where not exists (select 1 from public.notes where title = '비서실 운영 규칙');

-- ------------------------------------------------------------
-- 선택: 방 비밀번호(room secret)로 더 잠그고 싶을 때
--   테이블에 room_key 컬럼을 두고, 클라이언트가 보낸 값과 비교하는
--   RPC를 만들어 쓰는 방식이 가장 간단합니다. 예)
--
--   alter table public.messages add column if not exists room_key text;
--   create or replace function public.post_message(p_key text, p_room text, p_sender text, p_body text)
--   returns void language plpgsql security definer as $$
--   begin
--     if p_key <> '여기에-비밀문구' then raise exception 'invalid room key'; end if;
--     insert into public.messages(room, sender, body) values (p_room, p_sender, p_body);
--   end $$;
--
--   그리고 웹앱은 supabase.rpc('post_message', {...})로 전송합니다.
--   (읽기까지 막으려면 RLS 정책을 select/insert 별로 나누고 RPC 경유로 바꿔야 합니다.)
-- ------------------------------------------------------------

-- 확인용
-- select * from public.agent_status order by id;
-- select * from public.messages order by created_at desc limit 20;

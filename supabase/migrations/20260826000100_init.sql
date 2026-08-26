-- ============================================================================
--  Articket 서버 스키마 — 이 파일 전체를 Supabase SQL Editor 에 붙여넣고 Run
--
--  (supabase CLI 를 쓴다면 supabase/migrations/20260826000100_init.sql 로 저장 후
--   `supabase db push`)
--
--  설계 원칙 세 줄:
--   1. 로컬이 여전히 읽기 경로입니다. 이 DB 는 백업·동기화·전시 마스터용이고,
--      화면은 여기를 직접 읽지 않습니다.
--   2. 컬럼은 서버가 물어봐야 하는 것만 승격합니다. 나머지는 payload jsonb 에
--      그대로 둡니다. Ticket.toJson() 을 그대로 쓸 수 있습니다.
--   3. 감상문(note)은 컬럼으로 올리지 않습니다. payload 안에만 둡니다.
--      공개 뷰를 짜다 실수로 섞여 나가는 사고를 구조로 막습니다.
-- ============================================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;   -- 전시명 자동완성 (한국어는 tsvector 보다 trigram)


-- ── 공통 트리거: updated_at 은 항상 서버 시계 ──────────────────────────────
--
-- 기기 시계를 믿으면 안 됩니다. 시계가 하루 빠른 폰이 한 번 올리면, 그 뒤로
-- 다른 기기가 뭘 고쳐도 "더 오래된 것"이 되어 영원히 덮이지 않습니다.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;


-- ============================================================================
--  1. 프로필 · 회원 번호
--
--  지금 앱의 `memberSerial(since: joinedYear, no: joinedYear.hashCode % 9000 + 1)`
--  은 정수 해시라 **2025년에 시작한 모든 사용자가 같은 번호**를 받습니다.
--  그리고 첫 티켓을 지우면 joinedYear 가 바뀌어 번호도 바뀝니다.
--  회원 번호는 바뀌면 안 되는 값이므로 서버가 발급합니다.
-- ============================================================================

create table public.member_counters (
  year     int primary key,
  last_no  int not null default 0
);

create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  name         text not null default '이름 없음',
  joined_at    timestamptz not null default now(),
  member_year  int  not null,
  member_no    int  not null,
  plan         text not null default 'basic' check (plan in ('basic','pro')),
  updated_at   timestamptz not null default now(),
  unique (member_year, member_no)
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  y int := extract(year from now())::int;
  n int;
begin
  insert into public.member_counters (year, last_no) values (y, 1)
    on conflict (year) do update set last_no = member_counters.last_no + 1
    returning last_no into n;

  insert into public.profiles (id, name, member_year, member_no)
  values (new.id,
          coalesce(nullif(new.raw_user_meta_data->>'name',''), '이름 없음'),
          y, n);

  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();


-- ============================================================================
--  2. 전시 마스터 (README "0. 먼저 해야 하는 것")
--
--  지금 안 만들면 나중에 못 만듭니다. 채우는 건 나중에 하더라도
--  tickets.exhibition_id 자리를 **nullable 로 지금** 뚫어두는 게 목적입니다.
-- ============================================================================

create table public.venues (
  id         uuid primary key default gen_random_uuid(),
  name_ko    text not null,
  name_en    text,
  city       text,
  lat        double precision,
  lng        double precision,
  created_at timestamptz not null default now()
);

create table public.exhibitions (
  id          uuid primary key default gen_random_uuid(),
  title_ko    text not null,
  title_en    text,
  venue_id    uuid references public.venues(id) on delete set null,
  start_at    date,
  end_at      date,
  poster_url  text,
  status      text not null default 'published'
              check (status in ('draft','published','merged')),
  -- 중복 등록은 지우지 않고 합칩니다. 이미 이 id 를 물고 있는 티켓이 있으니까요.
  merged_into uuid references public.exhibitions(id) on delete set null,
  created_at  timestamptz not null default now()
);

create index exhibitions_title_trgm on public.exhibitions using gin (title_ko gin_trgm_ops);
create index venues_name_trgm       on public.venues      using gin (name_ko  gin_trgm_ops);

-- 목록에 없는 소규모 갤러리를 적으려던 사용자가 그 자리에서 이탈하지 않도록
-- 자유 입력은 살려두고 여기로 쌓습니다. 매칭은 나중에 사람이 합니다.
create table public.exhibition_suggestions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete set null,
  raw_title  text not null,
  raw_venue  text,
  visited_at date,
  resolved   uuid references public.exhibitions(id) on delete set null,
  created_at timestamptz not null default now()
);


-- ============================================================================
--  3. 서류철 · 티켓
-- ============================================================================

create table public.folders (
  id         uuid primary key,                    -- 앱이 만든 uuid 를 그대로
  user_id    uuid not null references auth.users(id) on delete cascade,
  label      text not null default '',
  subtitle   text not null default '',
  sort_index int  not null default 0,
  payload    jsonb not null default '{}'::jsonb,  -- ArchiveFolder.toJson() 나머지
  updated_at timestamptz not null default now(),
  deleted_at timestamptz                          -- 묘비. 행을 지우지 않습니다
);

create table public.tickets (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,

  -- folder_id 에 외래키를 **일부러 걸지 않습니다.**
  -- 동기화 순서를 보장할 수 없습니다. 오프라인에서 서류철과 티켓을 같이 만든
  -- 기기가 티켓을 먼저 올리면, FK 가 있으면 그 티켓은 영영 못 올라갑니다.
  folder_id     uuid,

  exhibition_id uuid references public.exhibitions(id) on delete set null,

  title         text not null default '',
  venue         text not null default '',
  visited_at    date not null,
  issued_year   int  not null default 0,
  issued_seq    int  not null default 0,
  genre         text not null default '미술',
  rating        int  not null default 0 check (rating between 0 and 5),
  one_liner     text not null default '',
  is_public     boolean not null default false,   -- 기본값은 비공개. 약속입니다
  poster_key    text,                             -- storage 경로. 로컬 경로 아님

  payload       jsonb not null default '{}'::jsonb,  -- note·layers·tint·frame·배치
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

-- 같은 사람이 같은 번호를 두 장 갖는 일을 DB 가 막습니다.
-- 미발권(0-0)은 여러 장일 수 있으므로 반드시 부분 인덱스여야 합니다.
create unique index tickets_serial_uniq
  on public.tickets (user_id, issued_year, issued_seq)
  where issued_year > 0;

create index folders_pull_idx on public.folders (user_id, updated_at);
create index tickets_pull_idx on public.tickets (user_id, updated_at);
create index tickets_public_idx on public.tickets (exhibition_id)
  where is_public and deleted_at is null;

create trigger folders_touch before update on public.folders
  for each row execute function public.touch_updated_at();
create trigger tickets_touch before update on public.tickets
  for each row execute function public.touch_updated_at();


-- ============================================================================
--  4. 발권 — 번호를 서버가 뽑습니다
--
--  현재 규칙이 자기모순입니다.
--    · "번호는 add() 에서 한 번 찍히고 다시는 바뀌지 않는다"
--    · "순번은 그 해의 최고값 + 1"   ← 최고값 = **그 기기가 아는** 최고값
--
--  폰과 태블릿이 둘 다 비행기 모드에서 2026년 티켓을 만들면 둘 다
--  AK-2026-005 를 찍습니다. 첫 규칙 때문에 나중에 밀어줄 수도 없습니다.
--
--  해법: 번호는 여기서 뽑습니다. 네트워크가 없으면 **찍지 않습니다.**
--  모델에 이미 kUnissuedSerial('AK-0000-000') 과 isIssued 가 있습니다.
--  실물도 그렇습니다 — 예매는 지금, 표는 창구에서.
-- ============================================================================

create table public.ticket_counters (
  user_id  uuid not null references auth.users(id) on delete cascade,
  year     int  not null,
  last_seq int  not null default 0,
  primary key (user_id, year)
);

alter table public.ticket_counters enable row level security;
-- 정책을 만들지 않습니다. 아래 RPC(security definer)로만 닿습니다.
-- 클라이언트가 last_seq 를 직접 쓰면 번호 규칙이 무너집니다.

create or replace function public.issue_ticket_serial(p_year int)
returns int language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_year < 1900 or p_year > 2200 then raise exception 'bad year'; end if;

  insert into public.ticket_counters (user_id, year, last_seq)
    values (auth.uid(), p_year, 1)
    on conflict (user_id, year)
      do update set last_seq = ticket_counters.last_seq + 1
    returning last_seq into n;

  return n;
end $$;

-- 기존 기기에서 이미 찍혀 올라온 번호가 카운터보다 높을 수 있습니다.
-- 첫 동기화 때 한 번 끌어올립니다(앱이 부릅니다).
create or replace function public.raise_ticket_counter(p_year int, p_seq int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  insert into public.ticket_counters (user_id, year, last_seq)
    values (auth.uid(), p_year, greatest(p_seq, 0))
    on conflict (user_id, year)
      do update set last_seq = greatest(ticket_counters.last_seq, excluded.last_seq);
end $$;


-- ============================================================================
--  5. RLS  ★ 하나라도 빠뜨리면 그 테이블은 인터넷 전체에 열려 있습니다
-- ============================================================================

alter table public.profiles               enable row level security;
alter table public.folders                enable row level security;
alter table public.tickets                enable row level security;
alter table public.exhibitions            enable row level security;
alter table public.venues                 enable row level security;
alter table public.exhibition_suggestions enable row level security;
alter table public.member_counters        enable row level security;  -- 정책 없음 = 아무도 못 봄

create policy profiles_self on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy folders_owner on public.folders
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy tickets_owner on public.tickets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 전시 마스터는 누구나 읽습니다. 쓰기는 관리자(service_role)만.
create policy exhibitions_read on public.exhibitions for select using (true);
create policy venues_read      on public.venues      for select using (true);

create policy suggest_insert on public.exhibition_suggestions
  for insert with check (auth.uid() = user_id);
create policy suggest_read on public.exhibition_suggestions
  for select using (auth.uid() = user_id);


-- ============================================================================
--  6. 공개 뷰 — 전시 페이지에 걸리는 티켓 (README 1번, 화면은 아직 없음)
--
--  ⚠ security_invoker 를 켜지 않습니다(= 소유자 권한으로 돌아 RLS 를 통과).
--    남의 공개 티켓을 보여주려면 그래야 하고, **그게 의도입니다.**
--    대신 컬럼을 하나하나 적습니다. `select t.*` 로 바꾸는 순간
--    감상문(note)과 동행인이 인터넷에 공개됩니다. payload 통째로 내보내지 마세요.
-- ============================================================================

create view public.public_tickets as
select
  t.id,
  t.exhibition_id,
  t.title,
  t.venue,
  t.visited_at,
  t.rating,
  t.one_liner,
  t.poster_key,
  t.payload -> 'posterTint' as poster_tint,
  t.payload ->> 'frame'     as frame,
  t.payload ->> 'layers'    as layers,
  p.name        as author_name,
  p.member_year as author_member_year,
  p.member_no   as author_member_no
from public.tickets t
join public.profiles p on p.id = t.user_id
where t.is_public and t.deleted_at is null;

grant select on public.public_tickets to anon, authenticated;


-- ============================================================================
--  7. 포스터 사진 스토리지
--
--  비공개 버킷 하나로 시작합니다. 경로는 `{uid}/{ticketId}.jpg`.
--  공개 썸네일은 나중에 별도 버킷 + 서버 리사이즈로 나눕니다. 원본을 공개
--  버킷에 넣으면 사용자가 실수로 올린 개인 사진이 URL 만 알면 열립니다.
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('posters', 'posters', false, 8 * 1024 * 1024,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

create policy posters_read on storage.objects for select
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy posters_write on storage.objects for insert
  with check (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy posters_update on storage.objects for update
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
create policy posters_delete on storage.objects for delete
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = auth.uid()::text);
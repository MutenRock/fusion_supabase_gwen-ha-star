-- Merge imported player economy/progression into the final players table.
-- Preconditions:
-- - docs/migrations/supabase/sql/001_create_old_import_tables.sql has run.
-- - The raw CSV files were imported into old_import.
-- - public.profiles has been verified against auth.users.
-- - A full Supabase backup exists.

update old_import.players
set username = trim(regexp_replace(username, E'[\\r\\n]+', '', 'g'))
where username is not null;

update old_import.profiles
set username = trim(regexp_replace(username, E'[\\r\\n]+', '', 'g'))
where username is not null;

select p.*
from old_import.players p
left join old_import.profiles pr on pr.id = p.id
where pr.id is null;

select
  p.id,
  p.username as player_username,
  pr.username as profile_username
from old_import.players p
join old_import.profiles pr on pr.id = p.id
where p.username is distinct from pr.username;

create table if not exists public.players (
  id uuid primary key references public.profiles(id) on delete cascade,
  username text,
  legacy_username text,
  gold bigint not null default 0,
  pack_count integer not null default 0,
  cards_qty integer not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.players
add column if not exists legacy_username text;

create table if not exists public.backup_players_before_merge as
select * from public.players;

insert into public.players (
  id,
  username,
  legacy_username,
  gold,
  pack_count,
  cards_qty,
  created_at,
  updated_at
)
select
  p.id,
  pr.username as username,
  p.username as legacy_username,
  coalesce(p.gold, 0),
  coalesce(p.pack_count, 0),
  coalesce(p.cards_qty, 0),
  coalesce(p.created_at, now()),
  coalesce(p.updated_at, now())
from old_import.players p
join public.profiles pr on pr.id = p.id
on conflict (id)
do update set
  username = excluded.username,
  legacy_username = excluded.legacy_username,
  gold = greatest(public.players.gold, excluded.gold),
  pack_count = greatest(public.players.pack_count, excluded.pack_count),
  cards_qty = greatest(public.players.cards_qty, excluded.cards_qty),
  updated_at = greatest(public.players.updated_at, excluded.updated_at);

insert into public.players (
  id,
  username,
  legacy_username,
  gold,
  pack_count,
  cards_qty,
  created_at,
  updated_at
)
select
  pr.id,
  pr.username,
  null,
  0,
  0,
  0,
  coalesce(pr.created_at, now()),
  now()
from public.profiles pr
left join public.players p on p.id = pr.id
where p.id is null;

select p.*
from public.players p
left join public.profiles pr on pr.id = p.id
where pr.id is null;

select pr.*
from public.profiles pr
left join public.players p on p.id = pr.id
where p.id is null;

select
  pr.username as profile_username,
  p.username as player_username,
  p.legacy_username,
  p.gold,
  p.pack_count,
  p.cards_qty,
  p.updated_at
from public.players p
join public.profiles pr on pr.id = p.id
order by p.gold desc;

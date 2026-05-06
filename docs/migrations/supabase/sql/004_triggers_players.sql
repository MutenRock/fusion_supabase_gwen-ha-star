-- Utility triggers for player rows.
-- No production database is changed until this SQL is run manually.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_players_updated_at on public.players;

create trigger set_players_updated_at
before update on public.players
for each row
execute function public.set_updated_at();

create or replace function public.handle_new_profile_player()
returns trigger
language plpgsql
as $$
begin
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
  values (
    new.id,
    new.username,
    null,
    0,
    0,
    0,
    now(),
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_profile_created_create_player on public.profiles;

create trigger on_profile_created_create_player
after insert on public.profiles
for each row
execute function public.handle_new_profile_player();

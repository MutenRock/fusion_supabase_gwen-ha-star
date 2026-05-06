-- Enable RLS for player progression rows.
-- Execute only after validating the migration with a real authenticated account.

alter table public.players enable row level security;

drop policy if exists "Players can read own player row" on public.players;
drop policy if exists "Players can insert own player row" on public.players;
drop policy if exists "Players can update own player row" on public.players;

create policy "Players can read own player row"
on public.players
for select
using (auth.uid() = id);

create policy "Players can insert own player row"
on public.players
for insert
with check (auth.uid() = id);

create policy "Players can update own player row"
on public.players
for update
using (auth.uid() = id)
with check (auth.uid() = id);

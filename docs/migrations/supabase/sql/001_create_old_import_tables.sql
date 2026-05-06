-- Creates a quarantine schema for old CSV exports.
-- Import docs/migrations/supabase/raw/profiles_rows.csv into old_import.profiles.
-- Import docs/migrations/supabase/raw/players_rows.csv into old_import.players.

create schema if not exists old_import;

create table if not exists old_import.profiles (
  id uuid primary key,
  username text,
  bio text,
  avatar_url text,
  created_at timestamptz,
  is_admin boolean
);

create table if not exists old_import.players (
  id uuid primary key,
  username text,
  gold bigint,
  pack_count integer,
  created_at timestamptz,
  updated_at timestamptz,
  cards_qty integer
);

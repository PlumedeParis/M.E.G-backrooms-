-- M.E.G. — Mode Online Play — schéma Supabase
-- À exécuter dans Supabase Studio > SQL Editor.
-- Prérequis : activer "Anonymous Sign-Ins" dans Authentication > Providers.
--
-- IMPORTANT si vous aviez déjà exécuté une version précédente de ce fichier :
-- le salon multijoueur fonctionne maintenant par CODE (colonne mp_rooms.code).
-- Ré-exécutez tout ce script une fois — il est idempotent (create/alter ... if
-- not exists, drop policy if exists) donc sans risque sur les données existantes.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- Salons (lobbies)
-- ---------------------------------------------------------------------
create table if not exists mp_rooms (
  id uuid primary key default gen_random_uuid(),
  code text,
  seed bigint,
  leader_id uuid not null,
  leader_pseudo text not null,
  level_id text,
  status text not null default 'lobby' check (status in ('lobby','starting','in_game','ended')),
  created_at timestamptz not null default now()
);
-- Migration : si la table mp_rooms existait déjà (version précédente sans salon
-- par code), ajoute les colonnes manquantes — sans effet si elles existent déjà.
alter table mp_rooms add column if not exists code text;
-- seed : graine aléatoire partagée, tirée par le chef d'équipe au lancement, pour que
-- tous les coéquipiers génèrent EXACTEMENT le même niveau (mêmes murs, même décor) —
-- avant ça, chaque joueur tirait son propre labyrinthe au hasard de son côté.
alter table mp_rooms add column if not exists seed bigint;
create unique index if not exists mp_rooms_code_idx on mp_rooms(code);
alter table mp_rooms replica identity full;
alter table mp_rooms enable row level security;

drop policy if exists "rooms select all" on mp_rooms;
create policy "rooms select all" on mp_rooms for select using (true);

drop policy if exists "rooms insert own" on mp_rooms;
create policy "rooms insert own" on mp_rooms for insert with check (auth.uid() = leader_id);

drop policy if exists "rooms update own" on mp_rooms;
create policy "rooms update own" on mp_rooms for update using (auth.uid() = leader_id) with check (auth.uid() = leader_id);

drop policy if exists "rooms delete own" on mp_rooms;
create policy "rooms delete own" on mp_rooms for delete using (auth.uid() = leader_id);

-- ---------------------------------------------------------------------
-- Membres d'un salon (1 à 4 par salon, y compris le chef d'équipe)
-- ---------------------------------------------------------------------
create table if not exists mp_room_members (
  room_id uuid not null references mp_rooms(id) on delete cascade,
  user_id uuid not null,
  pseudo text not null,
  level int not null default 1,
  ready boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);
alter table mp_room_members replica identity full;
alter table mp_room_members enable row level security;

drop policy if exists "members select all" on mp_room_members;
create policy "members select all" on mp_room_members for select using (true);

drop policy if exists "members insert own" on mp_room_members;
create policy "members insert own" on mp_room_members for insert with check (auth.uid() = user_id);

drop policy if exists "members update own" on mp_room_members;
create policy "members update own" on mp_room_members for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "members delete own or leader" on mp_room_members;
create policy "members delete own or leader" on mp_room_members for delete
  using (auth.uid() = user_id or auth.uid() = (select leader_id from mp_rooms where id = room_id));

-- Empêche de dépasser 4 joueurs par salon (1 chef + 3 invités max)
create or replace function mp_check_room_capacity() returns trigger as $$
begin
  if (select count(*) from mp_room_members where room_id = new.room_id) >= 4 then
    raise exception 'Room is full';
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists mp_room_capacity_trigger on mp_room_members;
create trigger mp_room_capacity_trigger
  before insert on mp_room_members
  for each row execute function mp_check_room_capacity();

-- ---------------------------------------------------------------------
-- Realtime : diffuse les changements de mp_rooms / mp_room_members
-- (vérifie l'appartenance avant d'ajouter, sinon "alter publication ...
-- add table" échoue si la table y est déjà — ce qui annulerait le reste
-- du script lors d'une ré-exécution)
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='mp_rooms'
  ) then
    alter publication supabase_realtime add table mp_rooms;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='mp_room_members'
  ) then
    alter publication supabase_realtime add table mp_room_members;
  end if;
end $$;

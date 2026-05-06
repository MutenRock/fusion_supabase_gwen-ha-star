# Migration Supabase — Fusion de deux bases Pokegang / Sterenna

_Date de génération : 2026-05-06 00:19 UTC_

## 1. Objectif

Tu as actuellement deux projets / bases Supabase :

- une ancienne base, utilisée par des joueurs/utilisateurs ;
- une nouvelle base, plus propre, que tu veux garder comme base principale.

L’objectif est de **fusionner les données utiles de l’ancienne base vers la nouvelle**, sans que les joueurs perdent leurs informations : profil, progression, argent, cartes, sauvegardes ou autres données liées au compte.

La stratégie recommandée est :

```txt
Ancienne base Supabase
        ↓ export
Fichiers CSV / SQL de migration
        ↓ import temporaire
Schéma old_import dans la nouvelle base
        ↓ nettoyage + mapping
Tables finales de la nouvelle base
        ↓ vérification
Application branchée uniquement sur la nouvelle base
```

Le principe important : **la nouvelle base reste la base officielle**, et l’ancienne base devient seulement une source d’import.

---

## 2. Fichiers analysés

Tu as fourni 3 fichiers CSV :

| Fichier | Rôle supposé | Nombre de lignes | Colonnes |
|---|---:|---:|---|
| `players_rows.csv` | Données joueur / progression | 8 | `id, username, gold, pack_count, created_at, updated_at, cards_qty` |
| `profiles_rows.csv` | Profils utilisateurs | 10 | `id, username, bio, avatar_url, created_at, is_admin` |
| `profiles_rows (1).csv` | Doublon probable de profiles | 10 | `id, username, bio, avatar_url, created_at, is_admin` |

Résultat important :

```txt
profiles_rows.csv et profiles_rows (1).csv sont identiques : True
```

Donc pour la migration, on peut considérer qu’il n’y a que deux exports utiles :

```txt
players_rows.csv
profiles_rows.csv
```

---

## 3. Résumé du diagnostic

### 3.1 Volumétrie

| Élément | Nombre |
|---|---:|
| Profils dans `profiles` | 10 |
| Joueurs dans `players` | 8 |
| Players sans profil correspondant | 0 |
| Profils sans ligne player | 2 |
| Différences de pseudo entre `players` et `profiles` | 1 |

Conclusion :

```txt
La migration est saine côté IDs :
- aucun player orphelin ;
- tous les players ont un profil correspondant ;
- seulement 2 profils n’ont pas encore de ligne player.
```

---

## 4. Structure observée des tables

### 4.1 Table `profiles`

Colonnes observées :

| Colonne | Rôle probable |
|---|---|
| `id` | UUID utilisateur, probablement lié à `auth.users.id` |
| `username` | Pseudo public / nom affiché |
| `bio` | Bio du profil |
| `avatar_url` | URL d’avatar |
| `created_at` | Date de création du profil |
| `is_admin` | Flag admin |

Exemple de rôle logique :

```txt
profiles = identité publique / informations de compte visibles
```

---

### 4.2 Table `players`

Colonnes observées :

| Colonne | Rôle probable |
|---|---|
| `id` | UUID du joueur, probablement identique à `profiles.id` |
| `username` | Ancien pseudo stocké côté player |
| `gold` | Monnaie / argent du joueur |
| `pack_count` | Nombre de packs disponibles ou ouverts selon ton code |
| `created_at` | Création de la ligne player |
| `updated_at` | Dernière mise à jour player |
| `cards_qty` | Quantité totale de cartes possédées |

Rôle logique recommandé :

```txt
players = progression / économie / état joueur
```

---

## 5. Relation entre `profiles` et `players`

Dans tes données actuelles :

```txt
players.id = profiles.id
```

C’est très probablement une relation 1:1 :

```sql
public.players.id references public.profiles(id)
```

ou directement :

```sql
public.players.id references auth.users(id)
```

La version que je recommande :

```sql
public.profiles.id references auth.users(id)
public.players.id references public.profiles(id)
```

Schéma logique :

```txt
auth.users
    ↓ id
profiles
    ↓ id
players
```

---

## 6. Analyse détaillée des correspondances

### 6.1 Players avec profil correspondant

| id                                   | username_player   | username_clean   | username_profile               |    gold |   cards_qty |
|:-------------------------------------|:------------------|:-----------------|:-------------------------------|--------:|------------:|
| 02e7b9d6-dcba-490f-98e3-83f13fa930fc | Conrad_OG         | Conrad_OG        | Conrad_OG                      |   49869 |         109 |
| 5ff95460-c65f-4dce-9de3-8b118df2491a | Laizid            | Laizid           | New Mega Super (Puissant) Mart |     150 |          75 |
| 6a95a536-1d50-449e-8e94-0007beafc0ff | Sniky             | Sniky            | Sniky                          |   44565 |         174 |
| ab318f3b-7d4a-4783-97c6-a3dffbb91e76 | Aligax            | Aligax           | Aligax                         | 1608329 |         122 |
| b89a2ef6-df42-45a9-b617-6d5003f5929c | Muten_01          | Muten_01         | Muten_01                       |       5 |          19 |
| be10a18e-b332-46e1-a933-0f1fb010a36d | gabilone          | gabilone         | gabilone                       |   42575 |         267 |
| c496aac4-7ed3-4173-9666-a4f30098cac7 | MutenRock         | MutenRock        | MutenRock                      |  672171 |         711 |
| fb8047f4-a700-4ef8-9ced-f14e6e2836bb | SoRn              | SoRn             | SoRn                           | 1567267 |          94 |

---

### 6.2 Profils sans ligne `players`

Ces profils existent, mais n’ont pas encore de données de progression dans `players`.

| id                                   | username      | created_at                    | is_admin   |
|:-------------------------------------|:--------------|:------------------------------|:-----------|
| 137cd5e0-eb03-43d3-8b24-71e7cc06d51c | voyageur_AAA4 | 2025-11-10 08:26:29.069821+00 | False      |
| 3b84515b-fbf3-40c4-80e0-6c4cdc61e43c | voyageur_B4EB | 2025-10-11 23:52:29.918716+00 | False      |

Interprétation probable :

- comptes créés mais pas encore initialisés côté jeu ;
- visiteurs / comptes test ;
- profils créés après la période de l’ancienne base ;
- ou migration incomplète si ces utilisateurs avaient bien une progression ailleurs.

Action recommandée :

```txt
Créer une ligne players vide pour eux, avec gold = 0, cards_qty = 0, pack_count = 0.
```

---

### 6.3 Players orphelins

Un player orphelin serait une ligne `players` dont le `id` ne correspond à aucun profil.

Résultat actuel :

_Aucune ligne._

Conclusion :

```txt
Aucun player orphelin dans les CSV fournis.
```

C’est très bon signe.

---

## 7. Problèmes de pseudo détectés

Il y a quelques différences entre `players.username` et `profiles.username`.

| id                                   | username_player   | username_clean   | username_profile               |
|:-------------------------------------|:------------------|:-----------------|:-------------------------------|
| 5ff95460-c65f-4dce-9de3-8b118df2491a | Laizid            | Laizid           | New Mega Super (Puissant) Mart |

### 7.1 Cas simples : retours ligne

Les cas suivants contiennent des caractères parasites :

```txt
Aligax\r\n → Aligax
gabilone\r\n → gabilone
```

Correction recommandée :

```sql
trim(regexp_replace(username, '[\r\n]+', '', 'g'))
```

---

### 7.2 Cas à décider manuellement

```txt
players.username  = Laizid
profiles.username = New Mega Super (Puissant) Mart
```

Ici, il ne s’agit pas seulement d’un nettoyage.

Décision recommandée :

```txt
Garder profiles.username comme pseudo public actuel.
```

Pourquoi ?

- `profiles` semble être la table officielle d’identité publique ;
- `players.username` semble redondant ;
- un joueur peut avoir modifié son pseudo après la création de sa ligne player.

Alternative possible :

```txt
Conserver players.username dans une colonne legacy_username.
```

Exemple :

```sql
alter table public.players
add column if not exists legacy_username text;
```

---

## 8. Statistiques rapides sur les joueurs

### 8.1 Gold

| Statistique | Valeur |
|---|---:|
| Minimum | 5 |
| Maximum | 1608329 |
| Moyenne | 498116.38 |
| Médiane | 47217.0 |

### 8.2 Cartes

| Statistique | Valeur |
|---|---:|
| Minimum | 19 |
| Maximum | 711 |
| Moyenne | 196.38 |
| Médiane | 115.5 |

### 8.3 Points à surveiller

Certains joueurs ont beaucoup plus d’or que les autres :

```txt
Aligax : 1 608 329 gold
SoRn : 1 567 267 gold
MutenRock : 672 171 gold
```

Ce n’est pas forcément un problème, mais avant une fusion définitive, vérifie si ces valeurs sont :

- normales ;
- issues d’une ancienne version très généreuse ;
- des comptes admin/test ;
- ou des valeurs à plafonner / convertir.

---

## 9. Architecture recommandée après fusion

Je déconseille de mettre toute la progression dans `profiles`.

Version recommandée :

```txt
profiles = identité publique
players = progression principale
player_saves = sauvegardes complètes si ton jeu en utilise
leaderboard = scores / classements
save_snapshots = historique de sauvegardes
profile_titles = titres débloqués
```

Donc :

```txt
auth.users
    ↓
profiles
    ↓
players
    ↓
autres tables liées
```

---

## 10. Pourquoi ne pas tout mettre dans `profiles`

Même si c’est tentant, éviter de transformer `profiles` en grosse table fourre-tout.

Mauvais modèle à long terme :

```txt
profiles
- username
- bio
- avatar
- gold
- cards
- inventory
- saves
- leaderboard
- settings
- titles
```

Meilleur modèle :

```txt
profiles
- id
- username
- bio
- avatar_url
- is_admin

players
- id
- gold
- pack_count
- cards_qty
- updated_at

player_saves
- user_id
- slot
- save_data
- updated_at

leaderboard
- user_id
- reputation
- total_caught
- shiny_count
```

Avantages :

- plus propre ;
- plus évolutif ;
- plus simple à sécuriser avec RLS ;
- plus facile à debug ;
- plus facile à migrer plus tard.

---

## 11. Point critique : Supabase Auth

Les CSV ne contiennent pas la table Supabase Auth.

Donc le point à vérifier absolument est :

```txt
Est-ce que profiles.id correspond bien à auth.users.id dans la nouvelle base ?
```

Tu peux vérifier avec cette requête dans la nouvelle base :

```sql
select
  p.id,
  p.username,
  u.email,
  u.created_at as auth_created_at
from public.profiles p
left join auth.users u on u.id = p.id
order by p.created_at desc;
```

Si certains profils n’ont pas de `auth.users` correspondant :

```sql
select
  p.id,
  p.username
from public.profiles p
left join auth.users u on u.id = p.id
where u.id is null;
```

### Si résultat = 0 ligne

Très bon signe. Les profils sont bien liés à Supabase Auth.

### Si résultat > 0 ligne

Attention : certains profils ne correspondent à aucun compte Auth.  
Il faudra créer un mapping ou corriger l’import.

---

## 12. Stratégie de migration recommandée

### Phase 1 — Backup

Avant toute modification :

```txt
1. Exporter l’ancienne base.
2. Exporter la nouvelle base.
3. Télécharger les CSV actuels.
4. Noter les URLs Supabase, project ref, branches, clés anon/service.
```

À ne jamais faire directement sans backup :

```sql
delete from public.players;
truncate public.profiles;
restore ancien dump par-dessus la nouvelle base;
```

---

### Phase 2 — Préparer un schéma temporaire

Dans la nouvelle base :

```sql
create schema if not exists old_import;
```

Ce schéma sert de zone de quarantaine.

Objectif :

```txt
Importer les anciennes données sans toucher aux tables finales.
```

---

### Phase 3 — Importer les CSV dans `old_import`

Créer les tables temporaires :

```sql
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
```

Ensuite importer :

```txt
profiles_rows.csv → old_import.profiles
players_rows.csv  → old_import.players
```

Via Supabase :

```txt
Table Editor
→ old_import.profiles
→ Import CSV

Table Editor
→ old_import.players
→ Import CSV
```

---

### Phase 4 — Nettoyer les données importées

Nettoyage des pseudos :

```sql
update old_import.players
set username = trim(regexp_replace(username, '[
]+', '', 'g'));

update old_import.profiles
set username = trim(regexp_replace(username, '[
]+', '', 'g'));
```

Vérification :

```sql
select * from old_import.players
where username ~ '[
]';

select * from old_import.profiles
where username ~ '[
]';
```

---

### Phase 5 — Vérifier les relations

Players sans profil :

```sql
select p.*
from old_import.players p
left join public.profiles pr on pr.id = p.id
where pr.id is null;
```

Profils sans player :

```sql
select pr.*
from public.profiles pr
left join old_import.players p on p.id = pr.id
where p.id is null;
```

Différences de pseudo :

```sql
select
  p.id,
  p.username as player_username,
  pr.username as profile_username
from old_import.players p
join public.profiles pr on pr.id = p.id
where p.username is distinct from pr.username;
```

---

## 13. Script SQL recommandé — Version propre avec table `players`

Cette version garde `profiles` pour l’identité et `players` pour la progression.

### 13.1 Créer ou vérifier la table `players`

```sql
create table if not exists public.players (
  id uuid primary key references public.profiles(id) on delete cascade,
  username text,
  gold bigint not null default 0,
  pack_count integer not null default 0,
  cards_qty integer not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

Si tu veux éviter de stocker deux fois le pseudo, tu peux supprimer `username` plus tard.  
Pour une migration, je recommande de le garder temporairement.

---

### 13.2 Ajouter une colonne legacy optionnelle

Utile pour garder l’ancien pseudo sans l’utiliser comme pseudo public :

```sql
alter table public.players
add column if not exists legacy_username text;
```

---

### 13.3 Importer / fusionner les players

Version prudente :

```sql
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
```

Pourquoi `greatest()` ?

```txt
Si un joueur a déjà progressé dans la nouvelle base,
on évite d’écraser sa progression avec une valeur plus ancienne.
```

Attention : cette logique est bonne pour des compteurs comme `gold` ou `cards_qty`, mais pas toujours pour des données complexes. Pour une vraie sauvegarde JSON, il vaut mieux comparer `updated_at`.

---

### 13.4 Créer une ligne player pour les profils sans player

```sql
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
```

---

## 14. Variante : fusionner les données `players` directement dans `profiles`

Je ne recommande pas cette option comme architecture finale, mais elle peut être utile pour une version très simple.

Ajouter les colonnes :

```sql
alter table public.profiles
add column if not exists gold bigint default 0,
add column if not exists pack_count integer default 0,
add column if not exists cards_qty integer default 0,
add column if not exists player_updated_at timestamptz;
```

Importer :

```sql
update public.profiles pr
set
  gold = coalesce(p.gold, 0),
  pack_count = coalesce(p.pack_count, 0),
  cards_qty = coalesce(p.cards_qty, 0),
  player_updated_at = p.updated_at
from old_import.players p
where pr.id = p.id;
```

Créer valeurs par défaut pour les profils sans player :

```sql
update public.profiles
set
  gold = coalesce(gold, 0),
  pack_count = coalesce(pack_count, 0),
  cards_qty = coalesce(cards_qty, 0),
  player_updated_at = coalesce(player_updated_at, now());
```

---

## 15. Requêtes de validation après migration

### 15.1 Nombre de lignes

```sql
select count(*) as profiles_count from public.profiles;
select count(*) as players_count from public.players;
```

Résultat attendu d’après les CSV :

```txt
profiles_count = 10
players_count >= 10 si tu crées les lignes vides
players_count = 8 si tu ne migres que les vrais players existants
```

---

### 15.2 Vérifier les players sans profil

```sql
select p.*
from public.players p
left join public.profiles pr on pr.id = p.id
where pr.id is null;
```

Résultat attendu :

```txt
0 ligne
```

---

### 15.3 Vérifier les profils sans player

```sql
select pr.*
from public.profiles pr
left join public.players p on p.id = pr.id
where p.id is null;
```

Résultat attendu :

```txt
0 ligne si tu as créé les lignes player par défaut.
```

---

### 15.4 Vérifier les montants migrés

```sql
select
  pr.username,
  p.gold,
  p.pack_count,
  p.cards_qty,
  p.updated_at
from public.players p
join public.profiles pr on pr.id = p.id
order by p.gold desc;
```

---

### 15.5 Vérifier les caractères parasites

```sql
select *
from public.players
where username ~ '[
]'
   or legacy_username ~ '[
]';
```

Résultat attendu :

```txt
0 ligne
```

---

## 16. RLS — Sécurité Supabase recommandée

Si `players` contient la progression d’un utilisateur, active RLS :

```sql
alter table public.players enable row level security;
```

### 16.1 Lecture par propriétaire

```sql
create policy "Players can read own player row"
on public.players
for select
using (auth.uid() = id);
```

### 16.2 Insertion par propriétaire

```sql
create policy "Players can insert own player row"
on public.players
for insert
with check (auth.uid() = id);
```

### 16.3 Update par propriétaire

```sql
create policy "Players can update own player row"
on public.players
for update
using (auth.uid() = id)
with check (auth.uid() = id);
```

### 16.4 Lecture publique partielle pour leaderboard

Si le leaderboard a besoin d’afficher certains champs, il vaut mieux créer une vue publique plutôt que d’ouvrir toute la table `players`.

Exemple :

```sql
create or replace view public.public_player_cards as
select
  pr.username,
  p.cards_qty,
  p.gold
from public.players p
join public.profiles pr on pr.id = p.id;
```

Puis attention : les vues et RLS doivent être testées selon ton modèle Supabase.

---

## 17. Triggers utiles

### 17.1 Mettre à jour `updated_at`

```sql
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
```

---

### 17.2 Créer automatiquement une ligne `players` à la création d’un profil

Si tu crées déjà les profils via trigger après inscription, tu peux ajouter une création player.

Exemple conceptuel :

```sql
create or replace function public.handle_new_profile_player()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.players (
    id,
    username,
    gold,
    pack_count,
    cards_qty,
    created_at,
    updated_at
  )
  values (
    new.id,
    new.username,
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
```

---

## 18. Risques principaux

### 18.1 Écraser une progression récente

Risque :

```txt
Un joueur a progressé dans la nouvelle base.
Tu importes une ancienne ligne moins récente.
Sa progression régresse.
```

Protection :

```sql
gold = greatest(public.players.gold, excluded.gold)
cards_qty = greatest(public.players.cards_qty, excluded.cards_qty)
```

Pour les sauvegardes JSON, il faut plutôt comparer `updated_at`.

---

### 18.2 Conflit entre ancien pseudo et nouveau pseudo

Risque :

```txt
players.username et profiles.username ne correspondent pas.
```

Protection :

```txt
profiles.username = source officielle
players.legacy_username = ancien pseudo conservé
```

---

### 18.3 IDs non liés à Auth

Risque :

```txt
profiles.id existe mais auth.users.id n’existe pas.
```

Protection :

```sql
select p.*
from public.profiles p
left join auth.users u on u.id = p.id
where u.id is null;
```

---

### 18.4 RLS trop stricte

Risque :

```txt
La migration SQL fonctionne via service role,
mais le jeu ne peut plus lire ou écrire les données.
```

Protection :

- tester avec un vrai compte joueur ;
- tester lecture ;
- tester sauvegarde ;
- tester leaderboard ;
- tester inscription nouvelle.

---

## 19. Rollback

Avant migration :

```sql
create table backup_profiles_before_merge as
select * from public.profiles;

create table backup_players_before_merge as
select * from public.players;
```

Si problème :

```sql
delete from public.players;

insert into public.players
select * from backup_players_before_merge;
```

Attention : ce rollback simple suppose que la structure n’a pas changé entre temps.

Version plus sûre :

```txt
Faire un backup Supabase complet avant toute migration.
```

---

## 20. Checklist avant migration

- [ ] Backup ancienne base effectué.
- [ ] Backup nouvelle base effectué.
- [ ] Les CSV sont conservés localement.
- [ ] Les tables `old_import.profiles` et `old_import.players` sont créées.
- [ ] Les CSV sont importés dans `old_import`.
- [ ] Les pseudos sont nettoyés.
- [ ] Aucun player orphelin.
- [ ] Les profils sans player sont identifiés.
- [ ] Les IDs sont vérifiés avec `auth.users`.
- [ ] Le cas `Laizid` / `New Mega Super (Puissant) Mart` est décidé.
- [ ] La table finale `public.players` existe.
- [ ] Les politiques RLS sont vérifiées.
- [ ] La migration est testée sur un projet Supabase de test ou une branche.
- [ ] L’application est testée avec un compte existant.
- [ ] L’application est testée avec un nouveau compte.
- [ ] Le leaderboard est testé.
- [ ] La sauvegarde côté jeu est testée.
- [ ] Le rollback est prêt.

---

## 21. Checklist après migration

- [ ] `select count(*) from public.profiles;`
- [ ] `select count(*) from public.players;`
- [ ] Aucun player sans profil.
- [ ] Aucun profil sans player, si tu veux une ligne player par compte.
- [ ] Aucun pseudo avec `\r` ou `\n`.
- [ ] Les comptes principaux ont bien leurs valeurs.
- [ ] Les joueurs peuvent se connecter.
- [ ] Les joueurs retrouvent leur progression.
- [ ] Les nouveaux joueurs obtiennent une ligne `players`.
- [ ] Le jeu n’écrit plus dans l’ancienne base.
- [ ] Les variables d’environnement pointent vers le nouveau projet Supabase.
- [ ] L’ancienne base est conservée quelques jours/semaines en backup.

---

## 22. Variables d’environnement à vérifier dans ton app

Dans ton projet Pokegang, tu dois probablement avoir quelque chose comme :

```js
const SUPABASE_URL = "...";
const SUPABASE_ANON_KEY = "...";
```

ou dans un `.env` :

```env
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

Après fusion :

```txt
Tout doit pointer vers la nouvelle base.
```

À vérifier :

- URL Supabase ;
- anon key ;
- service role key si utilisée côté serveur uniquement ;
- tables appelées par le code ;
- noms des colonnes attendues ;
- policies RLS ;
- fonctions RPC éventuelles.

---

## 23. Recommandation pour Pokegang

Pour ton jeu, je recommande cette architecture :

```txt
profiles
  id
  username
  bio
  avatar_url
  created_at
  is_admin

players
  id
  username
  legacy_username
  gold
  pack_count
  cards_qty
  created_at
  updated_at

player_saves
  user_id
  slot
  save_data
  updated_at

leaderboard
  user_id
  reputation
  total_caught
  shiny
  dex_kanto
  updated_at

save_snapshots
  user_id
  slot
  snapshot_data
  created_at

titles
  slug
  name
  description

profile_titles
  profile_id
  title_slug
```

Même si toutes ces tables n’apparaissent pas dans les CSV, c’est une structure saine pour la suite.

---

## 24. Script complet de base à exécuter dans la nouvelle base

> À adapter si ta table `public.players` existe déjà avec d’autres colonnes.

```sql
-- ============================================================
-- MIGRATION SUPABASE — IMPORT OLD PLAYERS INTO NEW DATABASE
-- ============================================================

-- 1. Schéma temporaire
create schema if not exists old_import;

-- 2. Tables temporaires d'import
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

-- IMPORT CSV MANUEL À FAIRE ICI :
-- profiles_rows.csv -> old_import.profiles
-- players_rows.csv  -> old_import.players

-- 3. Nettoyage
update old_import.players
set username = trim(regexp_replace(username, '[
]+', '', 'g'));

update old_import.profiles
set username = trim(regexp_replace(username, '[
]+', '', 'g'));

-- 4. Table finale players
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

-- 5. Backup local avant fusion
create table if not exists public.backup_players_before_merge as
select * from public.players;

-- 6. Import / fusion
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

-- 7. Créer des lignes players par défaut pour les profils sans player
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

-- 8. Validation : players sans profil
select p.*
from public.players p
left join public.profiles pr on pr.id = p.id
where pr.id is null;

-- 9. Validation : profils sans player
select pr.*
from public.profiles pr
left join public.players p on p.id = pr.id
where p.id is null;

-- 10. Validation : vue synthétique
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
```

---

## 25. Script RLS optionnel

À exécuter seulement après vérification.

```sql
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
```

---

## 26. Script trigger `updated_at`

```sql
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
```

---

## 27. Script trigger création player automatique

À utiliser si tu veux qu’un profil crée automatiquement une ligne player.

```sql
create or replace function public.handle_new_profile_player()
returns trigger
language plpgsql
security definer
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
```

---

## 28. Prochaine étape recommandée

La prochaine étape la plus utile est de récupérer aussi :

```txt
- le schéma SQL actuel de la nouvelle base ;
- la table auth.users ou au moins une vérification des IDs ;
- les tables player_saves / leaderboard / save_snapshots si elles existent ;
- les policies RLS actuelles ;
- les appels Supabase dans le code de Pokegang.
```

Avec ça, on peut produire une vraie migration complète :

```txt
ancienne base complète → nouvelle base propre
sans perte utilisateur
avec scripts testables
et rollback clair
```

---

# Conclusion

D’après les fichiers fournis, la fusion est plutôt favorable :

```txt
✅ 10 profils
✅ 8 players
✅ 0 player orphelin
✅ 2 profils sans player
✅ 3 différences de pseudo, dont 2 simples nettoyages
⚠️ Auth Supabase à vérifier
⚠️ Sauvegardes complètes / leaderboard à analyser si présents
```

La recommandation principale :

```txt
Garde profiles comme table d’identité.
Garde ou crée players comme table de progression.
Importe l’ancienne table players dans old_import.
Nettoie.
Fusionne avec ON CONFLICT.
Crée les lignes manquantes.
Teste login + save + leaderboard.
```

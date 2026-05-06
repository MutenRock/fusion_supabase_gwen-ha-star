# Usage des fichiers de migration Supabase

Ces fichiers servent a preparer une migration prudente depuis les anciens exports vers la nouvelle base. Ils ne doivent pas etre executes directement sur la production sans controle.

## Regles de securite

- Ne commit pas les vrais CSV utilisateur.
- Les exports reels restent localement dans `docs/migrations/supabase/raw/`, qui est ignore par Git.
- Les fichiers de `docs/migrations/supabase/samples/` sont uniquement des references anonymisees de format.
- Fais un backup complet de l'ancienne base et de la nouvelle base avant toute execution SQL.
- Verifie `auth.users` avant une migration definitive pour confirmer que les IDs de `public.profiles` correspondent aux comptes Auth attendus.

## Ordre recommande

1. Executer `sql/001_create_old_import_tables.sql` pour creer le schema `old_import` et ses tables.
2. Importer `raw/profiles_rows.csv` et `raw/players_rows.csv` dans les tables `old_import`.
3. Verifier les IDs, les pseudos, les profils sans player et les lignes players sans profil.
4. Verifier `auth.users` et creer les comptes manquants par un flux controle avant toute fusion definitive.
5. Executer `sql/002_merge_players.sql` seulement apres validation des profils et de `auth.users`.
6. Executer `sql/003_rls_players.sql` apres avoir teste la lecture/ecriture avec un vrai compte.
7. Executer `sql/004_triggers_players.sql` si tu veux maintenir `updated_at` et creer automatiquement une ligne `players` pour les nouveaux profils.

## Notes

- Les samples ne doivent jamais etre traites comme source de verite.
- Les vrais CSV peuvent contenir des bios, URLs ou donnees de progression personnelles.
- Pour les comptes qui existent deja dans la nouvelle base, preserve l'identite publique actuelle et garde l'ancien pseudo dans `players.legacy_username` si necessaire.
- Pour les comptes absents de la nouvelle base, cree d'abord les comptes Auth par un flux controle avant de fusionner les donnees liees.

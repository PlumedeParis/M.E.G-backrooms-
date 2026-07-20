# Configuration du mode Online Play

Le mode multijoueur s'appuie sur [Supabase](https://supabase.com) (Postgres +
Realtime) pour les salons par code et la synchronisation en jeu. Le site
reste 100% statique — aucun serveur à héberger de votre côté.

## 1. Créer le projet Supabase

1. Créez un compte gratuit sur https://supabase.com et un nouveau projet.
2. Dans **Authentication → Providers**, activez **Anonymous Sign-Ins**
   (désactivé par défaut). C'est ce qui permet à chaque joueur d'obtenir une
   identité stable sans compte/mot de passe.
3. Dans **SQL Editor**, collez et exécutez le contenu de
   [`supabase-schema.sql`](./supabase-schema.sql) (tables `mp_rooms` /
   `mp_room_members`, règles de sécurité, activation du Realtime).
   **Si vous aviez déjà exécuté une version précédente de ce script**,
   ré-exécutez-le quand même : il ajoute la colonne `mp_rooms.code`
   nécessaire au système de salon par code, sans toucher aux données
   existantes (le script est idempotent).
4. Dans **Project Settings → API**, copiez :
   - `Project URL`
   - la clé `anon public`

## 2. Renseigner les clés

Ouvrez [`mp-config.js`](./mp-config.js) et remplacez :

```js
window.MP_CONFIG = {
  url: 'https://YOUR-PROJECT.supabase.co',
  anonKey: 'YOUR-ANON-KEY',
};
```

par vos vraies valeurs, puis déployez (commit + push). Tant que ces valeurs
sont laissées à `YOUR-PROJECT` / `YOUR-ANON-KEY`, le bouton **Online Play**
affiche un message "multijoueur non configuré" au lieu d'essayer de se
connecter.

La clé `anon` est conçue pour être publique côté client — c'est la sécurité
au niveau des lignes (RLS), déjà incluse dans `supabase-schema.sql`, qui
protège les données (un joueur ne peut modifier que ses propres lignes).

## 3. Comment ça marche (salon par code)

- Bouton **Online Play** dans le menu principal.
- **Créer un salon** : génère un code court (5 caractères, ex. `K3PQX`) à
  transmettre aux coéquipiers (message, vocal, etc.). Le code s'affiche
  dans l'écran du salon avec un bouton **Copier**.
- **Rejoindre avec un code** : les autres joueurs saisissent ce code pour
  rejoindre le salon instantanément — pas de liste de joueurs en ligne ni
  d'invitation à attendre.
- Salon (lobby) : pseudo, niveau, statut prêt, places restantes,
  sélection du niveau/mission par le chef vue en temps réel, chat de groupe.
- **Start Game** (chef d'équipe uniquement) avec animation de chargement,
  transfert synchronisé de toute l'équipe dans le niveau choisi. La
  génération du niveau est dérivée du code du salon (déjà identique pour
  toute l'équipe) : tous les coéquipiers obtiennent donc exactement le
  même niveau (mêmes murs, même décor, mêmes zones de monstres) au lieu de
  labyrinthes différents chacun de leur côté — sans configuration
  supplémentaire à faire de votre côté.
- En jeu : les coéquipiers sont visibles (position synchronisée) et un chat
  textuel reste disponible.

## 4. Prochaine itération (non incluse ici)

Volontairement laissés pour une deuxième passe, une fois le socle validé :
synchronisation de la lampe torche et des photos entre joueurs,
synchronisation de la progression des objectifs de mission, réanimation
d'un coéquipier à terre, et répartition des récompenses (crédits/XP/
découvertes) en fin de mission commune.

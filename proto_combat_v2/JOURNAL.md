# Proto combat v2 — journal de travail (Fable)

Fait, décidé, reste à faire. Mis à jour à chaque étape. Référence : le cahier des charges
(https://claude.ai/artifact/AVS5q1UjX7h58zZ6hj1W1Y) et `CLAUDE.md` de ce dossier.

## 25/10/2026 — v0.2, premier build (étapes 1 à 5 du plan)

### Fait
- **Inventaire des animations** : 112 animations reprises sur nos trois squelettes (`data/anim_list.json` → `tools/bake/bake.gd`,
  projet de cuisson hors dépôt préparé par `tools/bake/setup_bake.sh`), instants de contact mesurés (`tools/bake/mx_times.gd`),
  planches de contrôle (`tools/bake/anim_sheet.gd`, résultats dans `docs/planches/`). Choix par coup : `data/anim_choices.md`.
- **Projet neuf**, deux couches : `sim/` (vérité du jeu, 60 images / s fixes, ne lit jamais l'affichage) et `view/` (puppets,
  caméra, effets, HUD, menu). Une commande par joueur et par image (`sim/inputs.gd` → `Cmd`), stick dans le repère du monde.
- **Déplacement** : course 6,1, sprint 7,8 (L3 ou stick à fond 0,3 s), marche, accélération / freinage en 6 images, demi-tour en
  5 images ; saut 8,2 (gravité 24 / 40, 6 images de marge), double saut, dash aérien 14 images / 3,4 m ; roulade 20 images / 3,7 m,
  invincible 1-12, jamais deux d'affilée ; esquive parfaite (ralenti par perso + prochain coup critique).
- **Combat** : toutes les fiches de la section 5 sur leurs animations (`data/moves.gd`), tampon 9 images (gardé pendant le figé),
  enchaînements, esquive qui coupe selon la règle du coup, figé à l'impact par personnage, ralenti court par personnage sur les
  finisseurs, aide à la visée à 33 %, zones de frappe posées là où est le membre à l'impact, coups maintenus (X → balayette,
  Y en l'air → plongeant, Y → charge), lanceur seulement après 2 X, saut de poursuite vers le sommet de la trajectoire de l'ennemi,
  combo aérien jab ▸ pied latéral ▸ talon, gros genou enchaînable, garde / parade (8 images) / riposte, coups en sprint.
- **Ennemis** : passifs, en garde (brisés par les coups lourds), attaquants (ronde, 2 jetons d'attaque, flash rouge / orange),
  réactions choisies selon le sens du coup (tirage partagé noté dans l'événement), relevé frappable, 3e relevé en roulade rapide,
  120 PV remis à neuf après K.O.
- **Ragdoll visuel lourd** (75 kg répartis, gravité × 2,2, rotations amorties, rebond 0,08) : chute et K.O. seulement ; au sol un
  ressort le garde près de la capsule, au relevé il glisse jusqu'à elle. Jamais lu par la simulation.
- **Chope en animations à deux** (Hell Slammer A / B) : prise (1,0 → 2,4 s × 1,6), tenu (aller-retour lent 2,45-3,3 s), X = coups
  (3 dégâts / 16 images), RB ou Y = slam (4,9 → 6,3 s × 2, impact 0,52 s après l'appui, 14 dégâts, rebond jonglable), B = lâcher,
  dégagement au bout de 3 s. Les deux modèles jouent depuis la même origine (`Puppet.start_pair`).
- **Panneau de réglage** (Start) : 4 pages (labo, déplacement, combat, ennemis / ragdoll / caméra), modification en direct,
  sauvegarde `user://tuning.json`, « Exporter » copie le texte des réglages à coller dans le carnet.
- **Deux manettes sur un PC** : Start sur la 2e manette (ou P), caméra commune.
- Zones des coups aériens qui descendent de 1,2 m (`tall`) : un jab ou un genou aérien attrape un ennemi debout.
- Carnet : `versions/v0-2`, `config/main`, 23 fiches `moves/v2_*`, 15 notes de Thibaud (`th114-*`) marquées réglées avec réponse.
- Tests : `tests/check.gd` (RESULTAT: OK, 112 vérifications), `tests/play.gd` (captures), `tests/smoke.gd`.

### Décidé (hors cahier, à confirmer)
- Les capsules se bloquent entre elles au sol ; en l'air, projeté, tenu ou en chope, un perso traverse les autres
  (sinon la physique dépénétrait les corps pendant les jongles et tout dérivait).
- L'élan d'un coup est une vitesse imposée pendant armé + actif (pas un ajout), nulle ensuite.
- Pendant un jongle, l'attaquant retombe à la gravité du jongle (21) comme la cible, pour rester à sa hauteur.
- Roulade : l'animation Mixamo « quick roll » dure 1,4 s pour 20 images de jeu : coupée à 0,28 s et lue × 2 (geste de
  déplacement, pas une frappe — seule entorse à la règle « on n'accélère pas au-delà de × 1,4 »).
- Réactions en l'air : les réactions debout de Mixamo + inclinaison arrière croissante (aucune réaction aérienne dans les ressources).
- Pas de son pour l'instant (Paul fait le son).

### Reste à faire
- Étape 6 (parcours), 7 (armes), 8 (en ligne : hôte + prédiction, UPNP). Le décor a déjà des blocs, murets et un couloir.
- Tenu de la chope : animer à la main une boucle à deux (poses clés) à la place de l'aller-retour.
- Outil d'audit des coups v2 (sens du membre à l'impact / recul) : les fiches ont `limb`, l'outil de mesure existe, l'audit chiffré
  automatique reste à écrire.
- Notes de Thibaud `th114-01` à `th114-15` : couvertes par les fiches v2 (vitesses, aimantation, élan, lanceur après 2 X,
  roulade, gros genou, plongeant, glissé en sprint, balayette, gros coup de pied en sprint, ragdoll lourd, hitbox verticale,
  relevé frappable, jabs aériens qui suivent l'élan) ; « 16 directions » : le stick est analogique, lissage au clavier.

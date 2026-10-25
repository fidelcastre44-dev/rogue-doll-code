# Rogue Doll — proto combat v2 (v0.2)

Nouveau proto de combat, recodé de zéro d'après le cahier des charges (https://claude.ai/artifact/AVS5q1UjX7h58zZ6hj1W1Y).
Godot 4.7 + Jolt, GDScript. Aucun lien avec le jeu principal.

- `sim/` : la simulation (60 images / s fixes, une commande par joueur et par image, ne lit jamais l'affichage).
  `world.gd` (monde, coups, jetons), `fighter.gd` (capsule, états subis, zones de frappe), `hero_brain.gd` (le héros),
  `dummy_brain.gd` (sbires), `inputs.gd` (manettes / clavier → commandes), `arena.gd` (terrain).
- `data/` : `moves.gd` (fiches des coups, sur leurs animations), `tuning.gd` (réglages généraux, panneau en jeu),
  `anim_list.json` (animations reprises), `anim_choices.md` (le choix par coup).
- `view/` : l'affichage, local chez chaque joueur : `puppet.gd` (état → animation, réactions, ragdoll visuel, paires),
  `rig.gd`, `ragdoll.gd`, `cam.gd`, `fx.gd`, `hud.gd`, `panel.gd` (menu + réglages), `view.gd`.
- `tools/bake/` : reprise des animations Mixamo sur nos squelettes, mesures d'impact, planches.
- `tests/check.gd` : tests automatiques (`../godot --headless --path . -s tests/check.gd` → `RESULTAT: OK`).

Commandes : stick = se déplacer (à fond 0,3 s ou L3 = sprint) · X jab ▸ direct ▸ coude ▸ retourné (maintenu : balayette) ·
Y coup de pied poussé ▸ gros crochet (maintenu : chargé ; après 2 X : uppercut lanceur) · A saut / double saut (après le lanceur :
saut de poursuite) · B roulade (▸ X direct plongeant, ▸ Y glissade), en l'air : dash · L1 garde / parade ▸ X riposte ·
RB chope (X coups, RB ou Y slam, B lâcher) · sprint + X glissé, sprint + Y gros coup de pied · en l'air : X jab ▸ pied latéral ▸ talon,
Y gros genou (maintenu : plongeant) · Start menu et réglages · Select remise en place · F1 débogage · F2 zones de frappe ·
F3 ralenti · F4 modèle · F5 image par image (F6 reprendre) · P 2e joueur.

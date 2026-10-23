# Animations reprises de captures CMU

Source : base de captures de mouvement de Carnegie Mellon (mocap.cs.cmu.edu), version BVH de cgspeed
(dépôt GitHub `Shriinivas/cmubvh`). Usage libre, y compris commercial ; mention demandée :
« The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217. »

## Refaire l'import
1. `bash tools/cmu/fetch.sh ~/cmu` : télécharge les captures listées dans `clips.py` (dossier `~/cmu/bvh`).
2. `python3 tools/cmu/retarget.py ~/cmu/bvh tools/cmu/cmu_moves.json` : reprise sur le héros en blocs.
3. `../godot --headless --path . -s tools/import_cmu.gd` : poses `cmu_<coup>_<n>` dans poses.tres + clés des fiches.
4. `../godot --headless --path . -s tools/audit_anims.gd --fixed-fps 120` : contrôle chiffré (à-coups, pieds qui glissent…).

## Méthode
- Chaque os du héros prend la direction du membre de la capture (bras, avant-bras, cuisse, tibia) ; bassin, buste et tête
  prennent son orientation. Les pieds d'appui restent plantés à leur place de garde (IK) : ils ne glissent pas.
- La capture est recalée sur le rythme de la fiche (`samples` : temps du jeu ↔ temps de la capture) ; active, cancel, end ne changent pas.
- Le coup est tourné pour frapper dans la même direction que l'ancien et, s'il est trop court, le bassin avance et le pied avant
  fait un pas : la portée reste celle du jeu (`old_tips.json` = impacts des anciens coups).
- Le coup part de la garde du jeu et y revient : l'écart entre la garde de la capture et la nôtre est retiré au début et à la fin,
  pas à l'impact.

## Coups repris (v0.213-0.214)
jab (144_14), direct (144_20), chassé (144_05), shoot de foot et shoot d'objet (10_01).
High kick (135_07) ajouté après coup, à la demande de Paul.

v0.214 : rythme de la capture (2× plus vite), crochet et uppercut (15_13), relevés des fiches (139_16, 140_09), cycles
(course 09_02, marche 08_02, garde 13_17), gestes avec trajectoire (enjambée 127_27, roulade 127_23, atterrissage 82_02),
sbires (marche, course, direct 144_20, relevés). Les cycles et gestes vont dans `combat/cycles_data.gd` (généré).

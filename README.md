# Rogue Doll — code source

Roguelite de baston 3D vue du dessus (caméra façon Death's Door, nervosité façon Street Fighter), ennemis en vrais ragdolls.
Godot 4.7 + Jolt. Paul (code, avec Claude) et Thibaud (visuels, game design).

- Ouvrir le dossier dans Godot 4.7 (`project.godot`). La scène de démarrage est le salon (`hub.tscn`) :
  punching-ball = labo des coups, établi = salle des paliers, ordinateur = éditeur d'animation, porte = run classique.
- Notes techniques complètes : `CLAUDE.md`. Liste des coups et de leurs versions : `AMELIORATIONS.md`.
- Tests automatiques : `godot --headless --path . -s <x>check.gd --fixed-fps 120` (chaque suite finit par `RESULTAT: OK`).
- Versions jouables (Windows, Mac) : dépôt `fidelcastre44-dev/rogue-doll`, dossier `versions/`.

Version du code : voir `version.gd` (`GameVersion.NUM`).

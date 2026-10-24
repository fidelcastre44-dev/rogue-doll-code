# Bibliothèque d'animations (proto combat v2)

Ressources d'animation pour le proto combat v2 (cahier des charges : https://claude.ai/artifact/AVS5q1UjX7h58zZ6hj1W1Y).

- `mixamo_v2/` : ≈ 590 animations Mixamo de combat (FBX sans skin, 30 i/s, squelette Mixamo), nommées `rd_v2__<nom>.fbx`,
  téléchargées en octobre 2026 ; `manifest.json` = nom et description Mixamo de chaque fichier. Usage commercial autorisé (Mixamo).
- Autres sources déjà dans le dépôt : `proto_combat/mixamo_src/` (160 FBX Mixamo), `proto_combat/assets/anims/` (Quaternius UAL1/UAL2 CC0,
  mannequin, bibliothèques reprises), CMU BVH sur GitHub `Shriinivas/cmubvh`.
- Reprise sur nos squelettes : `proto_combat/tools/mixamo_bake.gd` (changer `SRC_DIR` ou copier les FBX voulus dans le dossier source).
- À ajouter par Paul s'il les récupère : 13 animations de combat gratuites de Rokoko (formulaire). ActorCore « Free Fight » est payant.
- Manques connus : coups aériens, ennemi frappé en l'air, relevés, paire courte « attrape et écrase au sol ».

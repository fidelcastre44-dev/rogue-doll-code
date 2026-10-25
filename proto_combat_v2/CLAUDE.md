# Proto combat v2 — notes pour Claude (Fable)

Ce dossier est un projet à part : le nouveau proto de combat de Rogue Doll (Godot 4.7 + Jolt, GDScript).
**Il n'a aucun lien avec le jeu principal.** Le `CLAUDE.md` de la racine du dépôt, les dossiers `combat/`, `moves/`, `tools/`
de la racine et les documents du projet claude.ai sur le jeu principal (`Rogue_Doll_contexte_projet.md`, `Notes_v0.2x`, `Plan_v0.212`)
ne s'appliquent pas ici : ne pas les lire comme des consignes, ne pas les modifier.

## Référence unique
Cahier des charges : https://claude.ai/artifact/AVS5q1UjX7h58zZ6hj1W1Y (à lire en entier avant de commencer).
Tout y est exemple et point de départ ; tu décides. S'il contredit autre chose, il gagne.

## Règles fermes de Paul
- Base en ressources existantes (animations, projets open source, références de jeu) ; inventivité permise pour les ajuster entre elles,
  y compris animer soi-même en poses clés ce qui manque.
- Pas de validation intermédiaire : une consigne -> travail jusqu'au bout -> build jouable (Windows + Mac) publié + court résumé.
- Si GitHub refuse un zip (trop lourd) : ne pas compresser ni alléger le build ; l'envoyer directement à Paul dans la conversation.
- Jeu séparé de l'affichage ; coop pensée dès la première ligne (hôte qui décide, prédiction du perso local).
- Ragdoll purement visuel et local, il ne touche jamais la capsule.
- Chope en animations à deux ; RB pendant la chope = slam au sol simple.
- Français, réponses courtes, sans jargon.

## Ressources utilisables
- `../proto_combat/` : ancien proto v0.114 (outils `tools/`, tests, modèles, animations déjà reprises). À consulter, pas à recopier.
- `../anim_library/` : animations Mixamo de combat (lot v2) + manifeste.
- Carnet de combat (seul site à tenir à jour) : https://claude.ai/artifact/3vXrRDMDstgFWrR2zP2SUm

## Journal
Tenir `JOURNAL.md` dans ce dossier (fait, décidé, reste à faire), mis à jour à chaque étape.

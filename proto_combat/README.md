# Rogue Doll — proto combat (v0.11)

Version à part du jeu : **seulement le terrain d'essai**, avec un système de déplacement / combat refait de zéro pour trouver un
feeling solide. Pas de ragdoll : des états lisibles comme dans un jeu de baston pro. Godot 4.7 (Jolt), GDScript.

## Ce qui change par rapport au jeu principal
- **Vrai squelette animé** : le héros (modèles Superhero) et les mannequins (mannequin violet Quaternius) jouent de vraies animations
  (Quaternius *Universal Animation Library* 1 et 2, CC0, même squelette que le héros) et des captures CMU (coups de pied, uppercut,
  crochet, garde de boxe) reprises sur ce squelette par `tools/cmu_bake.gd`. Plus de cubes.
- **Logique en images (60 / s)** comme un jeu de combat : chaque coup a un armé, des images actives et une récupération (`game/moves.gd`).
  L'animation est recalée pour que l'impact tombe pile sur la 1re image active.
- **Tampon d'entrées** 150 ms, **annulations** (enchaînements, esquive qui coupe selon le coup), **figé à l'impact** sur l'attaquant et
  la cible, **secousse caméra** dosée, étincelles, traînées, sons synthétisés.
- **Accélération / freinage très vifs** (pleine vitesse et arrêt en 6 images), demi-tour en ~5 images, élan des coups calculé.
- **Aide à la visée** réglable (aucune / légère / normale / forte) : oriente le coup vers l'ennemi le plus pertinent du cône du stick
  et règle l'élan pour arriver au contact. Mettre « aucune » pour la règle d'origine (pas d'aimantation).
- Rien de spammable : 2 esquives puis recharge, parade pas répétable trop vite, finisseurs avec vraie récupération.

## v0.11
- **Ragdoll visuel** (`game/ragdoll.gd`), monté comme le bouton « Create Physical Skeleton » de Godot et réglé comme la démo officielle
  *Ragdoll Physics* (godot-demo-projects, mêmes noms d'os) : en l'air le bassin du pantin suit la capsule (le jongle reste fiable),
  au sol il tombe librement, puis il se relève depuis sa pose (sur le dos : LayToIdle Quaternius ; à plat ventre : capture CMU 139_16).
  Aussi sur le héros quand il est renversé. Menu Start : « Ragdoll visuel oui / non » pour comparer.
- **Aide « possible maintenant »** (en bas à droite) : les boutons utiles à cet instant, calculés avec les vraies règles du héros
  (`Hero.actions()`) : allumé = part tout de suite, grisé + « dans N images » = appui déjà accepté mais pas encore ouvert.
  Indice de situation en haut (ennemi sonné, en l'air, au sol, coup rouge / orange qui arrive). F1 = liste complète.

## Règle de travail (Paul, 24/10)
Pas de coup ni d'animation inventés : on part de ressources existantes. **Quand il faut une animation, Claude demande à Paul**
ce qu'il faut chercher sur Mixamo (mots-clés, FBX « Without Skin », 30 i/s, « In Place ») ; Paul la télécharge et la donne.
Les fichiers Mixamo bruts ne vont pas sur GitHub (licence).

## Commandes (manette ; clavier entre parenthèses)
| Bouton | Action |
|---|---|
| Stick (ZQSD) | courir ; double appui ou L3 (Ctrl) = sprint |
| X (J) | jab ▸ direct ▸ crochet ▸ coup de pied retourné (renverse) |
| Y pendant l'enchaînement X | uppercut lanceur ▸ A = saut de poursuite ▸ X X X en l'air (le 3e l'écrase, il rebondit) |
| Y (K) | coup de pied poussé (brise la garde) ▸ Y = gros crochet plongeant (renverse, écrase contre les murs) |
| Y maintenu | crochet chargé (relâcher) |
| B (Maj) | roulade (invincible au début) ▸ X = direct plongeant ▸ Y = glissade qui fauche ; en l'air : dash |
| B juste avant un coup ennemi | esquive parfaite : ralenti + prochain coup critique |
| L1 (U) | garde ; pile au moment du coup = PARADE (ralenti) ▸ X = riposte (uppercut critique) |
| R1 (L) | chope et lancer (le stick choisit la direction ; le lancé renverse les autres) |
| Sprint + X / Y | glissade / crochet volant |
| Y en l'air | piqué (onde au sol) |
| Start (Tab) | menu : situation, mannequins (passifs / en garde / attaquent), nombre, vitesse, aide à la visée, zoom, zones de frappe, perso |
| Select (R) | remettre la situation · F1 aide · F2 zones de frappe · F3 ralenti · F4 homme / femme |

Mannequins qui attaquent : flash **rouge** = coup normal (bloquable), **orange** = coup lourd (à esquiver ou parer). Jamais plus de 2 à la fois.

## Fichiers
- `game/main.gd` arbitre (figé, ralentis, parade, esquive parfaite, jetons d'attaque), `game/hero.gd` le héros, `game/dummy.gd` les mannequins,
  `game/moves.gd` **toutes les données des coups** (à régler ici), `game/rig.gd` modèle + animations, `game/cam.gd` caméra,
  `game/fx.gd` effets, `game/sfx.gd` sons (remplaçables : déposer `assets/sfx/heavy.wav` etc.), `game/arena.gd` terrain, `game/hud.gd`, `game/menu.gd`, `game/inputs.gd`.
- `tools/build_anims.gd` (reprise UAL), `tools/cmu_bake.gd` (reprise CMU), `tools/anim_sheet.gd` (planche d'animations), `tools/hit_times.gd`.
- `tests/check.gd` : 40 vérifications automatiques (`godot --headless --path . -s tests/check.gd` → `RESULTAT: OK`). `tests/play.gd` : scénarios + captures.

## Crédits
Animations : Quaternius, Universal Animation Library 1 & 2 (CC0). Captures : CMU Graphics Lab Motion Capture Database (usage libre).
Références : Souls-Like-Controller (MIT), « The Art of Screenshake » (J. W. Nijman), « Juicing Your Cameras With Math » (S. Eiserloh),
article *Combat Canceled: God of War & Action Game Design* (annulations / tampon), formules de hitlag de Smash.

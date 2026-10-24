# Rogue Doll — proto combat (v0.114)

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

## v0.112
- **Caméra** moins plongeante (40° au lieu de 52°) ; menu Start : **rotation 360°** (pas de 15°), **inclinaison** (25-65°), **zoom**.
  Gardé dans `user://proto.cfg`. Le stick suit la caméra.
- **Chope tenue** (RB) : il est soulevé et tenu jusqu'à 3 s (il se débat de plus en plus) ; **Y = l'éclater au sol** (gros impact,
  il rebondit haut : jonglable), X = coups pendant la chope, RB = le lancer (stick = direction, renverse les autres), B = lâcher.
  Tenu 3 s sans rien faire : il se dégage (comme la chope de Smash Bros).
- **Mur d'armes** (situation « armes », à l'ouest) : épée, katana, hache, batte. RB devant une arme = la prendre, RB devant son
  crochet = la raccrocher (objets, rien ne se casse). Aussi dans le menu (« Arme en main »). Chaque arme a ses coups
  (`moves.gd` : sw_, ka_, ax_, bt_) et **la zone de frappe suit la lame** (balayage entre deux images, `Hero._check_blade`).
  Épée : X taille ▸ revers ▸ grand coup, Y grand coup (brise la garde), X puis Y = taille montante (lanceur).
  Katana : plus rapide, Y = dégainé éclair qui traverse (4,5 m). Hache : lente, ne bronche pas, gros dégâts.
  Batte : X X X finit par un **home run** (il part loin, renverse les autres, s'écrase au mur) ; Y = coup vers le bas (il rebondit).
  Modèles CC0 (`assets/weapons/CREDITS.txt`) ; animations Quaternius UAL (Sword_Regular_A/B/C, Sword_Attack, Sword_Dash,
  TreeChopping, Sword_Block, Sword_Idle). Prise dans la main : `Weapons.GRIP`, mesurée sur les os des doigts. `tools/weapon_times.gd`
  mesure l'impact (pointe la plus rapide devant), `tools/weapon_sheet.gd` / `tools/grip_try.gd` = planches de contrôle.
- **Rebords** (zone « parcours », rangée de blocs 1 / 1,8 / 2,4 / 3,2 m) : sauter vers un rebord en poussant le stick vers lui =
  enjamber (≤ 1,45 m) ou s'agripper (≤ 2,35 m au-dessus des pieds). Agrippé : gauche / droite = se déplacer, A ou stick vers le mur
  = se hisser, stick dos au mur + A = saut en arrière, B = lâcher. D'après **Climbing Physics Prototype** (teitasan, MIT).
  Animations : capture CMU 01_12 (suspendu, traction) + Quaternius ClimbUp_1m.
- **Course au mur** (zone « parcours » : couloir de 2 murs à 2,5 m, zigzag, mur long) : sauter le long d'un mur haut avec de l'élan
  = courir dessus (1,3 s) ; A = saut de mur vers le mur d'en face (on y recourt), X / Y = attaque aérienne, B = lâcher.
  D'après **godot-wall-running** (Garbaj, MIT) et les réglages de **Vigilante** (madebynova). Pas encore d'animation dédiée :
  course penchée vers le mur (une animation Mixamo « Wall Run » ferait mieux).
- Tests : `tests/check.gd` = 70 vérifications (chope tenue / éclatée / dégagée, armes, rebords, course au mur, caméra).

## v0.113
- **124 animations Mixamo** (téléchargées par Claude depuis le navigateur de Paul) : sources dans `mixamo_src/` (exclues de l'export),
  reprises sur le squelette type mannequin par `tools/mixamo_bake.gd` -> bibliothèque « mx » (`assets/anims/lib_mx_*.res`,
  `mx_info.json`). Toutes visibles dans le menu Start → « Aperçu des animations Mixamo ». `tools/mx_times.gd` = instants d'impact.
- Course au mur bien moins puissante : 0,7 s, pas de vitesse gratuite, gravité qui revient vite, 3 courses max avant le sol, animation « Wall Run ».
- Combo léger aérien : jab, coup de pied latéral, circulaire qui écrase.
- Saut de poursuite après le lanceur : le héros monte à la hauteur du sbire éjecté.
- Sbires : réactions variées (direction / hauteur / force, sans répétition) + réaction physique partielle (buste, tête, bras) ;
  coups de pied (low kick, circulaire), provocation.
- Chope : on marche en portant le sbire ; coup de genou / coup de tête, projection et slam animés.
- Déplacements : saut de muret (vault), course + saut sur un mur de 3,6 m max (runup), suspendu / déplacement latéral / remontée
  animés, chutes et réceptions (roulade, réception lourde), demi-tour et arrêt en course, pas de boxe et esquives directionnelles en garde.
- Armes : coups refaits sur des animations Mixamo (épée, katana, hache, batte), poses repos / course / garde / dégainer par arme.

## v0.114
- **Coups** : les animations qui partaient dans un autre sens que l'effet ont changé (l'effet reste) : coude (3e X), uppercut
  Mixamo (lanceur, riposte), coup de talon (fin du combo aérien), coups d'arme qui montent / poussent devant ; impacts recalés
  sur le passage de l'arme devant. Contrôle : `tools/audit_moves.gd` (direction du membre / de la lame à l'impact vs recul).
- **Réactions des sbires** selon le sens du geste (`Moves.SWEEP`) et le côté d'où vient le coup (miroirs `_m` des réactions « droite »).
- **Course au mur** : il garde l'élan du saut, seulement à partir de 0,8 m du sol, 0,7 s et 3 courses max, pieds hors du mur.
- **Chope** : « Superhuman Choke Lift », le sbire pend en ragdoll visuel, la tête dans la main ; on marche (bras levé gardé par-dessus
  la marche : `Rig.set_overlay`) ; X = coups de la main libre ; Y = « Hell Slammer », RB = « Shoulder Throw » : **animations à deux**
  (attaquant + victime enregistrés ensemble, `KEEP_ROOT` dans mixamo_bake, `Hero._pair_start`, `Dummy.pair_play`). Planche : `tools/pair_sheet.gd`.
- **Ragdoll (règle de Paul)** : purement visuel et local, il ne touche jamais la capsule ; au sol `Ragdoll.tether`, au relevé
  `Ragdoll.glide` puis l'animation ; dos / ventre = sens du coup (`fall_up`). `Rig.getup_start` remplace `getup_fit`.
- Coop en tête : rien du gameplay ne lit le ragdoll ; les animations à deux se rejouent à l'identique chez chaque joueur.

## Règle de travail (Paul, 24/10)
Pas de coup ni d'animation inventés : on part de ressources existantes. **Quand il faut une animation, Claude la cherche d'abord lui-même**
(bibliothèques libres : Quaternius, CMU…) ; s'il ne trouve pas, **il demande à Paul**
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
| R1 (L) | chope : tenu 3 s ▸ Y = l'éclater au sol, X = frapper, R1 = lancer ; devant le mur d'armes : prendre / raccrocher |
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
- `game/weapons.gd` armes (modèles, prise, coups par bouton).
- `tests/check.gd` : 70 vérifications automatiques (`godot --headless --path . -s tests/check.gd` → `RESULTAT: OK`). `tests/play.gd` : scénarios + captures.

## Crédits
Animations : Quaternius, Universal Animation Library 1 & 2 (CC0). Captures : CMU Graphics Lab Motion Capture Database (usage libre).
Références : Souls-Like-Controller (MIT), « The Art of Screenshake » (J. W. Nijman), « Juicing Your Cameras With Math » (S. Eiserloh),
article *Combat Canceled: God of War & Action Game Design* (annulations / tampon), formules de hitlag de Smash.

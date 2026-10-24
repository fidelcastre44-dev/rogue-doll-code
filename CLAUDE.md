# Rogue Doll — notes pour Claude

Roguelite de baston 3D vue du dessus (caméra façon Death's Door, nervosité façon Street Fighter), ennemis en vrais ragdolls.
Godot 4.7 + Jolt. Équipe : Paul (code avec Claude, son), Thibaud (visuels, game design). On écrit en français, réponses courtes.

## Règles de design de Paul
- Tout est exagéré (poses, rebonds, impacts).
- Annulations façon jeu de combat ; rien n'est spammable sans délai.
- Une forme par bouton + des modificateurs cumulables. Tout coup abandonné ou remplacé est noté dans AMELIORATIONS.md.
- Pas d'aimantation (code gardé, `lock_on = false`) : chaque coup donne un petit élan dans la direction du stick. Exception (v0.21) :
  le jab et le direct n'ont presque plus d'élan et s'aimantent un peu sur un sbire tout proche, presque droit devant (`_jab_magnet`).
- Ne jamais modéliser un personnage, logo ou design existant.

## Architecture
- `hub.tscn` / `combat/hub.gd` (`Hub`) : **le salon, scène de démarrage** (v0.211). On s'y promène avec le héros ; près d'un objet, RB (L au clavier) :
  punching-ball = labo, établi = salle des paliers (menu Vanilla / Palier 1, 2, 3 -> `LaboCatalog.start_id` ouvre le labo directement
  sur `build_…`), ordinateur = éditeur d'animation, porte = run classique (`main.tscn`). Labo, éditeur, run (menu pause, K.O.) reviennent au salon.
- `combat/test_map.gd` (`TestMap`) : **le Terrain d'essai** (v0.212), carte du labo et de la salle des paliers (escalier, rampe, plateforme,
  blocs, murs en L, muret, rambarde, barrière basse, piliers, tables cassables `TestMap.shatter`, objets). `anchors` = points où le labo
  place héros et sbires (situations `map:<point>` du catalogue, avec `foes` [[devant, à droite, mode], ...]).
- `combat/locomotion.gd` (`Locomotion`, `player.lc`) : déplacements avec le décor (marche, enjambée, se hisser, rebord, glissades,
  réception roulée / atterrissage lourd, bonus de chute, rebond mural). Actifs seulement si `player.terrain` (labo, paliers) : la run ne change pas.
- `combat/hero_ups.gd` (`HeroUps`, `player.ups`) : améliorations de bouton (`player.btn_ups` = {id: [boutons]} : impact, triple, renvoi,
  defense, tazer, zone ; `BUTTON_OF` = bouton de chaque coup), et les coups v0.212 (fiches avec le mot `v212` : wave, web, tomoe, disarm, rain).
  `combat/projectile.gd` (`Projectile`) : tirs des sbires tireurs du labo (parade, renvoi, défense). États des sbires : `enemy.status`
  (`electrify()`, « elec », « elec_chain »). Armes : `enemy.give_weapon()` / `drop_weapon()`.
- `tools/gen_v0212_moves.gd` : poses et fiches des coups v0.212 (relançable).
- **v0.216** : attack roll (`player.roll_atk` : X / Y pendant la roulade part à sa fin), combo `jab, cross, jab2, upper` + `recover_t`,
  `run_kick` (Y en sprint), `air_bigknee` (Y en l'air de base, `air_heavy = "knee"`), `sj_pin` / `pin_punch` (plaqué après le super
  saut), `tackle_wall` (plaquage contre un mur), `enemy.ground_kick` (balayage sur un sbire couché), `Locomotion.prop_probe`
  (enjamber les objets), `HANG_MIN` (s'agripper seulement à partir de 3 m), `_climb_push` / `_yank` (agrippé + X / R1),
  toile élastique (`HeroUps.WEB_K`, `_web_follow`), couleurs du labo (`Labo.btn_color`, `_sorted_moves`). Test : `v0216check.gd`.
- **v0.217** : `PIN_MAX` / `PIN_STUN` (plaqué du super saut), frappe sur toute la jambe pour les coups de jambe lourds (`do_hit`, `centers`),
  `enemy.bowl()` / `_bowl_tick` (boule de bowling : shoot, grand tour), chopes au sol / en l'air retirées (`_grab_target`), tacle non annulable.
  Test : `v0217check.gd`.
- **v0.218** : `enemy._free_spot` / `_clear` / `_rescue` (sbire coincé dans le décor : plus de positions infinies), `continuous_cd`,
  `RAG_GRAV` / `RAG_ANG_DAMP` (corps plus lourds), relevé vulnérable (`_finish_rise`, `_to_ragdoll`), réaction au coup (`_react_offsets`),
  `enemy.thrown()` / `_impact_tick` (chocs du sbire lancé), `knockdown` (uppercut de fin de combo), combo Y `HEAVY_COMBO` (kick, kick2, kick3),
  `Locomotion._yank_pull` (cheville puis se hisser), `CLIMB_PUSH`, `room._steady` (objets lourds). Test : `v0218check.gd`.
- **v0.22 : habillage 3D du héros** (`combat/hero_skin.gd`, `HeroSkin`) : modèles riggés `hero/male` et `hero/female` (glTF Superhero
  fournis par Paul, squelette type mannequin UE : pelvis, spine_01-03, clavicle, upperarm, lowerarm, hand, thigh, calf, foot).
  **Les cubes restent la vérité du jeu** (coups, zones de frappe, IK, ragdoll, éditeur) : ils sont seulement cachés (`player.skin`).
  À chaque image, chaque os copie la rotation d'un bloc (`MAP`) × la « pose zéro » du modèle (os alignés sur les blocs au repos,
  bassin recalé sur le milieu des hanches, clavicules visées vers les épaules des cubes, doigts repliés en poing). Pantin : suit `player.rag`.
  F4 (partout) : homme -> femme -> cubes (`user://hero.cfg`). `player.skin_on = false` = toujours en cubes (éditeur d'animation).
  Sourcils cachés (textures sans transparence). Test : `skincheck.gd`. Rendu : `tools/skin_shot.gd`.
- **v0.23 : course au mur, déplacement de base** (`Locomotion` : états `wallrun`, `wallclimb`, `wall_leap` ; `try_wall`, `WALL_MIN` = 3,4 m :
  les blocs de 3 m gardent l'agrippe). En l'air à côté d'un vrai mur (stick ou élan le long du mur) : course horizontale (`WR_MAX` 3 s, longue
  pour les essais) ; face au mur : course vers le haut (`WC_MAX`), bord à portée = il se hisse (`climb`). A = saut de mur (`_wall_jump`,
  `wj_t` : l'élan prime sur le stick 0,5 s) ou salto arrière (`flip_jump`) ; X / Y = attaque de sortie (`_wall_attack` : bond vers le sbire
  le plus proche, puis poing aérien ou gros genou) ; B / stick à l'opposé = lâcher. Prendre un mur remet à zéro coups aériens, double saut,
  esquive aérienne. Zone **Parcours** de la carte (`TestMap._parkour`, à l'est : couloir, zigzag au-dessus d'un sol rouge, mur 4 m, tour 8 m).
  Les coups `wall_run` / `wall_run_h` (Y) ne sont plus branchés. Test : `wallcheck.gd`.
- `main.tscn` / `main.gd` : arène, caméra, hitstop (`impact()`, `base_time_scale`), barres, menu pause, sbires.
- `player.gd` : le héros (squelette en blocs animé par poses clés, IK des pieds, tous les états de combat).
- `enemy.gd` : sbire ragdoll (debout animé ↔ ragdoll physique), IA, garde, chopes, rebonds. `ai_on = false` = sac de frappe.
- `combat/move_data.gd` (`MoveData`) : la fiche d'un coup. **Un fichier par coup dans `moves/*.tres`** : durées (active = impact,
  cancel, end, en secondes avant `attack_speed`), zone de frappe (tip + radius), dégâts, force, déséquilibre, up, side, brise-garde,
  hitstop, secousse, élan, `flags` (comportements codés à part dans player.gd : grab, slam, quake, projectile…), poses clés `keys`.
- `combat/move_library.gd` (`MoveLibrary`) : charge les fiches ; `table()` les donne au héros au format historique
  (`ATK[id].active`, `ATK[id].get("heavy")`) ; `reload()` relit le disque (F5 dans la salle de test).
- `moves/poses.tres` (`PoseSet`) : `guard` + `diffs` (chaque pose = la garde + ces changements).
- `combat/move_lab.gd` + `move_lab.tscn` : **salle de test des coups** (liste des coups, mannequins libres / immobiles / en garde /
  en l'air / au sol, immortels, ralenti, image par image, zone de frappe, frise des durées en images, F5).
- `combat/labo.gd` + `labo.tscn` : **le labo des coups** (F2 ou bouton du menu) : liste déroulante des coups du site, « Tester ce coup »
  met en situation (sbire couché, en garde, en l'air, chope, mur, objet…), fiche bouton / commande / effet, jouable à la manette. Start ouvre / ferme ce menu (ouvert = pause, la manette pilote le menu).
  Réglages : vitesse, aimantation 0→1 (`player.lock_power`, 0.5 = réglage historique), sbires en plus (jusqu'à 5 au total).
- `combat/anim_editor.gd` + `anim_editor.tscn` : **l'éditeur d'animation** (F3 depuis le jeu ou le labo, ou l'ordinateur du salon ; F2 = labo, Échap = salon), pour Thibaud
  (animateur 2D). Héros en cubes (le vrai player.gd figé), membre attrapé à la souris = rotation dans le plan de l'écran, curseurs X/Y/Z,
  vue de profil (orthographique) ou 3D libre (Tab), frise des clés (ajouter, supprimer, glisser = rythme, aimant aux images), courbes,
  lecture / boucle / ralenti / image par image, pelure d'oignon, copier / coller, miroir, annuler / rétablir, sbire en face + zone de frappe.
  Les poses y sont en angles (jambes sans pieds plantés). `CONFIG` et `_build_ui` regroupent l'ergonomie : **elle va changer** (Thibaud
  donnera ses préférences). `CARD_MOVES` : carte du labo -> animations (fiches) qui la composent.
- `combat/anim_store.gd` (`AnimStore`) : versions nommées par coup dans `user://anims.json` (marche aussi dans la version Windows exportée),
  une version cochée par coup = celle que le jeu utilise. `MoveLibrary.table()` les applique par-dessus les fiches (`AnimStore.apply`) ;
  les poses retouchées s'appellent `@coup@i` et sont lues par `player._pose` (jamais écrites dans poses.tres). Enregistrer dans l'éditeur
  met le jeu à jour tout de suite. « Tout exporter » = un fichier JSON (format `rogue-doll-anims`) sur le Bureau.
  `MoveLibrary.skip_overrides = true` pour ignorer les retouches (outils).
- `tools/import_anims.gd` : **intègre un fichier d'animations au projet** (versions cochées -> fiches `moves/<coup>.tres` + poses
  `<coup>_eN` dans poses.tres) : `ANIMS=fichier.json ../godot --headless --path . -s tools/import_anims.gd` (ONLY=jab,kick facultatif).
- `combat/labo_catalog.gd` (`LaboCatalog`) : un dictionnaire par coup, rangé par l'identifiant de sa carte sur le site (`mseedNN`),
  plus le pantin (`pantin`) et la salle des builds (`build_vanilla`, `build_t1`…, situation `arena`).
- `combat/build_tiers.gd` (`BuildTiers`) : paliers de build (Vanilla, Palier 1, 2, 3), cumulés ; à ranger d'après la tier list du site
  (champ `moveideas.tier` = S / A / B / C / D, onglet Atelier des coups → « Tier list »).
- `tools/gen_atelier_moves.gd` : a généré les fiches et poses des coups de l'atelier (déjà lancé ; à garder comme exemple).
  `tools/gen_v011_moves.gd` : poses et fiches des correctifs 0.11 (relançable ; ne change que les champs listés d'une fiche existante).
- `combat/cycles_data.gd` (`CycleData`, **généré**) : cycles et gestes capturés (course, marche, garde au repos, enjambée, roulade,
  atterrissage lourd, relevés et direct des sbires). player.gd : `_run_pose` / `_cyc` / `_clip` / `_track`, `_arm_ik` (mains sur un rebord) ;
  enemy.gd : `to_enemy()` (pose du héros -> sbire), `_gait_pose`, `_punch_pose`, `_start_mocap_up`.
- `tools/cmu/` + `tools/import_cmu.gd` : **animations reprises de captures CMU** (libres de droits, v0.213-0.214). `clips.py` = quel coup vient de
  quelle capture et à quels instants ; `retarget.py` = reprise sur le héros en blocs ; `import_cmu.gd` = poses `cmu_<coup>_<n>` + clés des
  fiches, recalées sur la direction et la portée de l'ancien coup (`old_tips.json`). Mode d'emploi : `tools/cmu/README.md`.
- `tools/audit_anims.gd` : audit chiffré des animations, sans rendu (à-coups, membres sous le sol, pieds qui glissent, rotations > 170°,
  « tout bouge d'un bloc » = pas de cascade ; C = marche/course, D = sbires, B = déplacements de la carte).
- **Style combat anime (v0.215)** : `tools/anime_moves.gd` (relançable, repart de `tools/anime/source.json`) met le mot `anime` sur
  les fiches faites main -> `player._cascade` (chaque articulation joue la fiche avec une avance : bassin d'abord, bras pile à
  l'heure, tête en retard), amplifie × 1,8 les poses des coups (`ax_<coup>_<n>`, visées vers l'ancien point d'impact) et fige
  0,05 s l'impact. Coups capturés : `anime` + `amp` dans `tools/cmu/clips.py`. **Après une retouche de fiche faite main, relancer
  l'outil** (sinon ses poses `ax_` restent les anciennes) ; une nouvelle fiche est prise si on supprime `source.json` (à refaire de zéro).
- `tools/shot_tool.gd` (+ `../shot.sh` hors projet) : rendu d'images d'un coup du labo en vue de profil / dessus / poursuite, pour vérifier une animation.
- États « punitifs » (`PENALTY` dans player.gd : drop_land, sm_land, tackle_slam, pd_land) : rien ne les coupe ; `AIR_LOCKED` : coups aériens
  qu'aucune esquive ne coupe (ils durent jusqu'à la réception).
- `upgrades.gd` (catalogue des améliorations ; `apply()` / `reset()` ; formes `form_*` ; améliorations de bouton ; `FUN` = coups fun gratuits), `run.gd` (Monde 1), `room.gd` (décor procédural), `energy_ball.gd`, `menu_ctl.gd`.

## Ajouter un coup
1. Créer `moves/<id>.tres` (dupliquer une fiche proche), régler les valeurs ; les poses vont dans `moves/poses.tres`.
2. Si le coup a un comportement nouveau, l'écrire dans player.gd derrière un mot de `flags`.
3. Le brancher sur un bouton / une amélioration (player.gd + upgrades.gd), puis l'essayer dans le labo (labo.tscn).
4. Ajouter un test (newcheck.gd ou un nouveau `*check.gd`).

## Atelier des coups (site) → labo
Site : https://claude.ai/artifact/5vMd46RjdgdwLTbSamnN69, collection `moveideas` (statuts existe / idee / tester / retenu / rejete).
On ne code que les « À tester ». « Regarde ce qu'on a ajouté » : lire `moveideas`, coder les nouveaux « tester » (fiche + pose + comportement),
les ajouter à `LaboCatalog.MOVES` et à `labocheck.gd`, puis mettre `lab: true` + `lab_cmd` sur leur carte. Retours de Paul et Thibaud :
collection `feedback` {move, kind animation/bug/ressenti/idee/autre, text, author, done} ; marquer `done: true` une fois corrigé.
Décisions à respecter : pas de différence arrêt / marche (« basique ») ; pas de commande « stick vers soi ».

## Conventions
- Poses : Euler YXZ en degrés ; deux clés successives à moins de 180° d'écart. Le héros regarde vers -Z.
- Couches : sbires debout 2, ragdoll 8, tenus 0 ; joueur 4 ; décor et objets 1 ; héros en ragdoll 16 (masque 1).

## Tests (obligatoires avant de livrer)
Depuis `/home/claude/godot/ragdoll_proto` : `../godot --headless --path . -s <x>check.gd --fixed-fps 120`.
32 suites (`*check.gd`, dont `skincheck.gd` = habillage v0.22, `wallcheck.gd` = course au mur v0.23), chacune finit par `RESULTAT: OK` (`correctcheck.gd` = correctifs 0.11, `editorcheck.gd` = éditeur d'animation, `v021check.gd` = version 0.21, `hubcheck.gd` = salon, `mapcheck.gd` = carte et déplacements, `v0212check.gd` = formes, améliorations, états, coups v0.212, `v0216check.gd` = retours du 23/10, `v0217check.gd` = retours du 23/10 au soir, `v0218check.gd` = bilans de la nuit du 23/10). `varietycheck` et `runcheck` sont
un peu aléatoires : un échec isolé se relance. Lancer les suites 2 par 2 au plus (machine à 2 cœurs). `labcheck.gd` vérifie l'ancienne salle de test, `labocheck.gd` le labo (chaque coup part dans sa situation).
Rendu d'images : xvfb-run + `--rendering-driver opengl3 --rendering-method gl_compatibility`.

## Livraison
Le projet de Paul est sur son PC : `D:\Rogue Doll\ragdoll_proto`. On travaille et on teste ici, puis on écrit les fichiers modifiés
chez lui (pont vers son ordinateur). Pas de terminal sur son PC : il lance Godot lui-même.

## Dépôt du code
Le code complet (projet Godot, sans `.godot/`) est sur GitHub : `fidelcastre44-dev/rogue-doll-code` (clone dans /home/claude/rogue-doll-code).
À chaque version : copier le projet dedans (sans `.godot/`), commit, push. Les builds jouables restent dans `fidelcastre44-dev/rogue-doll`.

## Versions à tester (journal du site)
- Numéro dans `version.gd` (`GameVersion.NUM`), affiché dans le menu pause et le labo. **Règle de Paul** : de simples correctifs
  = 0.11, 0.12… ; on passe à 0.2, 0.3… seulement quand on ajoute vraiment des fonctionnalités.
- Livrer une version : augmenter `NUM`, lancer les tests, exporter (`../godot --headless --path . --export-release "Windows" ../build/RogueDoll.exe`,
  préréglage dans `export_presets.cfg`, modèles 4.7 dans ~/.local/share/godot/export_templates/4.7.stable), zipper en `RogueDoll-vX.Y-windows.zip`,
  le pousser dans le dossier `versions/` du dépôt GitHub `fidelcastre44-dev/rogue-doll` (clone dans /home/claude/rogue-doll, avec un
  `versions/vX.Y-notes.md` ; Claude peut pousser lui-même), lien = `https://github.com/fidelcastre44-dev/rogue-doll/raw/main/versions/RogueDoll-vX.Y-windows.zip`, puis sur le site : un document `versions/<id>` {num, at, title, notes (une ligne par changement)}
  et `config/main` {version, driveUrl = lien Windows, macUrl = lien Mac}.
- **Mac** : préréglage « macOS » (universel, signature ad hoc intégrée, pas de notarisation) : `--export-release "macOS" ../build/RogueDoll-mac.zip`
  (modèle `macos.zip` dans le dossier des modèles 4.7) → `RogueDoll-vX.Y-mac.zip`. Au 1er lancement : clic droit → Ouvrir, ou
  Réglages Système → Confidentialité et sécurité → « Ouvrir quand même ».
- Journal : collection `sessions` {who, version, place, goal, startedAt, endedAt, open, ok, ko, ideas, summary, readByClaude}.
  « Regarde le journal » : lire les sessions avec `readByClaude: false`, corriger, livrer, passer `readByClaude: true`.
- **Journal automatique** : chaque modification faite sur le site est notée seule dans la collection `activity`
  {who, at, col, doc, op create/update/delete, title, changes [{f, from, to}], text, read}. Les « sessions » sont devenues des
  « bilans de test » facultatifs. Quand Paul demande « qu'est-ce qui s'est passé dernièrement ? » : lire `activity` (read: false)
  et `sessions` (readByClaude: false), dire qui a voulu quoi, faire les changements, livrer, puis passer à read / readByClaude: true.
- **Ventiler les idées des sessions** (règle de Paul) : à la lecture du journal, chaque idée ou remarque notée dans les champs
  généraux d'une session (`ideas`, `ok`, `ko`, `summary`) qui parle d'un coup précis doit être reportée sur la carte de ce coup :
  un retour dans `feedback` {move = id de la carte, moveTitle, kind (idee / animation / bug / ressenti), text = la phrase de Paul ou Thibaud,
  author = l'auteur de la session, at, done: false, session = id de la session}, ou une forme / amélioration rattachée (`parent`) si c'en est une.
  Les idées qui ne visent aucun coup (vie, PV max, salles…) vont dans `ideas` (« À trier »). Ne rien inventer : reprendre leurs mots.
- Familles de coups sur le site : `moveideas.kind` (base / forme / amelio) et `moveideas.parent` (id de la carte parente).
- **Animations déposées** (onglet « Animations » du site) : collection `anims` {title, who, at, fileName, game, moves [{id, chosen, versions}],
  summary, data (le fichier JSON en texte), size, integrated, integratedIn}. Chaque dépôt apparaît aussi dans `activity` (col `anims`).
  À la lecture du journal : signaler les dépôts `integrated: false`, et **après l'accord de Paul** écrire `data` dans un fichier, lancer
  `tools/import_anims.gd`, tester, livrer, puis passer `integrated: true` + `integratedIn` (numéro de version).

# Améliorations (coups débloquables)

Chaque fois qu'un coup est remplacé ou qu'une variante est inventée, elle se note ici.
Par défaut, le perso a les **coups de base**. Les autres sont des améliorations à débloquer pendant une partie.

**Pour les essayer :** en jeu, appuie sur **Start** (Tab au clavier), en haut du menu, section « Améliorations ».
(Ou dans l'Inspecteur du nœud Player, réglages indiqués ci-dessous.)

## Esquive (B / Rond) — `dodge_move`

| Valeur | Coup | Statut |
|---|---|---|
| `roll` | **Roulade avant** : tour complet en boule, invulnérable. | base |
| `dash` | **Strafe éclair** : déplacement ultra rapide dans la direction du stick (en arrière sans direction), sans se retourner. Invulnérable. Utilisable une fois en l'air. | amélioration |

## Attaque chargée (Y maintenu) — `charge_move`

Appui court sur Y = le coup lourd normal (inchangé). **Y maintenu** = l'attaque chargée, si tu en as débloqué une : il charge sur place ; **plus tu charges, plus elle est puissante** ; chargée au max, **elle part toute seule**.

| Valeur | Coup | Statut |
|---|---|---|
| `none` | Pas d'attaque chargée. | base |
| `power` | **Coup lourd chargé** (v0.11, remplace le « chassé chargé ») : la version chargée du coup lourd en place (chassé, high kick, retourné, axe kick, frappe au sol) ; jusqu'à 2× plus fort ; au max, il passe la garde et met au sol. | amélioration |
| `shoryu` | **Shoryuken** : il se ramasse poing au sol ; relâché chargé = il jaillit tout droit, l'ennemi monte collé au poing et est lâché au sommet. | amélioration |
| `hadoken` | **Boule d'énergie** : la boule grossit entre ses mains (~1 s) ; relâchée chargée = elle part et balaie tout sur sa ligne. | amélioration |

## Sprint

**Sprint** (de base) : clic du stick gauche (L3, Ctrl au clavier) ou **double tap du stick** dans une direction. Il dure tant que tu pousses le stick ; course bien plus rapide, buste penché en avant.

### Attaque en sprint (X pendant le sprint) — `sprint_attack`

| Valeur | Coup | Statut |
|---|---|---|
| `none` | Rien de spécial (X = combo normal). | base |
| `slide` | **Tacle glissé** (tacle de foot) : il glisse loin en ligne droite, couché sur la hanche, jambe tendue au ras du sol ; fauche **tous** les sbires sur sa ligne, même en garde. Invulnérable au départ. | amélioration |
| `flop` | **Plongeon pantin** : temps d'arrêt, il plie les jambes, puis se jette en avant ; son corps devient un **vrai ragdoll** (rotation au hasard à chaque fois) qui fauche tous les sbires qu'il percute ; il se relève là où il est tombé. | amélioration |

## Coup lourd au sol (Y / Triangle) — `heavy_move`

| Valeur | Coup | Statut |
|---|---|---|
| `kick` | **Chassé** : jambe tendue devant, bras en arrière. | base |
| `hikick` | **High kick latéral façon boxe thaï** : le buste plonge, la jambe passe à hauteur de tête. L'envoie sur le côté. | amélioration |
| `spinkick` | **Coup de pied retourné au visage** : tour complet, dos à l'ennemi, talon à hauteur de tête. L'envoie loin en arrière. | amélioration |
| `axe` | **Axe kick en salto avant** : il saute, s'enroule et fait un tour complet vers l'avant ; la jambe passe par-dessus et s'abat **talon en premier**. Debout, l'ennemi est écrasé à plat au sol ; en l'air, il est smashé au sol. | amélioration |
| `quake` | **Frappe au sol** : sans sauter, poing levé au ciel puis abattu dans le sol ; même onde de choc (zone) que le plongeon. | amélioration |

## Coup lourd en l'air (Y en l'air)

| Entrée | Coup |
|---|---|
| Y | **Chassé sauté** à deux pieds (vrille puis détente). |
| Y maintenu | **Coup de pied en piqué** : il fond en diagonale vers le sol, pied tendu ; touche tout jusqu'au sol, et fait rebondir en l'air les sbires couchés. Tu rebondis sur eux. |

## Attaque légère sautée (X / Carré en l'air) — `air_move`

| Valeur | Coup | Statut |
|---|---|---|
| `jab` | **Combo aérien** (v0.11, remplace les « 3 jabs ») : le combo du sol en l'air — jab, direct, puis le 3e coup s'il est débloqué (uppercut, crochet ou genou volant, version aérienne) ; chaque coup fait remonter l'ennemi (jongle). | base |
| ~~`hammer`~~ | ~~**Marteau à deux mains**~~ : retiré du poing en l'air ; son geste sert maintenant au **plongeon**. | retiré |

## Chope (R1) — `throw_move`

| Valeur | Coup | Statut |
|---|---|---|
| `slam` | (fracas : son corps percute les autres sbires là où il s'écrase ; délai de 1 s entre deux chopes : pas de spam ; chopé **debout**, il se libère au bout de **1,5 s** et retombe sur ses pieds ; chopé **au sol / sonné**, tu le gardes **4 s**) **Par le col** (debout, au sol ou en l'air) : relevé et tenu ; X = droites (la 3e le renvoie en l'air), rappui R1 = fracas au sol. | base |
| `swing` | **Grand tour** : sur un ennemi en ragdoll (au sol ou en l'air), attrapé par les chevilles. **R1 maintenu** : il tourne tout seul, et faire des cercles au stick accélère la rotation (cercles dans l'autre sens = il change de sens) ; son corps s'envole et percute les autres. **R1 relâché** (ou au bout de 3 s) : il part avec ta vitesse de rotation et prend le coup en touchant le sol. | amélioration |
| `throw` | **Lancer visé** : chope par le col ; **R1 maintenu** = élan automatique (il passe derrière ton épaule, jusqu'à 0,9 s), tu vises en tournant au stick ; **R1 relâché** = lancé devant toi comme un boulet, d'autant plus loin que l'élan est long ; en vol il percute les autres sbires, et prend le coup en touchant le sol. | amélioration |
| ~~`club`~~ | ~~**Massue humaine**~~ (abandonnée, voir plus bas) : **R1 maintenu** = attrapé par les pieds (debout, il bascule), tu marches en le traînant ; **X** = tu l'abats par-dessus ta tête devant toi, son corps percute les sbires (et prend un coup lui aussi) ; **R1 relâché** = tu le lâches. | amélioration |

**Objet porté** (v0.21) : X = lancé droit devant, Y = fracassé devant lui ; il marche en le portant.

Dans **toute chope par le col** (de base) : **Y = coup de tête** : il le lâche au moment de l'impact, l'ennemi part en arrière et rebondit au sol.

## Modificateurs (cumulables) — cases à cocher dans le menu

| Réglage | Effet |
|---|---|
| `double_jump` | **Double saut en salto avant** : A en l'air = 2e saut, il fait un tour complet en boule. |
| `air_slam` | **Chope plongeante** : R1 en l'air attrape l'ennemi en vol, l'emporte en piqué et le plaque au sol (il rebondit). Sans elle, **pas de chope en l'air**. |
| `dive` | **Plongeon** : A en l'air (après le double saut s'il y en a un) = geste du marteau (corps en arc, bras tendus, il charge suspendu), il pique vers le sol et **abat ses deux poings dans le sol** : onde de choc (anneau au sol) qui fait décoller les sbires autour. |
| `parry` | **Parade** (L1) : garde levée juste avant le coup (fenêtre de 0,35 s) = aucun dégât, l'attaquant est **sonné** ~1,3 s. |
| `riposte` | **Riposte critique** : le coup donné juste après une parade est critique (×2, passe la garde, met au sol). |
| `guard_gauge` | **La garde remplit la jauge de spécial** à chaque coup paré. |
| `tackle_up` | **Plaquage** (v0.21, était de base) : R1 en plein sprint, il fonce épaule en avant, emporte le premier sbire et plonge avec lui au sol ; distance réduite. |
| `counter_triple` | **Contre tournant triple** (v0.11) : le revers tournant de sortie de roulade fait 3 tours ; chaque tour retouche. |
| `air_dodges` = 2, puis 3 | **Double / triple esquive aérienne** (v0.11, paliers) : 2 puis 3 petits dashs par saut au lieu d'un. |

**Jauge de spécial** (barre jaune sous ta vie) : se remplit en frappant, en parant (parade), et en gardant avec le modificateur. Le spécial sur R2 reste à faire.

## Coup bas (X maintenu, de base)

**Balayage retourné** : accroupi, jambe tendue au ras du sol, tour complet sur lui-même. Fauche l'ennemi de côté, même en garde (coup bas). Invulnérable. Pas de spam : il va au bout de sa rotation, puis petit délai.

Amélioration `sweep_triple` (case à cocher) : **balayage triple**, 3 tours sur lui-même au lieu d'un (chaque tour peut refaucher) ; depuis la v0.11, on se déplace au stick à vitesse de marche pendant les 3 tours, pour aller faucher les autres.

## Combo de poings (X)

Le 3e coup du combo (uppercut, crochet ou genou volant) est un **brise-garde** : il passe la garde.
 — `light_move`

| Valeur | Coup | Statut |
|---|---|---|
| `base` | **Jab + direct + uppercut** (v0.21, l'uppercut est devenu de base) : les jabs bloquent le sbire sur place (presque pas de recul), l'uppercut le lance en l'air (jongle). Le jab s'aimante un peu sur un sbire tout proche, presque droit devant. | base |
| ~~`upper`~~ | ~~Uppercut en amélioration~~ : il fait maintenant partie du combo de base (v0.21). | — |
| `hook` | **Jab + direct + crochet** : armé exagéré, bassin et buste vrillés loin en arrière, puis le bassin pivote d'un coup et le poing balaie à plat ; l'ennemi part sur ta droite et tombe. | amélioration |
| `knee` | **Jab + direct + genou volant** : 3e coup, il décolle en mettant le genou ; l'ennemi part en l'air avec lui → enchaîne directement en aérien. | amélioration |

En l'air (v0.21) : le 3e coup suit l'amélioration (crochet aérien, genou aérien, sinon uppercut aérien). Les coups aériens suivent la courbe du saut
(on peut frapper en montant comme en descendant) et chaque coup qui touche fait rebondir le héros vers le haut.

## Le héros : look

Retour au perso en blocs bleus (look de base, sans habillage). Le look « Remontoir » (jouet en fer-blanc, `hero_look.gd`) et le boxeur modélisé dans Blender sont abandonnés.

## Système de coups et salle de test
Chaque coup est une fiche dans `moves/` (un fichier `.tres` par coup, 44 fiches) : durées, zone de frappe, dégâts, force, effets, poses clés.
On les règle dans l'inspecteur de Godot sans toucher au code. Les poses sont dans `moves/poses.tres`. Le portage est exact :
les 44 coups et les 70 poses sont identiques à l'ancien code, et les 18 suites de tests passent.

Salle de test : ouvrir `move_lab.tscn` et la lancer (F6). Liste de tous les coups (double-clic = le héros le joue face au mannequin),
mannequins libres / immobiles / en garde / en l'air / au sol (ils reviennent tout seuls dans l'état choisi et ne meurent jamais),
ralenti ×0.5 / ×0.25 / ×0.1, pause et image par image, zone de frappe affichée, frise des durées en images, journal des dégâts.
F5 recharge les fiches : on modifie un coup dans l'inspecteur, on enregistre, F5, on rejoue.
Les coups aériens se testent sur le mannequin « en l'air » ; les prises (chopes, objets) se jouent à la manette.

## Déplacements et aimantation

L'aimantation (se tourner tout seul vers l'ennemi, s'en approcher, rester collé à lui en l'air) est **désactivée** (`lock_on`, code gardé). À la place, chaque coup donne une **petite avancée dans la direction où tu te déplaces** ; les déplacements sont libres. Seule la chope se tourne encore vers un sbire tout proche.

## Chope sur les objets

Toutes les chopes marchent sur les objets du décor (tables, chaises, bancs, poubelles, caisses, tonneaux) quand aucun sbire n'est à portée : **chope de base** = soulevé au-dessus de la tête, rappui sur R1 = lancé droit devant toi ; **lancer visé** = élan puis lancé loin ; **grand tour** = il tourne au bout de tes bras et fauche les sbires, relâché il part. Un objet lancé percute les sbires sur son passage.

## Monde 1 (la partie)

Au lancement du jeu : **8 salles** à la suite (2, 2, 3, 3, 4, 4, 5, 5 sbires). Chaque salle a un décor tiré au hasard. Quand tous les sbires sont morts (en partie, ils ne réapparaissent pas), le jeu se met en pause et propose **3 améliorations au hasard** parmi celles que tu n'as pas (chaque carte explique le coup et dit ce qu'il remplace) ; tu en prends une, tu récupères 30 de vie, salle suivante. K.O. = on recommence le monde avec les coups de base. Salle 8 nettoyée = monde terminé. Le catalogue et les explications de tous les coups sont dans `upgrades.gd` ; la liste de tes coups actuels est en haut du menu pause (Start). Le menu pause permet toujours de tout changer à la main (pour tester).

## Décor

À chaque pièce (Select, ou « Nouvelle pièce » dans le menu), un décor tiré au hasard : taille de la pièce, murets, couleur du sol, tapis, piliers, et des objets physiques posés un peu partout — tables, poubelles, caisses, tonneaux, chaises, bancs (groupe `reactive`, meta `kind`). Ils laissent libres les places du joueur et des sbires. Les interactions (tête sur la table, jeté dans la poubelle…) viendront plus tard.

## Coups de l'atelier (« À tester » sur le site) — jouables dans le labo (F2)
- X : contre tournant (X juste après une roulade), coup de chaise (X avec un objet en main ; avant, X ne faisait rien de spécial).
- Y : drop kick (Y en sprint), retourné capoeira (Y après une roulade), shoot de foot (sbire couché devant), course au mur salto (stick vers un mur proche + Y), course au mur horizontale (mur sur le côté, stick le long du mur + Y), shoot d'objet (objet au sol devant), bicyclette (forme du Y aérien `air_heavy`, remplace le chassé sauté quand elle est choisie).
- R1 : plaquage (sprint + R1), suplex (chope + B), prise de catch (chope + A), râpe à fromage (chope près d'un mur + R1), objet-bouclier (objet en main, R1 maintenu ; appui court = lancer), projection de hanche (R1 sur un sbire en garde : remplace la chope normale dans ce cas).
- B : esquive aérienne pour toutes les esquives (une par saut). A : trampoline (retomber sur un sbire couché), super saut (A maintenu).
- X + Y ensemble : superman punch.
- Adaptations aux décisions du site : plaquage « en marchant » → en sprint (plus de différence arrêt / marche) ; suplex « stick vers soi » → B pendant la chope (pas de stick vers soi).

## Version 0.11 (correctifs du 22/10)

- **Supprimés** : rafale de poings (X martelé), moulinet de jambes (Y martelé) et toute la catégorie « appuis rapides » ; poing marteau (X sur un sbire couché : c'est de nouveau un jab). Fiches gardées dans `moves/` (`rush`, `rush_end`, `leg_mill`, `hammer_fist`) mais plus branchées.
- **Drop kick** : il retombe sur le dos et y reste 2 s ; plus rien ne l'annule (roulade, saut, coups, garde, et même un coup reçu ne le relève pas). Avant, la chute s'annulait quand le coup se terminait en l'air.
- **Superman punch** : punitif, il retombe à plat ventre puis se relève vite (`sm_land`).
- **Plaquage** : il court vraiment (jambes animées) en portant le sbire, puis plonge et reste couché sur lui au sol avant de se relever en poussant ; le sbire est plaqué (presque sans rebond).
- **Projection de hanche** : le héros pivote d'un demi-tour (dos au sbire), le charge sur sa hanche ; le sbire passe par-dessus lui, fait un tour et retombe sur le dos de l'autre côté.
- **Prise de catch** : bras enroulé autour du cou, saut ; en l'air le héros se couche à l'horizontale pieds devant et force le sbire à se coucher dans l'autre sens (sur le dos, tête vers l'avant), puis tous deux s'écrasent.
- **Bicyclette** : retournée acrobatique, couché en l'air, la jambe passe par-dessus en arc latéral ; elle touche tout le long de l'arc (avant, le coup ne touchait jamais : une valeur manquait dans sa fiche).
- **Course au mur horizontale** (`wall_run_h`, nouvelle) : le long d'un mur tout proche sur le côté, stick dans le sens du mur + Y : il court à l'horizontale sur le mur en fauchant ceux qu'il croise, puis se repousse en coup de pied sauté. La course au mur d'avant reste (stick vers le mur + Y) : c'est la « course au mur salto ».
- **Super saut → chope plongeante** (synergie) : du haut du super saut, R1 (avec la chope plongeante) = il plonge sur le sbire visé au stick et l'écrase au sol. Les coups aériens peuvent aussi couper le super saut et le trampoline.
- **Micro-animations** : au repos, le héros respire, sautille sur ses appuis, bouge la tête et les poings.

## Version 0.2 : éditeur d'animation (F3)

Pour Thibaud : F3 ouvre l'éditeur (F2 = labo pour essayer, Échap = jeu). On choisit un coup (mêmes noms que le labo), on attrape un membre
du héros à la souris pour le tourner (ou curseurs X / Y / Z), on ajoute / supprime / déplace les poses clés sur la frise (le rythme),
on choisit la courbe entre deux clés, on lit en boucle, au ralenti ou image par image, avec la pelure d'oignon et un sbire en face.
Chaque coup peut avoir plusieurs **versions nommées** ; celle qui est **cochée** est celle que le jeu utilise, tout de suite.
« Tout exporter » crée un fichier à déposer sur le site (onglet Animations). Les coups calculés par le code (roulade, balayage,
tacle glissé, strafe, course) ne sont pas encore modifiables dans l'éditeur.

## Version 0.21 (bilans de Thibaud du 22/10)

Correctifs : la boule d'énergie disparaît si on est touché pendant la charge ; un coup aérien ne peut plus laisser le héros figé ;
les sbires ne restent plus coincés sur un objet (ils se relèvent à côté) ; la roulade n'est plus spammable ; sprint moins rapide (×1,4).
Jab sans élan (on n'avance plus en le martelant), plaquage plus court, combo de base jab / direct / uppercut, plaquage en amélioration,
objet porté X / Y, caméra dynamique (plus près quand on est seul, recule quand les sbires sont dispersés autour, avec une limite).
Labo : **pantin d'entraînement** (salle libre) et **salle des builds** (Vanilla, Palier 1, 2, 3 : `combat/build_tiers.gd`, une
première répartition des améliorations à corriger d'après la **tier list** du site).

## Version 0.211 : le salon

Au lancement, on arrive dans un petit salon où l'on se déplace avec le héros. Près d'un objet, RB (L au clavier) : punching-ball = labo
des coups, établi = salle des paliers (choix Vanilla, Palier 1, 2, 3), ordinateur = éditeur d'animation, porte = run classique.
Le labo, l'éditeur et la run (menu pause, écran K.O. / victoire) ramènent au salon.

## Version 0.212 : Terrain d'essai, formes, améliorations de bouton, états

**Nouvelle carte de test « Terrain d'essai »** (labo et salle des paliers ; la run classique ne change pas) : grand escalier et rampe
vers une plateforme de 2 m (bord dégagé), blocs de 0,4 / 1 / 2 / 3 m, bloc de 2 m seul, deux longs murs en L (courses au mur, coin),
muret 0,9 m, rambarde 1,1 m, barrière haute à glisser dessous, piliers, tables cassables, objets à ramasser, zone plate au centre.

**Déplacements** (seulement sur la carte de test, réglage `terrain`) : marche automatique (≤ 0,4 m) ; enjamber muret / rambarde
(auto en sprint, ou A) ; se hisser sur un bloc de 1 m ; s'agripper au rebord d'un bloc de 2 m puis se hisser (A ou stick) ou lâcher (B) ;
glissade dans l'escalier ou sur la pente (B maintenu en descendant, sprint + B = prolongée), qui fauche ; glisser sous la barrière
(sprint + B) ; grande chute : B juste avant le sol = réception roulée, sinon atterrissage lourd ; bonus de chute (coup aérien jusqu'à ×2
en tombant d'un rebord) ; rebond mural (esquive contre un mur). Les sbires suivent le sol, contournent ce qui est trop haut, tombent
des rebords (dégâts selon la hauteur), et le plaquage dépend de ce qu'on percute (mur = le dos casse, table = elle vole en éclats).

**Formes débloquables** : Vanilla = seulement les coups de base. Drop kick, retourné capoeira, contre tournant, super saut, bicyclette,
toile d'araignée, la vague (et tacle / plongeon pantin, 3e coup, plaquage, grand tour) sont des loots. **Plongeon** et **double saut en
salto** sortent du jeu de base (améliorations du saut). Règle : une forme choisie, plus de forme concurrente proposée pour ce coup.
Paliers refaits (`combat/build_tiers.gd`).

**Améliorations de bouton** (un loot = un bouton, tiré parmi ceux autorisés) : Augmentation d'impact (X, Y), Triple Tour (X : balayage
et contre tournant à 3 tours), Renvoi (X, Y, L1, B), Défense (R1 : ennemi ou objet tenu = bouclier, 3 coups ; chope 2× plus longue),
Tazer (X, Y, L1, B), Électrification de zone. **États** : Électrifié (convulse, tombe, dégâts) ; système prévu pour d'autres états.

**Coups « À tester »** : renvoi de projectile (parade pile au bon moment ; sbire tireur dans le labo), désarmer (parade puis X ; sbire
armé d'un bâton), la vague (L1 + X), toile d'araignée (R1 sans personne à portée), pas de côté (B sans stick, contre critique),
tomoe nage (chope + B, en variante : chope + B reste le suplex par défaut), pluie d'objets (R2, I au clavier). Course au mur : une seule carte
(face au mur / le long du mur). **Coups « fun »** : nouvelle catégorie (donnés gratuitement, pour rire) ; premier : le Trampoline.

**Caméra** : plus proche (elle ne recule plus avec la taille de la fenêtre), beaucoup plus stable, zoom réglable (labo et menu pause).

## Version 0.213 : animations reprises de vraies captures (CMU)

Le **jab**, le **direct**, le **chassé**, le **shoot de foot** et le **shoot d'objet** sont rejoués d'après des captures de mouvement
de la base CMU (libres de droits ; outils dans `tools/cmu`). Même rythme, même portée et même direction qu'avant : seul le geste change.
Les anciennes poses (jab, cross, kick, sk2_*) restent dans poses.tres (d'autres coups s'en servent).
Pas repris, à retravailler avec la même méthode : **high kick** (le nôtre, exagéré, plonge le buste sous la jambe), crochet, uppercut,
se hisser sur un rebord, glissade, atterrissages, coups aériens.

## Version 0.214 : tout en vraies captures (CMU), sbires compris

- **Rythme** : les coups repris (jab, direct, chassé, high kick, shoots, crochet, uppercut) suivent la capture jouée 2× plus vite
  (avant : 3 à 4× plus vite). Ils sont donc plus lents qu'avant (le jab touche en 0,13 s au lieu de 0,06 s).
- **Portée** : le pas ajouté pour garder l'ancienne allonge est retiré (geste pur) ; jab et direct ont une zone de frappe un peu plus grosse.
- **High kick** : capture 135_07 (moins exagéré : la tête ne plonge plus sous la jambe).
- **Course, marche** : cycles capturés, les pieds ne patinent plus ; **garde au repos** : rebonds d'un boxeur capturé.
- **Roulade** (esquive, réception roulée) : capturée, 0,64 s au lieu de 0,5 s (même distance).
- **Enjambée** et **atterrissage lourd** capturés ; **se hisser** : mains posées sur le rebord (IK des bras), pieds posés sur le dessus.
- **Glissade** : accroupi de côté (retour de Paul), pied droit devant.
- **Relevés** (plongeon pantin, superman punch, prise de catch, drop kick) : capturés, 3× plus vite que la capture (plus longs qu'avant).
- **Sbires** : marche et course capturées (pas de côté, recul), direct capturé (armé du jeu gardé : il prévient), relevé capturé
  à plat ventre ou sur le dos (remplace la boule + roulade arrière).
- Pas de capture qui corresponde : coup de pied retourné, lancers d'objet (la capture lance une balle à une main), parade,
  ramasser, coups aériens, prises : restent faits main.

## Version 0.215 : style combat anime

- **Coups capturés** (jab, direct, chassé, high kick, crochet, uppercut, shoots) : amplitude × 1,8 (écart à la garde) et rythme anime :
  armé lisible, frappe sèche en 3-4 images, pose figée 0,05 s à l'impact, retour amorti. Le chassé touche en 0,14 s (0,27 avant).
  La frappe est revisée vers l'ancien point d'impact (le chassé va plus loin et plus haut, façon anime).
- **Animations faites main** (71 fiches) : cascade (le bassin part en avance, puis buste, épaules, le bras arrive pile à l'impact,
  la tête suit) ; les 42 coups (frappes, prises, lancers, aériens) ont leurs poses amplifiées × 1,8 et le figé de 0,05 s
  (outil `tools/anime_moves.gd`, relançable ; clés d'origine dans `tools/anime/source.json`).

## Problèmes notés (à régler plus tard)

- **Chope plongeante** : en pratique on n'a presque jamais d'ennemi en l'air à attraper, sauf après un shoryuken ou un lanceur ; souvent on l'a débloquée sans rien pour faire décoller les ennemis. Pistes : la proposer seulement si on a un lanceur, la rendre possible sur un ennemi debout (saut + R1 = il l'emporte), ou donner un petit lanceur de base.

## Idées notées, pas encore faites

- **Amélioration passive : rebonds amplifiés** : tous les rebonds au sol déclenchés par tes attaques montent plus haut (fracas, coup de tête, axe kick, chutes). Se brancherait sur `bounce` et `ground_bounce` de l'ennemi.
- **Arme : câble électrique** arraché du décor, il devient un fouet.
- **Boss sniper** : posté en hauteur, il tire sur le joueur ; on doit **renvoyer ses balles en les frappant** pour l'atteindre.

## Essayées puis abandonnées

- **Objet-bouclier** (R1 maintenu avec un objet) : passé en Rejeté sur le site, retiré en v0.212 ; remplacé par l'amélioration Défense (R1).
- **Balayage triple** et **contre tournant triple** : remplacés en v0.212 par l'amélioration de bouton Triple Tour (sur X).
- **Plongeon** et **double saut en salto** de base : devenus des améliorations du saut (v0.212).

- **Coup de coude** (3e coup du combo) : retiré.
- **Massue humaine** (chope par les pieds, X = coups de massue avec le corps) : pas pratique, difficile de viser. Le code reste en réserve.
- **Rafale de poings** (X martelé), **moulinet de jambes** (Y martelé) : supprimés en v0.11 (catégorie « appuis rapides » abandonnée).
- **Poing marteau** (X sur un sbire couché) : supprimé en v0.11.
- **Chassé chargé** : remplacé en v0.11 par le coup lourd chargé (la version chargée du coup lourd en place).
- **Poing aérien en 3 jabs** : remplacé en v0.11 par le combo du sol en l'air.
- **Charge dirigée sur Y** (Y maintenu, le stick choisissait chassé / side kick / uppercut, critique au relâcher) : trop confus en jeu.

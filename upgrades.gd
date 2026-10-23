extends RefCounted
## Catalogue des coups : ceux de base, et toutes les améliorations qu'on débloque en fin de salle.
## Une amélioration de « forme » remplace le coup du même bouton ; un « modificateur » s'ajoute (cumulable).

## Coups de base (toujours là) — affichés dans la liste des coups.
const BASE := [
	["Poing (X)", "Jab, direct, jab, uppercut. Les jabs bloquent l'ennemi sur place ; l'uppercut le lance en l'air, puis petit temps de récupération. Un appui pendant un coup est gardé en mémoire : le suivant part dès que le précédent a touché."],
	["Tacle glissé (X en sprint)", "En sprint, X : coup de pied glissé au ras du sol qui fait tomber tous ceux qu'il touche."],
	["Poing en l'air (X en l'air)", "Le combo du sol, en l'air : jab, direct, uppercut (ou le 3e coup débloqué) ; chaque coup qui touche te fait rebondir vers le haut avec l'ennemi (jongle)."],
	["Balayage retourné (X maintenu)", "Accroupi, jambe tendue au ras du sol, il tourne sur lui-même et fauche de côté, même en garde. Invulnérable pendant la rotation."],
	["Coup lourd (Y, appui court)", "Chassé : jambe tendue devant, l'ennemi part en arrière."],
	["Gros genou (Y en l'air)", "Gros coup de genou aérien qui garde l'élan du saut : l'ennemi monte, on enchaîne le combo aérien."],
	["Coup de pied en piqué (Y maintenu en l'air)", "Il fond en diagonale vers le sol ; touche tout jusqu'au sol et fait rebondir en l'air les ennemis couchés."],
	["Chope (R1)", "Par le col, debout ou au sol. X = droites (la 3e le renvoie en l'air), Y = coup de tête (lâché, il rebondit au sol), R1 = fracas au sol (son corps percute les autres ennemis là où il s'écrase). Chopé debout, il se libère au bout de 1,5 s ; chopé au sol, tu le gardes 4 s. Marche aussi sur les objets (table, chaise, banc, poubelle...) : soulevé au-dessus de la tête, rappui sur R1 = lancé droit devant toi."],
	["Garde (L1)", "Bloque tout ce qui vient de devant et des côtés."],
	["Esquive (B)", "Roulade avant, invulnérable ; coupable très tôt par n'importe quelle action. En l'air : petit dash, une fois par saut."],
	["Saut (A)", "Saut simple ; un coup qui touche peut être annulé par un saut pour partir jongler."],
	["Sprint (L3 ou double tap)", "Course bien plus rapide tant que tu pousses le stick."],
]

## Améliorations : [identifiant, réglage du joueur, valeur, nom, emplacement, description]
const LIST := [
	["tackle", "tackle_up", true, "Plaquage", "R1 en plein sprint — s'ajoute", "En sprint, R1 : il fonce épaule en avant, emporte le premier sbire et plonge avec lui au sol ; ceux sur la route sont bousculés."],
	["hook", "light_move", "hook", "Crochet", "3e coup du combo (X)", "Jab, direct, puis un crochet énorme (brise-garde) : le bassin pivote d'un coup, le poing balaie à plat et l'envoie au sol sur ta droite."],
	["knee", "light_move", "knee", "Genou volant", "3e coup du combo (X)", "Jab, direct, puis il décolle avec le genou dans le menton (brise-garde) : vous partez en l'air ensemble, enchaîne en aérien."],
	["hikick", "heavy_move", "hikick", "High kick", "Coup lourd (Y)", "Coup de pied de boxe thaï à hauteur de tête : il balaie l'ennemi sur le côté."],
	["spinkick", "heavy_move", "spinkick", "Coup de pied retourné", "Coup lourd (Y)", "Tour complet, talon au visage : l'ennemi part loin en arrière."],
	["power", "charge_move", "power", "Coup lourd chargé", "Attaque chargée (Y maintenu)", "Garde Y enfoncé : il arme, planté sur place. Relâche : ton coup lourd en place (chassé, high kick, retourné, axe kick, frappe au sol), d'autant plus fort que tu as chargé (jusqu'à 2×) ; chargé au max, il part tout seul, passe la garde et met au sol. Le Y normal (appui court) ne change pas."],
	["axe", "heavy_move", "axe", "Axe kick en salto", "Coup lourd (Y)", "Salto avant, la jambe passe par-dessus et s'abat talon en premier : l'ennemi est écrasé au sol et rebondit haut."],
	["shoryu", "charge_move", "shoryu", "Shoryuken", "Attaque chargée (Y maintenu)", "Garde Y enfoncé : il se ramasse, poing au sol. Relâche : il jaillit tout droit vers le ciel, l'ennemi monte collé au poing et est lâché au sommet pour le jongle ; plus tu as chargé, plus ça monte haut et fort. Au max, il part tout seul. Le Y normal ne change pas."],
	["hadoken", "charge_move", "hadoken", "Boule d'énergie", "Attaque chargée (Y maintenu)", "Garde Y enfoncé : la boule grossit entre tes mains. Relâche : elle part vite et balaie tous les ennemis sur sa ligne ; plus elle est chargée, plus elle est grosse et fait mal. Au max (1 s), elle part toute seule. Le Y normal ne change pas."],
	["quake", "heavy_move", "quake", "Frappe au sol", "Coup lourd (Y)", "Poing levé puis abattu dans le sol : onde de choc qui fait décoller tous les ennemis autour."],
	["swing", "throw_move", "swing", "Grand tour", "Chope (R1)", "Sur un ennemi au sol ou en l'air : attrapé par les chevilles, il tourne autour de toi (accélère avec des cercles au stick) et percute les autres. Relâche R1 pour le lancer. Marche aussi avec les objets du décor."],
	["throw", "throw_move", "throw", "Lancer visé", "Chope (R1)", "R1 maintenu : élan, il passe au-dessus de ton épaule ; vise au stick, relâche : il part en boulet et percute les autres. Marche aussi avec les objets du décor."],
	["dash", "dodge_move", "dash", "Strafe éclair", "Esquive (B)", "Déplacement ultra rapide dans la direction du stick, sans se retourner ; utilisable une fois en l'air."],
	["flop", "sprint_attack", "flop", "Plongeon pantin", "Attaque en sprint (X)", "En sprint, X : il plie les jambes et s'envoie loin en vrai ragdoll, en fauchant tout ce qu'il percute."],
	["double_jump", "double_jump", true, "Double saut", "Saut (A) — s'ajoute", "Un 2e saut en l'air, en salto avant."],
	["dive", "dive", true, "Plongeon", "Saut (A) — s'ajoute", "A en l'air : il arme en arc, pique vers le sol et abat les deux poings : onde de choc autour."],
	["air_slam", "air_slam", true, "Chope plongeante", "Chope en l'air (R1) — s'ajoute", "R1 en l'air : il attrape l'ennemi en vol, l'emporte en piqué et le plaque au sol."],
	# Formes débloquables (v0.212) : déjà en place au début de la run classique (inchangée) ; coupées en Vanilla (salle des paliers).
	["dropkick", "form_dropkick", true, "Coup de pied en course", "Y en plein sprint — se débloque", "En sprint, Y : gros coup de pied sans saut, brise-garde, qui envoie l'ennemi au loin (remplace le drop kick, v0.216)."],
	["capoeira", "form_capoeira", true, "Retourné capoeira", "Y en sortie de roulade — se débloque", "Juste après une roulade : mains au sol, coup de pied tournant bas qui fauche autour."],
	["counter", "form_counter", true, "Contre tournant", "X en sortie de roulade — se débloque", "Juste après une roulade : revers tournant à 360° qui touche tout autour."],
	["superjump", "form_superjump", true, "Super saut", "A maintenu — se débloque", "A maintenu : saut très haut, retombée en onde de choc."],
	["bicycle", "air_heavy", "bicycle", "Bicyclette", "Y en l'air (remplace le gros genou)", "En l'air, retourné acrobatique qui renvoie l'ennemi vers le sol en diagonale."],
	["web", "web", true, "Toile d'araignée", "R1 sans personne à portée — se débloque", "Un fil s'accroche au premier sbire, objet ou mur touché et le ramène (élastique) ; relâche R1 pour le projeter. Marche en l'air."],
	["wave", "wave", true, "La vague", "L1 + X — se débloque", "Il fait la vague avec ses bras : tous les sbires autour sont étourdis."],
	# Améliorations de bouton (v0.212) : la liste donne les boutons possibles ; chaque loot n'en améliore qu'un (tiré au hasard).
	["impact", "btn:impact", ["X", "Y"], "Augmentation d'impact", "Un bouton (X ou Y) — s'ajoute", "Les coups de ce bouton touchent sur une plus grande zone et font plus de dégâts."],
	["triple", "btn:triple", ["X"], "Triple Tour", "Attaques rotatives (X) — s'ajoute", "Toutes les attaques rotatives du bouton tournent 3 fois (balayage, contre tournant) ; chaque tour retouche."],
	["renvoi", "btn:renvoi", ["X", "Y", "L1", "B"], "Renvoi", "Un bouton (X, Y, L1 ou B) — s'ajoute", "L'attaque de ce bouton renvoie les projectiles vers leur tireur."],
	["defense", "btn:defense", ["R1"], "Défense", "Chope (R1) — s'ajoute", "Un ennemi ou un objet tenu sert de bouclier contre les coups et les tirs (il cède au 3e) ; la chope tient 2× plus longtemps."],
	["tazer", "btn:tazer", ["X", "Y", "L1", "B"], "Tazer", "Un bouton (X, Y, L1 ou B) — s'ajoute", "L'attaque de ce bouton électrifie : l'ennemi convulse, tombe et prend des dégâts."],
	["zone", "btn:zone", ["*"], "Électrification de zone", "Tazer — s'ajoute", "Un ennemi électrifié électrifie aussi ceux qui sont autour (demande le Tazer)."],
	["air_dodge2", "air_dodges", 2, "Double esquive aérienne", "Esquive en l'air (B) — s'ajoute", "Deux petits dashs par saut au lieu d'un."],
	["air_dodge3", "air_dodges", 3, "Triple esquive aérienne", "Esquive en l'air (B) — s'ajoute", "Trois petits dashs par saut (demande la double esquive aérienne)."],
	["parry", "parry", true, "Parade", "Garde (L1) — s'ajoute", "Lève la garde juste avant le coup : aucun dégât, l'attaquant est sonné."],
	["riposte", "riposte", true, "Riposte critique", "Garde (L1) — s'ajoute", "Le coup donné juste après une parade est critique : ×2, passe la garde, met au sol."],
	["guard_gauge", "guard_gauge", true, "Garde chargeuse", "Garde (L1) — s'ajoute", "Chaque coup bloqué remplit la jauge de spécial."],
]

## Coups « fun » (v0.212, idée de Paul sur le Trampoline) : presque inutiles, donnés gratuitement pour rigoler
## (jamais à la place d'un coup utile, jamais dans le choix d'améliorations). [réglage, valeur, nom, commande, description]
const FUN := [
	["trampoline", true, "Trampoline", "A, retombe sur un sbire couché", "Il rebondit sur le sbire couché, le sbire rebondit aussi, et il monte de plus en plus haut."],
]

## Valeurs de base (début de partie).
const DEFAULTS := {"light_move": "base", "heavy_move": "kick", "charge_move": "none", "throw_move": "slam", "dodge_move": "roll", "sprint_attack": "slide",
	"double_jump": false, "dive": false, "air_slam": false, "sweep_triple": false, "parry": false, "riposte": false, "guard_gauge": false,
	"counter_triple": false, "air_dodges": 1, "tackle_up": false,
	"form_dropkick": true, "form_capoeira": true, "form_counter": true, "form_superjump": true, "air_heavy": "knee",
	"web": false, "wave": false, "btn_ups": {}}

## Nom du coup actuellement en place sur un emplacement (pour « remplace : … »).
const BASE_NAMES := {"light_move": "Uppercut (3e coup)", "heavy_move": "Chassé", "charge_move": "", "throw_move": "Fracas", "dodge_move": "Roulade", "sprint_attack": "Tacle glissé", "air_heavy": "Gros genou"}


## Remet le héros aux coups de départ de la run (les dictionnaires sont copiés).
static func reset(player: Node) -> void:
	for k in DEFAULTS:
		var v = DEFAULTS[k]
		player.set(k, v.duplicate(true) if typeof(v) == TYPE_DICTIONARY else v)


## Améliorations de bouton : boutons déjà améliorés.
static func _btns(player: Object, u: Array) -> Array:
	return player.btn_ups.get(u[0], [])


## Donne l'amélioration au héros. Amélioration de bouton : un seul bouton, tiré parmi ceux qui restent. Renvoie le bouton (ou "").
static func apply(player: Object, u: Array, force_button := "") -> String:
	if typeof(u[2]) != TYPE_ARRAY:
		player.set(u[1], u[2])
		return ""
	var have: Array = _btns(player, u).duplicate()
	var left := []
	for b in u[2]:
		if not b in have:
			left.append(b)
	if left.is_empty():
		return ""
	var b: String = force_button if force_button in left else left[randi() % left.size()]
	have.append(b)
	var bu: Dictionary = player.btn_ups.duplicate(true)
	bu[u[0]] = have
	player.btn_ups = bu
	if u[0] == "triple" and b == "X":
		player.sweep_triple = true   # balayage retourné et contre tournant : 3 tours
		player.counter_triple = true
	return b


static func find(id: String) -> Array:
	for u in LIST:
		if u[0] == id:
			return u
	return []


## Le joueur l'a-t-il déjà ?
static func owned(player: Node, u: Array) -> bool:
	if typeof(u[2]) == TYPE_ARRAY:
		return _btns(player, u).size() >= u[2].size()   # tous ses boutons sont déjà améliorés
	if typeof(u[2]) == TYPE_INT:
		return player.get(u[1]) >= u[2]   # paliers (esquives aériennes) : le palier 3 contient le 2
	return player.get(u[1]) == u[2]


## Proposable : pas déjà en place, et ses prérequis sont là.
static func available(player: Node, u: Array) -> bool:
	if owned(player, u):
		return false
	if u[0] == "riposte" and not player.parry:
		return false
	if u[0] == "zone" and not player.btn_ups.has("tazer"):
		return false
	# Règle de Paul (v0.212) : une forme choisie pour un coup, le jeu ne propose plus de forme concurrente pour ce coup.
	if typeof(u[2]) == TYPE_STRING and DEFAULTS.has(u[1]) and player.get(u[1]) != DEFAULTS[u[1]]:
		return false
	if typeof(u[2]) == TYPE_INT and player.get(u[1]) < u[2] - 1:
		return false   # palier suivant seulement
	return true


## Ce que ça remplace (vide pour un modificateur ou un emplacement encore vide).
static func replaces(player: Node, u: Array) -> String:
	if typeof(u[2]) in [TYPE_BOOL, TYPE_INT, TYPE_ARRAY]:
		return ""
	var cur = player.get(u[1])
	if cur == DEFAULTS[u[1]]:
		return BASE_NAMES[u[1]]
	for o in LIST:
		if o[1] == u[1] and o[2] == cur:
			return o[3]
	return ""


## Liste lisible des coups en place (base + améliorations prises).
static func loadout(player: Node) -> String:
	var lines := []
	for u in LIST:
		if typeof(u[2]) == TYPE_ARRAY and _btns(player, u).size() > 0:
			lines.append("• %s (%s) : %s" % [u[3], ", ".join(_btns(player, u)), u[5]])
		elif typeof(u[2]) != TYPE_ARRAY and owned(player, u) and not (u[1].begins_with("form_") and DEFAULTS.get(u[1]) == true):
			lines.append("• %s — %s : %s" % [u[3], u[4], u[5]])
	var out := "Améliorations débloquées :\n" + ("\n".join(lines) if lines.size() else "(aucune pour l'instant)")
	out += "\n\nCoups de base :"
	for b in BASE:
		out += "\n• %s : %s" % [b[0], b[1]]
	return out

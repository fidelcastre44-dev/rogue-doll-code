class_name Moves
## Toutes les données des coups du héros, en images (60 par seconde), façon jeu de combat :
##   startup = images avant que le coup touche (l'armé) ; active = images où il peut toucher ; recovery = la récupération.
## Le coup « part » de l'animation `anim` à `from` et l'animation est recalée pour que son instant d'impact (`hit`, en s
## dans l'animation) tombe pile sur la 1re image active ; pendant la récupération elle file jusqu'à `end`.
##
## Champs :
##   dmg, hitstop (images de figé à l'impact, attaquant + cible), stun (images d'étourdissement de la cible),
##   kb = [recul horizontal m/s, vertical m/s], effect : "" | "launch" (en l'air) | "knockdown" (à terre) | "crumple" (s'effondre lentement)
##     | "stagger" (gros recul titubant) | "spike" (écrasé au sol),
##   box = [devant (m), hauteur (m), rayon (m)] (sphère de frappe, repère du héros) ; sweep = la sphère avance pendant les images actives,
##   lunge = élan (m) pendant l'armé + actif ; chain = {bouton: coup suivant} (ouvert dès `chain_from`, appui gardé en tampon),
##   dodge = quand l'esquive peut couper le coup : "always" (dès l'image 0), "active" (dès la fin de l'actif), "hit" (seulement s'il a touché),
##   jump_cancel = saut possible si le coup a touché ; guard_break ; armor (ne bronche pas sous les coups pendant l'armé),
##   shake = secousse caméra (0-1) ; sfx ; air = coup aérien ; hang = vitesse verticale donnée en l'air (reste en l'air).

const M := {
	# ---------------- X : enchaînement léger jab, direct, crochet, coup de pied retourné ----------------
	"jab": {"anim": "jab", "from": 0.05, "hit": 0.20, "end": 0.50, "startup": 5, "active": 3, "recovery": 11,
		"dmg": 4, "hitstop": 4, "stun": 18, "kb": [1.6, 0.0], "box": [0.95, 1.4, 0.5], "lunge": 0.45,
		"chain": {"attack": "cross", "heavy": "launcher"}, "chain_from": 5, "dodge": "always", "shake": 0.12, "sfx": "light"},
	"cross": {"anim": "cross", "from": 0.08, "hit": 0.283, "end": 0.62, "startup": 6, "active": 3, "recovery": 12,
		"dmg": 5, "hitstop": 5, "stun": 20, "kb": [2.0, 0.0], "box": [1.0, 1.4, 0.5], "lunge": 0.6,
		"chain": {"attack": "hook", "heavy": "launcher"}, "chain_from": 6, "dodge": "always", "shake": 0.15, "sfx": "light"},
	"hook": {"anim": "cmu/hook_box", "from": 0.08, "hit": 0.32, "end": 0.62, "startup": 7, "active": 3, "recovery": 13,
		"dmg": 6, "hitstop": 6, "stun": 22, "kb": [2.4, 0.0], "box": [1.0, 1.45, 0.6], "lunge": 0.6,
		"chain": {"attack": "spin_kick", "heavy": "launcher"}, "chain_from": 7, "dodge": "always", "shake": 0.18, "sfx": "light"},
	"spin_kick": {"anim": "cmu/kick_round", "from": 0.05, "hit": 0.375, "end": 0.75, "startup": 11, "active": 4, "recovery": 20,
		"dmg": 12, "hitstop": 11, "stun": 30, "kb": [8.0, 3.5], "effect": "knockdown", "box": [1.15, 1.1, 0.75], "lunge": 0.9,
		"chain": {}, "dodge": "hit", "shake": 0.45, "sfx": "heavy", "slowmo": 0.12},
	# Y pendant l'enchaînement X (ou après une parade) : uppercut qui envoie en l'air -> sauter pour le combo aérien
	"launcher": {"anim": "cmu/uppercut", "from": 0.06, "hit": 0.33, "end": 0.66, "startup": 9, "active": 4, "recovery": 18,
		"dmg": 8, "hitstop": 8, "stun": 40, "kb": [0.3, 11.5], "effect": "launch", "box": [0.9, 1.3, 0.65], "lunge": 0.7,
		"chain": {}, "dodge": "hit", "jump_cancel": true, "shake": 0.3, "sfx": "heavy"},

	# ---------------- Y : coup de pied poussé, puis gros crochet plongeant ; Y maintenu = crochet chargé ----------------
	"push_kick": {"anim": "cmu/kick_front", "from": 0.1, "hit": 0.407, "end": 0.85, "startup": 12, "active": 4, "recovery": 18,
		"dmg": 9, "hitstop": 9, "stun": 34, "kb": [9.0, 1.0], "effect": "stagger", "box": [1.25, 0.95, 0.65], "lunge": 0.7,
		"chain": {"heavy": "haymaker", "attack": "jab"}, "chain_from": 12, "dodge": "active", "guard_break": true, "shake": 0.35, "sfx": "heavy"},
	"haymaker": {"anim": "hook", "from": 0.0, "hit": 0.267, "end": 0.467, "then": "hook_rec", "startup": 14, "active": 4, "recovery": 22,
		"dmg": 14, "hitstop": 12, "stun": 40, "kb": [11.0, 4.0], "effect": "knockdown", "box": [1.2, 1.0, 0.8], "lunge": 2.0,
		"chain": {}, "dodge": "hit", "guard_break": true, "shake": 0.5, "sfx": "heavy", "slowmo": 0.1},
	"charged": {"anim": "hook", "from": 0.0, "hit": 0.267, "end": 0.467, "then": "hook_rec", "startup": 8, "active": 5, "recovery": 24,
		"dmg": 22, "hitstop": 16, "stun": 50, "kb": [16.0, 5.0], "effect": "knockdown", "box": [1.3, 1.0, 0.95], "lunge": 3.0,
		"chain": {}, "dodge": "hit", "guard_break": true, "armor": true, "shake": 0.75, "sfx": "big", "slowmo": 0.18},

	# ---------------- Après une roulade / en sprint ----------------
	"dash_punch": {"anim": "cmu/cross_box", "from": 0.1, "hit": 0.30, "end": 0.57, "startup": 6, "active": 4, "recovery": 14,
		"dmg": 8, "hitstop": 7, "stun": 30, "kb": [7.0, 0.5], "effect": "stagger", "box": [1.0, 1.4, 0.6], "lunge": 2.4,
		"chain": {"attack": "hook", "heavy": "launcher"}, "chain_from": 10, "dodge": "active", "shake": 0.25, "sfx": "light"},
	"slide": {"anim": "slide_start", "from": 0.25, "hit": 0.7, "end": 0.833, "then_loop": "slide_exit", "startup": 6, "active": 14, "recovery": 16,
		"dmg": 7, "hitstop": 6, "stun": 36, "kb": [3.0, 7.5], "effect": "launch", "box": [0.7, 0.35, 0.75], "sweep": true, "lunge": 5.0,
		"chain": {}, "dodge": "active", "jump_cancel": true, "shake": 0.3, "sfx": "heavy", "low": true},
	"flying_hook": {"anim": "hook", "from": 0.0, "hit": 0.267, "end": 0.467, "then": "hook_rec", "startup": 10, "active": 5, "recovery": 20,
		"dmg": 12, "hitstop": 10, "stun": 40, "kb": [12.0, 4.0], "effect": "knockdown", "box": [1.2, 1.0, 0.85], "lunge": 4.0,
		"chain": {}, "dodge": "hit", "shake": 0.45, "sfx": "heavy"},

	# ---------------- En l'air ----------------
	"air_jab": {"anim": "jab", "from": 0.05, "hit": 0.20, "end": 0.45, "startup": 4, "active": 3, "recovery": 10,
		"dmg": 4, "hitstop": 5, "stun": 26, "kb": [1.0, 3.2], "effect": "juggle", "box": [0.9, 1.1, 0.65], "lunge": 0.3,
		"chain": {"attack": "air_cross", "heavy": "air_spike"}, "chain_from": 4, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.12, "sfx": "light"},
	"air_cross": {"anim": "cross", "from": 0.08, "hit": 0.283, "end": 0.55, "startup": 5, "active": 3, "recovery": 11,
		"dmg": 5, "hitstop": 5, "stun": 26, "kb": [1.2, 3.2], "effect": "juggle", "box": [0.95, 1.1, 0.65], "lunge": 0.3,
		"chain": {"attack": "air_kick", "heavy": "air_spike"}, "chain_from": 5, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.14, "sfx": "light"},
	"air_kick": {"anim": "cmu/kick_front", "from": 0.15, "hit": 0.407, "end": 0.75, "startup": 7, "active": 4, "recovery": 14,
		"dmg": 8, "hitstop": 10, "stun": 34, "kb": [3.0, -14.0], "effect": "spike", "box": [1.15, 0.9, 0.8], "lunge": 0.5,
		"chain": {"heavy": "air_spike"}, "chain_from": 9, "dodge": "hit", "air": true, "hang": 1.6, "shake": 0.4, "sfx": "heavy", "slash": "down"},
	"air_spike": {"anim": "cmu/kick_low", "from": 0.1, "hit": 0.342, "end": 0.7, "startup": 8, "active": 30, "recovery": 14,
		"dmg": 10, "hitstop": 10, "stun": 40, "kb": [2.0, -16.0], "effect": "spike", "box": [0.7, 0.4, 0.95], "lunge": 0.4,
		"chain": {}, "dodge": "hit", "air": true, "dive": true, "shake": 0.5, "sfx": "big"},

	# ---------------- Riposte (X juste après une parade) ----------------
	"riposte": {"anim": "cmu/uppercut", "from": 0.06, "hit": 0.33, "end": 0.66, "startup": 5, "active": 4, "recovery": 16,
		"dmg": 14, "hitstop": 14, "stun": 50, "kb": [0.8, 12.5], "effect": "launch", "box": [1.0, 1.3, 0.8], "lunge": 0.8,
		"chain": {}, "dodge": "always", "jump_cancel": true, "shake": 0.55, "sfx": "big", "slowmo": 0.2, "crit": true},
}

# Chope (R1) : pas une frappe, réglages à part.
const GRAB := {"startup": 6, "reach": 1.5, "whiff": 20, "hold": 14, "throw_f": 10, "recovery": 18, "dmg": 10, "kb": [13.0, 4.5]}


static func get_move(id: String) -> Dictionary:
	return M[id]


static func total(m: Dictionary) -> int:
	return m.startup + m.active + m.recovery

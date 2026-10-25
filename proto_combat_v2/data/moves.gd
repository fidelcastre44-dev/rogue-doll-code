class_name Moves
## Fiches des coups (cahier des charges, section 5), en images à 60 / s : startup (armé), active (touche), recovery.
## Chaque coup est défini SUR une animation existante : `anim` (bibliothèque mx/ = Mixamo repris, voir data/anim_list.json),
## `hit` = instant de contact mesuré avec tools/bake/mx_times.gd (pic de vitesse du membre), `end` = fin utile.
## L'affichage coupe le début de l'animation pour que `hit` tombe sur la 1re image active (`from` = hit - armé si absent),
## puis la laisse filer jusqu'à `end` pendant actif + récupération. La zone de frappe `box` = [devant, hauteur, rayon] (m) est
## posée là où est le membre à l'impact dans l'animation (mesuré), `limb` = l'os qui frappe (audit).
## Autres champs : dmg, hitstop (images), stun (images), kb [horizontal m/s, vertical m/s], effect ("" | stagger | knockdown |
## launch | juggle | spike), lunge (m, élan pendant armé + actif), chain {bouton: coup} dès `chain_from`, dodge "always" |
## "active" | "hit", jump_cancel, guard_break, armor, air, hang (vitesse verticale gardée en l'air), dive, low, sweep (la zone
## avance pendant l'actif), shake (0-1), slowmo (s), crit, sfx.

const M := {
	# ---------------- X au sol : jab ▸ direct ▸ coude ▸ coup de pied retourné ; X maintenu = balayette ----------------
	"jab": {"anim": "mx/jab", "hit": 0.28, "end": 0.62, "limb": "hand_l", "startup": 5, "active": 3, "recovery": 11,
		"dmg": 4, "hitstop": 4, "stun": 18, "kb": [1.6, 0.0], "box": [0.75, 1.35, 0.45], "lunge": 0.32,
		"chain": {"attack": "cross", "heavy": "push_kick"}, "chain_from": 5, "dodge": "always", "shake": 0.12, "sfx": "light",
		"hold": "sweep"},
	"cross": {"anim": "mx/cross", "hit": 0.57, "end": 0.95, "limb": "hand_r", "startup": 6, "active": 3, "recovery": 12,
		"dmg": 5, "hitstop": 5, "stun": 20, "kb": [2.0, 0.0], "box": [0.95, 1.2, 0.45], "lunge": 0.42,
		"chain": {"attack": "elbow", "heavy": "launcher"}, "chain_from": 6, "dodge": "always", "shake": 0.15, "sfx": "light"},
	"elbow": {"anim": "mx/elbow", "hit": 0.53, "end": 0.95, "limb": "lowerarm_r", "startup": 7, "active": 3, "recovery": 13,
		"dmg": 6, "hitstop": 6, "stun": 22, "kb": [2.4, 0.0], "box": [0.95, 1.1, 0.5], "lunge": 0.42,
		"chain": {"attack": "spin_kick", "heavy": "launcher"}, "chain_from": 7, "dodge": "always", "shake": 0.18, "sfx": "light"},
	"spin_kick": {"anim": "mx/spin_kick", "hit": 0.95, "end": 1.5, "limb": "foot_r", "startup": 11, "active": 4, "recovery": 20,
		"dmg": 12, "hitstop": 11, "stun": 30, "kb": [8.0, 3.5], "effect": "knockdown", "box": [0.95, 1.3, 0.65], "lunge": 0.63,
		"chain": {}, "dodge": "hit", "shake": 0.45, "sfx": "heavy", "slowmo": 0.12, "sweep_dir": 1},
	"launcher": {"anim": "mx/uppercut", "hit": 0.47, "end": 0.95, "limb": "hand_l", "startup": 9, "active": 4, "recovery": 18,
		"dmg": 8, "hitstop": 8, "stun": 40, "kb": [0.3, 11.5], "effect": "launch", "box": [0.75, 1.25, 0.6], "lunge": 0.7,
		"chain": {}, "dodge": "hit", "jump_cancel": true, "shake": 0.3, "sfx": "heavy", "sweep_dir": -1},
	"sweep": {"anim": "mx/sweep", "hit": 0.8, "end": 1.35, "limb": "foot_r", "startup": 8, "active": 4, "recovery": 18,
		"dmg": 6, "hitstop": 6, "stun": 30, "kb": [3.0, 2.0], "effect": "knockdown", "box": [0.7, 0.3, 0.65], "lunge": 0.3,
		"chain": {}, "dodge": "hit", "low": true, "shake": 0.3, "sfx": "heavy", "sweep_dir": 1},

	# ---------------- Y au sol : coup de pied poussé ▸ gros crochet ; Y maintenu = coup chargé ----------------
	"push_kick": {"anim": "mx/bencao", "hit": 0.5, "end": 1.0, "limb": "foot_r", "startup": 12, "active": 4, "recovery": 18,
		"dmg": 9, "hitstop": 9, "stun": 34, "kb": [9.0, 1.0], "effect": "stagger", "box": [0.9, 0.95, 0.55], "lunge": 0.7,
		"chain": {"heavy": "haymaker", "attack": "jab"}, "chain_from": 12, "dodge": "active", "guard_break": true, "shake": 0.35, "sfx": "heavy",
		"hold": "charged"},
	"haymaker": {"anim": "mx/hook_rear", "hit": 0.62, "end": 1.15, "limb": "hand_r", "startup": 14, "active": 4, "recovery": 22,
		"dmg": 14, "hitstop": 12, "stun": 40, "kb": [11.0, 4.0], "effect": "knockdown", "box": [0.85, 1.05, 0.6], "lunge": 2.0,
		"chain": {}, "dodge": "hit", "guard_break": true, "shake": 0.5, "sfx": "heavy", "slowmo": 0.1, "sweep_dir": -1},
	"charged": {"anim": "mx/hook_rear", "hit": 0.62, "end": 1.15, "limb": "hand_r", "startup": 8, "active": 5, "recovery": 24,
		"dmg": 22, "hitstop": 16, "stun": 50, "kb": [16.0, 5.0], "effect": "knockdown", "box": [0.9, 1.05, 0.75], "lunge": 3.0,
		"chain": {}, "dodge": "hit", "guard_break": true, "armor": true, "shake": 0.75, "sfx": "big", "slowmo": 0.18, "sweep_dir": -1,
		"charge_anim": "mx/hook_rear", "charge_t": 0.3},

	# ---------------- Après une roulade / en sprint ----------------
	"dash_punch": {"anim": "mx/cross_2", "hit": 0.98, "end": 1.4, "limb": "hand_r", "startup": 6, "active": 4, "recovery": 14,
		"dmg": 8, "hitstop": 7, "stun": 30, "kb": [7.0, 0.5], "effect": "stagger", "box": [0.85, 1.35, 0.55], "lunge": 2.4,
		"chain": {"attack": "elbow", "heavy": "launcher"}, "chain_from": 10, "dodge": "active", "shake": 0.25, "sfx": "light"},
	"slide": {"anim": "mx/low_spin", "hit": 1.15, "end": 1.73, "from": 1.0, "limb": "foot_r", "startup": 6, "active": 14, "recovery": 16,
		"dmg": 7, "hitstop": 6, "stun": 36, "kb": [3.0, 7.5], "effect": "launch", "box": [0.9, 0.7, 0.7], "sweep": true, "lunge": 5.0,
		"chain": {}, "dodge": "active", "jump_cancel": true, "low": true, "shake": 0.3, "sfx": "heavy", "sweep_dir": 1},
	"slide_kick": {"anim": "mx/slide", "hit": 0.45, "end": 1.4, "from": 0.3, "limb": "foot_l", "startup": 6, "active": 14, "recovery": 16,
		"dmg": 8, "hitstop": 7, "stun": 36, "kb": [4.0, 2.0], "effect": "knockdown", "box": [0.8, 0.4, 0.7], "sweep": true, "lunge": 5.0,
		"chain": {}, "dodge": "active", "low": true, "shake": 0.3, "sfx": "heavy"},
	"big_kick": {"anim": "mx/flying_kick", "hit": 0.28, "end": 0.95, "limb": "foot_l", "startup": 10, "active": 5, "recovery": 20,
		"dmg": 12, "hitstop": 10, "stun": 40, "kb": [12.0, 4.0], "effect": "knockdown", "box": [1.0, 1.2, 0.65], "lunge": 3.0,
		"chain": {}, "dodge": "hit", "shake": 0.45, "sfx": "heavy"},

	# ---------------- En l'air : X jab ▸ pied latéral ▸ talon ; Y gros genou ; Y maintenu : coup de pied plongeant ----------------
	"air_jab": {"anim": "mx/jab", "hit": 0.28, "end": 0.55, "limb": "hand_l", "startup": 4, "active": 3, "recovery": 10,
		"dmg": 4, "hitstop": 5, "stun": 26, "kb": [1.0, 3.2], "effect": "juggle", "box": [0.75, 1.3, 0.6], "lunge": 0.0,
		"chain": {"attack": "air_kick", "heavy": "air_knee"}, "chain_from": 4, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.12, "sfx": "light",
		"tall": 1.2, "keep_momentum": true},
	"air_kick": {"anim": "mx/side_kick", "hit": 0.5, "end": 0.9, "limb": "foot_l", "startup": 5, "active": 3, "recovery": 11,
		"dmg": 5, "hitstop": 5, "stun": 26, "kb": [1.2, 3.2], "effect": "juggle", "box": [0.8, 1.0, 0.65], "lunge": 0.0,
		"chain": {"attack": "air_heel", "heavy": "air_knee"}, "chain_from": 5, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.14, "sfx": "light",
		"tall": 1.2, "keep_momentum": true},
	"air_heel": {"anim": "mx/stomp", "hit": 0.68, "end": 1.1, "limb": "foot_r", "startup": 7, "active": 4, "recovery": 14,
		"dmg": 8, "hitstop": 10, "stun": 34, "kb": [3.0, -14.0], "effect": "spike", "box": [0.85, 0.5, 0.7], "lunge": 0.5,
		"chain": {"heavy": "air_knee"}, "chain_from": 9, "dodge": "hit", "air": true, "hang": 1.6, "shake": 0.4, "sfx": "heavy", "tall": 1.2, "heavy_land": true},
	"air_knee": {"anim": "mx/flying_knee", "hit": 0.7, "end": 1.0, "limb": "calf_r", "startup": 6, "active": 4, "recovery": 14,
		"dmg": 10, "hitstop": 10, "stun": 34, "kb": [2.0, 5.0], "effect": "juggle", "box": [1.0, 1.05, 0.65], "lunge": 0.4,
		"chain": {"attack": "air_jab"}, "chain_from": 8, "dodge": "always", "air": true, "hang": 2.4, "shake": 0.35, "sfx": "heavy",
		"tall": 1.2, "hold": "dive_kick"},
	"dive_kick": {"anim": "mx/flying_kick", "hit": 0.28, "end": 0.75, "limb": "foot_l", "startup": 8, "active": 30, "recovery": 14,
		"dmg": 10, "hitstop": 10, "stun": 40, "kb": [2.0, -16.0], "effect": "spike", "box": [0.9, 0.6, 0.7], "lunge": 0.4,
		"chain": {}, "dodge": "hit", "air": true, "dive": true, "shake": 0.5, "sfx": "big", "quake": 3, "heavy_land": true, "tall": 1.0},

	# ---------------- Riposte (X juste après une parade) ----------------
	"riposte": {"anim": "mx/uppercut_rear", "hit": 0.6, "end": 1.05, "limb": "hand_r", "startup": 5, "active": 4, "recovery": 16,
		"dmg": 14, "hitstop": 14, "stun": 50, "kb": [0.8, 12.5], "effect": "launch", "box": [0.85, 0.9, 0.65], "lunge": 0.8,
		"chain": {}, "dodge": "always", "jump_cancel": true, "shake": 0.55, "sfx": "big", "slowmo": 0.2, "crit": true, "sweep_dir": -1},

	# ---------------- Coups des sbires : même fiche, armés longs (lisibles) ; rouge = bloquable, orange = à esquiver ----------------
	"e_cross": {"anim": "mx/e_cross", "hit": 0.98, "end": 1.5, "limb": "hand_r", "startup": 16, "active": 4, "recovery": 24,
		"dmg": 8, "hitstop": 6, "stun": 24, "kb": [3.0, 0.0], "box": [0.85, 1.35, 0.5], "lunge": 0.6,
		"chain": {}, "dodge": "always", "shake": 0.2, "sfx": "light", "telegraph": "red"},
	"e_lowkick": {"anim": "mx/e_low_kick", "hit": 0.5, "end": 1.1, "limb": "foot_r", "startup": 18, "active": 4, "recovery": 26,
		"dmg": 9, "hitstop": 6, "stun": 26, "kb": [3.5, 0.0], "box": [0.75, 0.6, 0.55], "lunge": 0.5,
		"chain": {}, "dodge": "always", "low": true, "shake": 0.2, "sfx": "light", "telegraph": "red"},
	"e_hook": {"anim": "mx/hook_rear", "hit": 0.62, "end": 1.2, "limb": "hand_r", "startup": 22, "active": 4, "recovery": 28,
		"dmg": 14, "hitstop": 10, "stun": 36, "kb": [9.0, 3.0], "effect": "knockdown", "box": [0.85, 1.05, 0.6], "lunge": 1.2,
		"chain": {}, "dodge": "always", "guard_break": true, "shake": 0.4, "sfx": "heavy", "telegraph": "orange", "sweep_dir": -1},
	"e_bigkick": {"anim": "mx/e_round_kick", "hit": 0.6, "end": 1.2, "limb": "foot_r", "startup": 24, "active": 5, "recovery": 30,
		"dmg": 16, "hitstop": 12, "stun": 40, "kb": [11.0, 4.0], "effect": "knockdown", "box": [0.9, 0.6, 0.65], "lunge": 1.0,
		"chain": {}, "dodge": "always", "guard_break": true, "shake": 0.5, "sfx": "heavy", "telegraph": "orange", "sweep_dir": 1},
}

## Chope : paire d'animations (attaquant / victime) jouées depuis la même origine. Temps dans l'animation (s), vitesse.
const GRAB := {
	"pair": ["mx/slam_a", "mx/slam_b"],
	"catch": {"from": 1.0, "to": 2.4, "speed": 1.6},         # la prise : il l'attrape et le soulève
	"hold": {"at": 2.45, "to": 3.3, "speed": 0.5},            # le tenu : lecture lente de ce passage, en aller-retour
	"slam": {"from": 4.9, "impact": 5.95, "to": 6.3, "speed": 2.0},   # RB / Y : il l'écrase au sol (0,52 s appui -> impact)
	"escape": {"stun": 16, "push": 4.0},
}


static func get_move(id: String) -> Dictionary:
	return M[id]


static func total(m: Dictionary) -> int:
	return int(m.startup) + int(m.active) + int(m.recovery)


static func from_time(m: Dictionary) -> float:
	if m.has("from"):
		return float(m.from)
	return maxf(0.0, float(m.hit) - float(m.startup) / 60.0)

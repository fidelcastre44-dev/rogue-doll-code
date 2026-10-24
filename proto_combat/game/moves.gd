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
## v0.113 : beaucoup de coups jouent des animations Mixamo (« mx/… », tools/mixamo_bake.gd) ; impacts mesurés par tools/mx_times.gd
## (pic de vitesse du pied, du poing ou de la pointe de l'arme). Combo aérien léger : jab, coup de pied latéral, coup de pied circulaire.

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
	"air_cross": {"anim": "mx/enemy__mma_side_kick", "from": 0.25, "hit": 0.52, "end": 0.85, "startup": 5, "active": 3, "recovery": 11,
		"dmg": 5, "hitstop": 5, "stun": 26, "kb": [1.2, 3.2], "effect": "juggle", "box": [0.95, 1.1, 0.65], "lunge": 0.3,
		"chain": {"attack": "air_kick", "heavy": "air_spike"}, "chain_from": 5, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.14, "sfx": "light"},
	"air_kick": {"anim": "mx/enemy__mma_roundhouse", "from": 0.45, "hit": 0.75, "end": 1.05, "startup": 7, "active": 4, "recovery": 14,
		"dmg": 8, "hitstop": 10, "stun": 34, "kb": [3.0, -14.0], "effect": "spike", "box": [1.15, 0.9, 0.8], "lunge": 0.5,
		"chain": {"heavy": "air_spike"}, "chain_from": 9, "dodge": "hit", "air": true, "hang": 1.6, "shake": 0.4, "sfx": "heavy", "slash": "down"},
	"air_spike": {"anim": "cmu/kick_low", "from": 0.1, "hit": 0.342, "end": 0.7, "startup": 8, "active": 30, "recovery": 14,
		"dmg": 10, "hitstop": 10, "stun": 40, "kb": [2.0, -16.0], "effect": "spike", "box": [0.7, 0.4, 0.95], "lunge": 0.4,
		"chain": {}, "dodge": "hit", "air": true, "dive": true, "shake": 0.5, "sfx": "big"},

	# ---------------- Riposte (X juste après une parade) ----------------
	"riposte": {"anim": "cmu/uppercut", "from": 0.06, "hit": 0.33, "end": 0.66, "startup": 5, "active": 4, "recovery": 16,
		"dmg": 14, "hitstop": 14, "stun": 50, "kb": [0.8, 12.5], "effect": "launch", "box": [1.0, 1.3, 0.8], "lunge": 0.8,
		"chain": {}, "dodge": "always", "jump_cancel": true, "shake": 0.55, "sfx": "big", "slowmo": 0.2, "crit": true},

	# ================= v0.112 : ARMES (mur d'armes, RB). « blade » = la zone de frappe suit la lame (Weapons.DEFS[..].blade) ;
	# animations Quaternius UAL (Sword_Regular_A/B/C, Sword_Attack, Sword_Dash, TreeChopping) recalées sur l'impact mesuré
	# par tools/weapon_times.gd (instant où la pointe va le plus vite, devant le perso).
	# ---------------- Épée : équilibrée ----------------
	"sw_a": {"anim": "mx/sword__slash_combo", "from": 0.3, "hit": 0.67, "end": 0.95, "startup": 7, "active": 4, "recovery": 12,
		"dmg": 7, "hitstop": 6, "stun": 22, "kb": [2.2, 0.0], "box": [1.2, 1.2, 0.7], "lunge": 0.6, "blade": true,
		"chain": {"attack": "sw_b", "heavy": "sw_up"}, "chain_from": 7, "dodge": "always", "shake": 0.15, "sfx": "light", "slash": "h"},
	"sw_b": {"anim": "mx/sword__slash_combo", "from": 0.95, "hit": 1.23, "end": 1.6, "startup": 7, "active": 4, "recovery": 13,
		"dmg": 8, "hitstop": 7, "stun": 24, "kb": [2.6, 0.0], "box": [1.2, 1.2, 0.7], "lunge": 0.6, "blade": true,
		"chain": {"attack": "sw_c", "heavy": "sw_up"}, "chain_from": 7, "dodge": "always", "shake": 0.18, "sfx": "light", "slash": "h"},
	"sw_c": {"anim": "mx/sword__slash_combo", "from": 2.0, "hit": 2.47, "end": 3.0, "startup": 12, "active": 5, "recovery": 20,
		"dmg": 14, "hitstop": 11, "stun": 30, "kb": [9.0, 3.5], "effect": "knockdown", "box": [1.3, 1.2, 0.8], "lunge": 0.9, "blade": true,
		"chain": {}, "dodge": "hit", "shake": 0.45, "sfx": "heavy", "slowmo": 0.1, "slash": "h"},
	"sw_up": {"anim": "sword_a", "from": 0.0, "hit": 0.25, "end": 0.43, "startup": 9, "active": 4, "recovery": 18,
		"dmg": 9, "hitstop": 8, "stun": 40, "kb": [0.3, 11.5], "effect": "launch", "box": [1.1, 1.0, 0.7], "lunge": 0.7, "blade": true,
		"chain": {}, "dodge": "hit", "jump_cancel": true, "shake": 0.3, "sfx": "heavy", "slash": "up"},
	"sw_heavy": {"anim": "mx/sword__power_slash", "from": 0.9, "hit": 1.4, "end": 2.0, "startup": 14, "active": 5, "recovery": 22,
		"dmg": 16, "hitstop": 12, "stun": 40, "kb": [11.0, 4.0], "effect": "knockdown", "box": [1.3, 1.2, 0.8], "lunge": 1.6, "blade": true,
		"chain": {}, "dodge": "hit", "guard_break": true, "shake": 0.5, "sfx": "heavy", "slowmo": 0.1, "slash": "h"},
	"sw_dash": {"anim": "mx/sword__low_attack", "from": 0.3, "hit": 0.77, "end": 1.3, "startup": 6, "active": 5, "recovery": 16,
		"dmg": 10, "hitstop": 8, "stun": 30, "kb": [7.0, 0.5], "effect": "stagger", "box": [1.2, 1.2, 0.7], "lunge": 3.0, "blade": true,
		"chain": {"attack": "sw_b", "heavy": "sw_up"}, "chain_from": 11, "dodge": "active", "shake": 0.25, "sfx": "light", "slash": "h"},
	"sw_air": {"anim": "sword_b", "from": 0.05, "hit": 0.27, "end": 0.5, "startup": 5, "active": 4, "recovery": 11,
		"dmg": 6, "hitstop": 6, "stun": 26, "kb": [1.0, 3.2], "effect": "juggle", "box": [1.1, 1.0, 0.8], "lunge": 0.3, "blade": true,
		"chain": {"attack": "sw_air2", "heavy": "air_spike"}, "chain_from": 5, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.14, "sfx": "light", "slash": "h"},
	"sw_air2": {"anim": "sword_dash", "from": 0.05, "hit": 0.33, "end": 0.6, "startup": 5, "active": 4, "recovery": 12,
		"dmg": 7, "hitstop": 6, "stun": 26, "kb": [1.2, 3.2], "effect": "juggle", "box": [1.1, 1.0, 0.8], "lunge": 0.3, "blade": true,
		"chain": {"attack": "sw_air3", "heavy": "air_spike"}, "chain_from": 5, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.16, "sfx": "light", "slash": "h"},
	"sw_air3": {"anim": "mx/sword__jump_attack", "from": 0.8, "hit": 1.2, "end": 1.6, "startup": 7, "active": 5, "recovery": 14,
		"dmg": 10, "hitstop": 10, "stun": 34, "kb": [3.0, -14.0], "effect": "spike", "box": [1.2, 0.9, 0.9], "lunge": 0.5, "blade": true,
		"chain": {"heavy": "air_spike"}, "chain_from": 9, "dodge": "hit", "air": true, "hang": 1.6, "shake": 0.4, "sfx": "heavy", "slash": "down"},

	# ---------------- Katana : rapide, longue portée, dégâts plus faibles ; Y = dégainé éclair qui traverse ----------------
	"ka_a": {"anim": "mx/katana__outward_slash", "from": 0.55, "hit": 0.9, "end": 1.3, "startup": 5, "active": 3, "recovery": 9,
		"dmg": 5, "hitstop": 5, "stun": 22, "kb": [1.6, 0.0], "box": [1.3, 1.2, 0.7], "lunge": 0.7, "blade": true,
		"chain": {"attack": "ka_b", "heavy": "ka_rise"}, "chain_from": 5, "dodge": "always", "shake": 0.12, "sfx": "light", "slash": "h"},
	"ka_b": {"anim": "mx/katana__inward_slash", "from": 0.85, "hit": 1.2, "end": 1.6, "startup": 5, "active": 3, "recovery": 10,
		"dmg": 6, "hitstop": 5, "stun": 22, "kb": [1.8, 0.0], "box": [1.3, 1.2, 0.7], "lunge": 0.7, "blade": true,
		"chain": {"attack": "ka_c", "heavy": "ka_rise"}, "chain_from": 5, "dodge": "always", "shake": 0.14, "sfx": "light", "slash": "h"},
	"ka_c": {"anim": "sword_c", "from": 0.35, "hit": 0.65, "end": 1.05, "startup": 9, "active": 6, "recovery": 18,
		"dmg": 10, "hitstop": 10, "stun": 30, "kb": [7.0, 3.0], "effect": "knockdown", "box": [1.4, 1.3, 0.8], "lunge": 1.0, "blade": true,
		"chain": {}, "dodge": "hit", "shake": 0.4, "sfx": "heavy", "slowmo": 0.1, "slash": "h"},
	"ka_rise": {"anim": "sword_a", "from": 0.0, "hit": 0.25, "end": 0.43, "startup": 8, "active": 4, "recovery": 16,
		"dmg": 8, "hitstop": 8, "stun": 40, "kb": [0.3, 12.0], "effect": "launch", "box": [1.2, 1.0, 0.7], "lunge": 0.8, "blade": true,
		"chain": {}, "dodge": "hit", "jump_cancel": true, "shake": 0.3, "sfx": "heavy", "slash": "up"},
	"ka_iai": {"anim": "sword_dash", "from": 0.05, "hit": 0.33, "end": 0.75, "startup": 10, "active": 6, "recovery": 20,
		"dmg": 16, "hitstop": 12, "stun": 40, "kb": [6.0, 1.0], "effect": "stagger", "box": [1.3, 1.2, 0.8], "lunge": 4.5, "blade": true,
		"chain": {}, "dodge": "hit", "shake": 0.5, "sfx": "big", "slowmo": 0.15, "slash": "thrust"},
	"ka_air": {"anim": "sword_b", "from": 0.08, "hit": 0.27, "end": 0.5, "startup": 4, "active": 3, "recovery": 10,
		"dmg": 5, "hitstop": 5, "stun": 26, "kb": [1.0, 3.2], "effect": "juggle", "box": [1.2, 1.0, 0.8], "lunge": 0.3, "blade": true,
		"chain": {"attack": "ka_air2", "heavy": "air_spike"}, "chain_from": 4, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.12, "sfx": "light", "slash": "h"},
	"ka_air2": {"anim": "sword_dash", "from": 0.08, "hit": 0.33, "end": 0.6, "startup": 4, "active": 3, "recovery": 11,
		"dmg": 6, "hitstop": 5, "stun": 26, "kb": [1.2, 3.2], "effect": "juggle", "box": [1.2, 1.0, 0.8], "lunge": 0.3, "blade": true,
		"chain": {"attack": "sw_air3", "heavy": "air_spike"}, "chain_from": 4, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.14, "sfx": "light", "slash": "h"},

	# ---------------- Hache : lente, ne bronche pas pendant l'armé, gros dégâts ----------------
	"ax_chop": {"anim": "mx/axe__three_hit_combo", "from": 0.6, "hit": 1.02, "end": 1.35, "startup": 13, "active": 5, "recovery": 18,
		"dmg": 12, "hitstop": 10, "stun": 32, "kb": [5.0, 0.0], "effect": "stagger", "box": [1.1, 1.3, 0.8], "lunge": 0.8, "blade": true,
		"chain": {"attack": "ax_chop2", "heavy": "ax_up"}, "chain_from": 14, "dodge": "active", "armor": true, "shake": 0.35, "sfx": "heavy", "slash": "h"},
	"ax_chop2": {"anim": "mx/axe__three_hit_combo", "from": 1.35, "hit": 1.63, "end": 2.1, "startup": 12, "active": 5, "recovery": 20,
		"dmg": 14, "hitstop": 11, "stun": 34, "kb": [7.0, 1.0], "effect": "stagger", "box": [1.1, 1.3, 0.8], "lunge": 0.9, "blade": true,
		"chain": {"attack": "ax_final", "heavy": "ax_up"}, "chain_from": 13, "dodge": "active", "armor": true, "shake": 0.4, "sfx": "heavy", "slash": "h"},
	"ax_final": {"anim": "mx/axe__three_hit_combo", "from": 2.1, "hit": 2.63, "end": 3.3, "startup": 16, "active": 6, "recovery": 26,
		"dmg": 22, "hitstop": 14, "stun": 44, "kb": [13.0, 5.0], "effect": "knockdown", "box": [1.3, 1.2, 0.9], "lunge": 1.2, "blade": true,
		"chain": {}, "dodge": "hit", "guard_break": true, "armor": true, "shake": 0.65, "sfx": "big", "slowmo": 0.15, "slash": "h"},
	"ax_sweep": {"anim": "mx/axe__spin_attack", "from": 0.55, "hit": 0.99, "end": 1.7, "startup": 18, "active": 6, "recovery": 28,
		"dmg": 20, "hitstop": 14, "stun": 44, "kb": [12.0, 4.0], "effect": "knockdown", "box": [1.3, 1.2, 0.9], "lunge": 1.4, "blade": true,
		"chain": {}, "dodge": "hit", "guard_break": true, "armor": true, "shake": 0.6, "sfx": "big", "slowmo": 0.12, "slash": "h"},
	"ax_up": {"anim": "mx/axe__backhand_upward", "from": 0.7, "hit": 1.03, "end": 1.6, "startup": 12, "active": 5, "recovery": 20,
		"dmg": 12, "hitstop": 10, "stun": 44, "kb": [0.3, 12.0], "effect": "launch", "box": [1.1, 1.0, 0.8], "lunge": 0.7, "blade": true,
		"chain": {}, "dodge": "hit", "jump_cancel": true, "shake": 0.4, "sfx": "heavy", "slash": "up"},
	"ax_jump": {"anim": "mx/axe__running_jump_attack", "from": 1.2, "hit": 1.73, "end": 2.3, "startup": 16, "active": 5, "recovery": 24,
		"dmg": 18, "hitstop": 13, "stun": 40, "kb": [10.0, 4.0], "effect": "knockdown", "box": [1.3, 1.1, 0.9], "lunge": 3.0, "blade": true,
		"chain": {}, "dodge": "hit", "armor": true, "shake": 0.6, "sfx": "big", "slowmo": 0.1, "slash": "down"},
	"ax_air": {"anim": "mx/axe__downward", "from": 0.45, "hit": 0.87, "end": 1.3, "startup": 9, "active": 5, "recovery": 16,
		"dmg": 12, "hitstop": 11, "stun": 36, "kb": [2.0, -16.0], "effect": "spike", "box": [1.1, 0.9, 0.9], "lunge": 0.4, "blade": true,
		"chain": {}, "dodge": "hit", "air": true, "hang": 1.6, "shake": 0.45, "sfx": "big", "slash": "down"},

	# ---------------- Batte : le 3e coup est un « home run » qui l'envoie loin (renverse les autres, s'écrase au mur) ;
	# Y = coup de batte vers le bas : il rebondit au sol, prêt à être jonglé ----------------
	"bt_a": {"anim": "mx/greatsword__combo_slash", "from": 1.4, "hit": 1.7, "end": 2.2, "startup": 8, "active": 4, "recovery": 13,
		"dmg": 7, "hitstop": 7, "stun": 24, "kb": [2.4, 0.0], "box": [1.1, 1.2, 0.7], "lunge": 0.6, "blade": true,
		"chain": {"attack": "bt_b", "heavy": "bt_up"}, "chain_from": 8, "dodge": "always", "shake": 0.18, "sfx": "light", "slash": "h"},
	"bt_b": {"anim": "mx/greatsword__combo_slash", "from": 2.3, "hit": 2.67, "end": 3.2, "startup": 8, "active": 4, "recovery": 14,
		"dmg": 8, "hitstop": 8, "stun": 26, "kb": [2.8, 0.0], "box": [1.1, 1.2, 0.7], "lunge": 0.6, "blade": true,
		"chain": {"attack": "bt_swing", "heavy": "bt_up"}, "chain_from": 8, "dodge": "always", "shake": 0.2, "sfx": "light", "slash": "h"},
	"bt_swing": {"anim": "mx/bat__homerun", "from": 1.1, "hit": 1.47, "end": 2.4, "startup": 14, "active": 5, "recovery": 22,
		"dmg": 13, "hitstop": 14, "stun": 40, "kb": [17.0, 5.0], "effect": "knockdown", "bowl": true, "box": [1.2, 1.2, 0.8], "lunge": 1.0, "blade": true,
		"chain": {}, "dodge": "hit", "shake": 0.65, "sfx": "big", "slowmo": 0.18, "slash": "h"},
	"bt_smash": {"anim": "mx/greatsword__downward_slash", "from": 0.3, "hit": 0.67, "end": 1.0, "startup": 13, "active": 5, "recovery": 20,
		"dmg": 12, "hitstop": 12, "stun": 44, "kb": [1.0, -16.0], "effect": "spike", "box": [1.1, 1.0, 0.9], "lunge": 0.8, "blade": true,
		"chain": {"attack": "bt_a"}, "chain_from": 16, "dodge": "hit", "jump_cancel": true, "shake": 0.5, "sfx": "big", "slash": "down"},
	"bt_up": {"anim": "sword_a", "from": 0.0, "hit": 0.25, "end": 0.43, "startup": 10, "active": 4, "recovery": 18,
		"dmg": 9, "hitstop": 9, "stun": 40, "kb": [0.3, 11.5], "effect": "launch", "box": [1.1, 1.0, 0.7], "lunge": 0.7, "blade": true,
		"chain": {}, "dodge": "hit", "jump_cancel": true, "shake": 0.3, "sfx": "heavy", "slash": "up"},
	"bt_air": {"anim": "mx/greatsword__jump_attack", "from": 0.8, "hit": 1.2, "end": 1.6, "startup": 5, "active": 4, "recovery": 12,
		"dmg": 6, "hitstop": 7, "stun": 26, "kb": [1.0, 3.2], "effect": "juggle", "box": [1.1, 1.0, 0.8], "lunge": 0.3, "blade": true,
		"chain": {"attack": "sw_air3", "heavy": "air_spike"}, "chain_from": 5, "dodge": "always", "air": true, "hang": 2.2, "shake": 0.15, "sfx": "light", "slash": "h"},
}

# Chope (R1) : pas une frappe, réglages à part.
# v0.112 : on le TIENT jusqu'à 3 s (hold_max) ; X = coups pendant la chope, Y = l'éclater au sol (rebond, jonglable),
# R1 = le lancer (stick = direction). S'il est tenu 3 s sans rien faire, il se dégage (comme la chope de Smash Bros).
const GRAB := {"startup": 6, "reach": 1.5, "whiff": 20, "hold_max": 180, "throw_f": 10, "recovery": 18, "dmg": 10, "kb": [13.0, 4.5],
	"pummel_dmg": 3, "pummel_f": 16, "slam_f": 20, "slam_dmg": 14, "slam_bounce": 7.5, "slam_recovery": 22}


static func get_move(id: String) -> Dictionary:
	return M[id]


static func total(m: Dictionary) -> int:
	return m.startup + m.active + m.recovery

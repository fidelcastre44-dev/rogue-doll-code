class_name Tuning
## Tous les réglages généraux du jeu (cahier des charges, section 5 « Réglages généraux », corrections de Thibaud en v2).
## Modifiables en direct dans le panneau (Start), gardés dans user://tuning.json, exportables en texte pour le carnet.
## Le jeu ne lit que `Tuning.v(nom)` : jamais de nombre enfoui dans le code pour ce qui est réglable.

const DEFAULTS := {
	# déplacement (m/s, m/s², rad/s)
	"run_speed": 6.1, "sprint_speed": 7.8, "walk_speed": 2.6, "guard_speed": 2.2,
	"accel": 75.0, "decel": 95.0, "turn_rate": 40.0,
	"sprint_hold": 0.3,            # s : stick à fond pendant ce temps = sprint (ou L3)
	# saut
	"jump_speed": 8.2, "grav_up": 24.0, "grav_down": 40.0, "coyote": 6,
	"double_jump": 7.2, "air_dash_frames": 14, "air_dash_dist": 3.4,
	"land_frames": 3, "land_heavy_frames": 9,
	# roulade (images, m)
	"roll_frames": 20, "roll_dist": 3.7, "roll_inv_from": 1, "roll_inv_to": 12, "roll_attack_from": 11,
	"roll_cooldown": 6,            # images avant une nouvelle roulade (jamais deux d'affilée)
	"perfect_dodge_window": 8,     # images avant le coup ennemi
	# parade / garde
	"parry_window": 8, "riposte_frames": 42, "parry_cooldown": 20,
	# coups
	"assist": 0.33,                # aide à la visée (0 = aucune, 0.65 = ancien réglage)
	"assist_range": 3.2, "assist_cone": 70.0,
	"lunge_scale": 1.0,            # multiplie l'élan de tous les coups
	"hold_sweep": 12, "hold_dive": 10, "charge_min": 0.2, "charge_max": 1.0,
	"buffer": 9,                   # images de tampon d'entrées (150 ms)
	"juggle_decay": 0.88, "juggle_grav": 21.0,
	"hitstop_scale": 1.0, "shake_scale": 1.0,
	# chope
	"grab_reach": 1.5, "grab_startup": 6, "grab_whiff": 20, "grab_hold_max": 180, "grab_pummel_every": 16,
	"grab_pummel_dmg": 3, "grab_slam_dmg": 14,
	# ennemis
	"foe_hp": 120.0, "foe_attackers_max": 2, "foe_ring": 2.3, "foe_speed": 3.6,
	"getup_frames": 50, "down_frames": 45, "quick_getup_after": 2,
	# ragdoll visuel
	"rag_mass": 75.0, "rag_gravity": 2.2, "rag_damp": 4.0, "rag_bounce": 0.08,
	# caméra
	"cam_yaw": 0.0, "cam_pitch": 42.0, "cam_zoom": 1.0,
}

static var values := {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	values = DEFAULTS.duplicate()
	if FileAccess.file_exists("user://tuning.json"):
		var j = JSON.parse_string(FileAccess.get_file_as_string("user://tuning.json"))
		if j is Dictionary:
			for k in j:
				if values.has(k):
					values[k] = j[k]


static func v(name: String) -> float:
	_ensure()
	return float(values[name])


static func vi(name: String) -> int:
	_ensure()
	return int(round(float(values[name])))


static func set_value(name: String, x: float) -> void:
	_ensure()
	values[name] = x


static func reset() -> void:
	values = DEFAULTS.duplicate()
	_loaded = true


static func save() -> void:
	_ensure()
	var f := FileAccess.open("user://tuning.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(values, "  "))


## Texte à coller dans une note du carnet : seulement ce qui diffère des valeurs de départ.
static func export_text() -> String:
	_ensure()
	var lines := []
	for k in DEFAULTS:
		if not is_equal_approx(float(values[k]), float(DEFAULTS[k])):
			lines.append("%s: %s (départ %s)" % [k, values[k], DEFAULTS[k]])
	return "Réglages proto v2\n" + ("\n".join(lines) if lines.size() else "(valeurs de départ)")

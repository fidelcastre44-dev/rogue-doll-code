extends SceneTree
## Outil (à lancer une fois, sans écran) : poses et fiches de la version 0.11 (correctifs, retours de Paul du 22/10).
##   ../godot --headless --path . -s tools/gen_v011_moves.gd
## Relançable : il remplace les poses et fiches qu'il crée ; pour une fiche existante, seuls les champs listés changent.

const N := null

func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


## Pose au sol -> même pose en l'air (jambes du poing aérien, bassin non abaissé).
func airy(ps: PoseSet, name: String) -> Dictionary:
	var d: Dictionary = ps.diffs[name].duplicate()
	d.merge({"foot_l": N, "foot_r": N, "hips_pos": V(0, 0, 0), "hip_l": V(80, 0, 0), "kn_l": V(-110, 0, 0), "hip_r": V(-10, 0, 0), "kn_r": V(-50, 0, 0)}, true)
	return d


func poses(ps: PoseSet) -> Dictionary:
	var air_legs := {"foot_l": N, "foot_r": N}
	return {
		# Superman punch : il retombe à plat ventre, bras devant, puis se relève vite.
		"sm_down": air_legs.merged({"hips_pos": V(0, -0.73, 0.1), "hips": V(-86, 0, 0), "spine": V(-2, 0, 0), "head": V(38, 0, 0),
			"sh_l": V(160, 0, 28), "el_l": V(12, 0, 0), "sh_r": V(160, 0, -28), "el_r": V(12, 0, 0),
			"hip_l": V(-4, 0, 7), "kn_l": V(-22, 0, 0), "hip_r": V(-4, 0, -7), "kn_r": V(-12, 0, 0)}),
		"sm_push": {"hips_pos": V(0, -0.5, 0.05), "hips": V(-55, 0, 0), "spine": V(-10, 0, 0), "head": V(30, 0, 0),
			"sh_l": V(85, 0, 12), "el_l": V(10, 0, 0), "sh_r": V(85, 0, -12), "el_r": V(10, 0, 0),
			"foot_l": V(-0.16, 0.02, 0.35), "foot_r": V(0.16, 0.02, 0.5)},
		# Drop kick : sur le dos, il se tortille un peu avant de se relever.
		"back_lie2": air_legs.merged({"hips_pos": V(0, -0.72, -0.05), "hips": V(84, 8, 0), "spine": V(6, -6, 0), "head": V(-28, 15, 0),
			"sh_l": V(110, 0, 55), "el_l": V(35, 0, 0), "sh_r": V(95, 0, -70), "el_r": V(15, 0, 0),
			"hip_l": V(25, 0, 8), "kn_l": V(-60, 0, 0), "hip_r": V(-4, 0, -8), "kn_r": V(-20, 0, 0)}),
		# Plaquage : il plonge et reste couché sur le sbire, bras autour, puis se relève en poussant.
		"tk_dive": air_legs.merged({"hips_pos": V(0, -0.5, 0.05), "hips": V(-82, 0, 0), "spine": V(-6, 0, 0), "head": V(40, 0, 0),
			"sh_l": V(70, 0, 38), "el_l": V(80, 0, 0), "sh_r": V(70, 0, -38), "el_r": V(80, 0, 0),
			"hip_l": V(-10, 0, 10), "kn_l": V(-35, 0, 0), "hip_r": V(5, 0, -8), "kn_r": V(-60, 0, 0)}),
		"tk_dive2": air_legs.merged({"hips_pos": V(0, -0.48, 0.05), "hips": V(-80, 4, 3), "spine": V(-10, -4, 0), "head": V(35, -10, 0),
			"sh_l": V(75, 0, 30), "el_l": V(90, 0, 0), "sh_r": V(65, 0, -44), "el_r": V(70, 0, 0),
			"hip_l": V(5, 0, 12), "kn_l": V(-55, 0, 0), "hip_r": V(-10, 0, -10), "kn_r": V(-30, 0, 0)}),
		# Prise de catch : bras enroulé autour du cou, puis il se couche à l'horizontale, pieds devant.
		"pd_hook": {"hips_pos": V(0, -0.14, 0), "hips": V(-12, -15, 0), "spine": V(-22, -10, 0), "head": V(15, 10, 0),
			"sh_l": V(95, 0, 25), "el_l": V(60, 0, 0), "sh_r": V(80, 0, 25), "el_r": V(115, 0, 0),
			"foot_l": V(-0.17, 0.02, -0.2), "foot_r": V(0.17, 0.02, 0.2)},
		"pd_crouch2": {"hips_pos": V(0, -0.34, 0), "hips": V(-15, -15, 0), "spine": V(-22, -10, 0), "head": V(20, 10, 0),
			"sh_l": V(95, 0, 25), "el_l": V(60, 0, 0), "sh_r": V(80, 0, 25), "el_r": V(115, 0, 0),
			"foot_l": V(-0.2, 0.02, -0.15), "foot_r": V(0.2, 0.02, 0.15)},
		"pd_flat": air_legs.merged({"hips_pos": V(0, -0.25, 0), "hips": V(82, 0, -8), "spine": V(4, 0, 0), "head": V(-30, 0, 0),
			"sh_l": V(45, 0, 40), "el_l": V(40, 0, 0), "sh_r": V(20, 0, -85), "el_r": V(105, 0, 0),
			"hip_l": V(-6, 0, 5), "kn_l": V(-12, 0, 0), "hip_r": V(4, 0, -5), "kn_r": V(-8, 0, 0)}),
		# Projection de hanche : il pivote (c'est le perso entier qui tourne), hanche dans le sbire, puis le bascule par-dessus.
		"ht2_load": {"hips_pos": V(0, -0.3, 0.1), "hips": V(-15, 0, 0), "spine": V(-20, 0, 0), "head": V(10, 0, 0),
			"sh_l": V(140, 0, 25), "el_l": V(70, 0, 0), "sh_r": V(155, 0, -20), "el_r": V(55, 0, 0),
			"foot_l": V(-0.16, 0.02, -0.05), "foot_r": V(0.16, 0.02, 0.05)},
		"ht2_throw": {"hips_pos": V(0, -0.38, 0.05), "hips": V(-45, 0, 0), "spine": V(-38, 0, 0), "head": V(28, 0, 0),
			"sh_l": V(35, 0, 15), "el_l": V(30, 0, 0), "sh_r": V(25, 0, -15), "el_r": V(30, 0, 0),
			"foot_l": V(-0.17, 0.02, -0.08), "foot_r": V(0.17, 0.02, 0.08)},
		# Bicyclette : couché en l'air, la jambe passe par-dessus en arc latéral (de la droite, par le haut, vers la gauche).
		"bc2_load": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(62, 0, 22), "spine": V(-8, 0, 0), "head": V(-35, 0, 0),
			"sh_l": V(40, 0, 85), "el_l": V(30, 0, 0), "sh_r": V(40, 0, -85), "el_r": V(30, 0, 0),
			"hip_l": V(85, 0, 0), "kn_l": V(-40, 0, 0), "hip_r": V(15, 0, 65), "kn_r": V(-15, 0, 0)}),
		"bc2_over": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(82, 0, 0), "spine": V(-10, 0, 0), "head": V(-40, 0, 0),
			"sh_l": V(30, 0, 95), "el_l": V(20, 0, 0), "sh_r": V(30, 0, -95), "el_r": V(20, 0, 0),
			"hip_l": V(30, 0, 10), "kn_l": V(-70, 0, 0), "hip_r": V(110, 0, 8), "kn_r": V(0, 0, 0)}),
		"bc2_kick": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(88, 0, -24), "spine": V(-8, 0, 0), "head": V(-45, 0, 0),
			"sh_l": V(20, 0, 85), "el_l": V(20, 0, 0), "sh_r": V(55, 0, -95), "el_r": V(30, 0, 0),
			"hip_l": V(10, 0, 15), "kn_l": V(-80, 0, 0), "hip_r": V(25, 0, -55), "kn_r": V(0, 0, 0)}),
		# Combo aérien : direct, puis le coup spécial (uppercut, crochet, genou) en l'air.
		"air_cross": airy(ps, "cross"),
		"air_upper_load": airy(ps, "upper_load"),
		"air_upper": airy(ps, "upper"),
		"air_hook_load": airy(ps, "hook_load"),
		"air_hook": airy(ps, "hook"),
		"air_hook_through": airy(ps, "hook_through"),
		# Course au mur horizontale : il court à l'horizontale le long du mur, puis s'en repousse en coup de pied sauté.
		"wh_run": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(-12, 0, 0), "spine": V(-14, 0, 0), "head": V(10, 0, 0),
			"sh_l": V(30, 0, 30), "el_l": V(90, 0, 0), "sh_r": V(-30, 0, -30), "el_r": V(90, 0, 0),
			"hip_l": V(40, 0, 0), "kn_l": V(-60, 0, 0), "hip_r": V(-20, 0, 0), "kn_r": V(-40, 0, 0)}),
		"wh_kick": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(25, 0, 0), "spine": V(10, 0, 0), "head": V(-25, 0, 0),
			"sh_l": V(-30, 0, 60), "el_l": V(40, 0, 0), "sh_r": V(-30, 0, -60), "el_r": V(40, 0, 0),
			"hip_l": V(60, 0, 0), "kn_l": V(-110, 0, 0), "hip_r": V(95, 0, 0), "kn_r": V(0, 0, 0)}),
		# Super saut -> chope plongeante : il plonge vers le sbire, bras tendus.
		"sj_dive": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(-60, 0, 0), "spine": V(-10, 0, 0), "head": V(45, 0, 0),
			"sh_l": V(165, 0, 20), "el_l": V(15, 0, 0), "sh_r": V(165, 0, -20), "el_r": V(15, 0, 0),
			"hip_l": V(-10, 0, 8), "kn_l": V(-30, 0, 0), "hip_r": V(-5, 0, -8), "kn_r": V(-15, 0, 0)}),
		# Respiration (micro-animation au repos) : garde un peu plus basse, qu'on mélange à la garde.
		"idle_breath": {"hips_pos": V(0, -0.1, 0), "spine": V(-4, 3, 0), "head": V(-10, 18, 0), "sh_l": V(52, 0, 18), "sh_r": V(42, 0, -18)},
	}


## id : champs de la fiche (les fiches existantes gardent ce qui n'est pas listé).
func moves() -> Dictionary:
	return {
		"superman": {"cancel": 99.0, "end": 99.0, "roll_ok": 99.0,
			"keys": [[0.0, "from"], [0.09, "sm_load"], [0.2, "sm_fly", "in"], [0.34, "sm_fly"], [99.0, "sm_fly"]]},
		"sm_land": {"display_name": "Superman punch (à plat ventre)", "active": 99.0, "cancel": 99.0, "end": 0.78, "roll_ok": 99.0,
			"keys": [[0.0, "from"], [0.07, "sm_down", "in"], [0.42, "sm_down"], [0.55, "sm_push"], [0.66, "crouch"], [0.78, "guard"]]},
		"drop_kick": {"cancel": 99.0, "end": 99.0, "roll_ok": 99.0,
			"keys": [[0.0, "from"], [0.08, "dk_tuck1"], [0.18, "dk_ext", "in"], [0.4, "dk_ext"], [99.0, "dk_ext"]]},
		"drop_land": {"cancel": 99.0, "end": 2.0, "roll_ok": 99.0,
			"keys": [[0.0, "from"], [0.06, "back_lie", "in"], [0.5, "back_lie"], [0.85, "back_lie2"], [1.25, "back_lie"], [1.6, "back_lie2"], [1.8, "crouch"], [2.0, "guard"]]},
		"tackle_slam": {"active": 0.14, "cancel": 0.75, "end": 0.95, "roll_ok": 0.75,
			"keys": [[0.0, "from"], [0.14, "tk_dive", "in"], [0.32, "tk_dive2"], [0.5, "tk_dive"], [0.66, "sm_push"], [0.8, "crouch"], [0.95, "guard"]]},
		"piledriver": {"keys": [[0.0, "from"], [0.12, "pd_hook"], [0.26, "pd_crouch2"], [0.34, "pd_hook"], [0.6, "pd_flat"], [99.0, "pd_flat"]]},
		"pd_land": {"cancel": 0.5, "end": 0.75,
			"keys": [[0.0, "from"], [0.05, "back_lie", "in"], [0.38, "back_lie"], [0.55, "crouch"], [0.75, "guard"]]},
		"hip_throw": {"active": 0.36, "cancel": 0.62, "end": 0.85,
			"keys": [[0.0, "from"], [0.12, "ht2_load"], [0.36, "ht2_throw", "in"], [0.55, "ht2_throw"], [0.85, "guard"]]},
		"bicycle": {"active": 0.16, "cancel": 0.42, "end": 0.6, "radius": 0.8,
			"keys": [[0.0, "from"], [0.07, "bc2_load"], [0.13, "bc2_over"], [0.2, "bc2_kick", "in"], [0.32, "bc2_kick"], [0.6, "air_rest"]]},
		"air_cross": {"display_name": "Direct aérien", "active": 0.06, "cancel": 0.14, "end": 0.24, "tip": "fist_r", "radius": 0.55, "damage": 7.0,
			"force_mult": 0.8, "drop": 0.3, "up": 0.9, "hitstop": 0.05, "shake": 0.35, "step": 2.0, "air": true, "light_air": true,
			"keys": [[0.0, "from"], [0.06, "air_cross"], [0.1, "air_cross"], [0.24, "air_rest"]]},
		"air_upper": {"display_name": "Uppercut aérien", "active": 0.1, "cancel": 0.26, "end": 0.36, "tip": "fist_l", "radius": 0.6, "damage": 14.0,
			"force_mult": 1.6, "heavy": true, "drop": 1.0, "up": 1.6, "guard_break": true, "hitstop": 0.09, "shake": 0.7, "step": 2.0, "air": true, "light_air": true,
			"keys": [[0.0, "from"], [0.05, "air_upper_load"], [0.1, "air_upper", "in"], [0.18, "air_upper"], [0.36, "air_rest"]]},
		"air_hook": {"display_name": "Crochet aérien", "active": 0.12, "cancel": 0.26, "end": 0.4, "tip": "fist_l", "radius": 0.6, "damage": 14.0,
			"force_mult": 1.6, "heavy": true, "drop": 1.0, "up": 0.4, "side": 2, "guard_break": true, "hitstop": 0.1, "shake": 0.8, "step": 2.0, "air": true, "light_air": true,
			"keys": [[0.0, "from"], [0.07, "air_hook_load"], [0.12, "air_hook", "in"], [0.18, "air_hook_through"], [0.4, "air_rest"]]},
		"air_knee": {"display_name": "Genou volant aérien", "active": 0.1, "cancel": 0.24, "end": 0.34, "tip": "kn_r", "radius": 0.6, "damage": 16.0,
			"force_mult": 0.45, "heavy": true, "drop": 1.0, "up": 2.2, "guard_break": true, "hitstop": 0.09, "shake": 0.7, "step": 2.0, "air": true, "light_air": true,
			"keys": [[0.0, "from"], [0.1, "knee_up"], [0.17, "knee_up"], [0.34, "air_rest"]]},
		"spin_counter3": {"display_name": "Contre tournant (3 tours)", "active": 0.14, "cancel": 0.72, "end": 0.85, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.05, "sc_load"], [0.12, "sc_out", "in"], [0.7, "sc_out"], [0.85, "guard"]]},
		"wall_run_h": {"display_name": "Course au mur horizontale", "active": 0.62, "cancel": 99.0, "end": 99.0, "roll_ok": 99.0, "tip": "foot_r",
			"radius": 0.7, "damage": 16.0, "force_mult": 0.9, "heavy": true, "drop": 1.0, "up": 0.3, "hitstop": 0.1, "shake": 0.9, "air": true,
			"keys": [[0.0, "from"], [0.06, "wh_run"], [0.54, "wh_run"], [0.62, "wh_kick", "in"], [99.0, "wh_kick"]]},
		"sj_grab": {"display_name": "Super saut : chope plongeante", "active": 99.0, "cancel": 99.0, "end": 99.0, "roll_ok": 99.0, "air": true,
			"keys": [[0.0, "from"], [0.1, "sj_dive"], [99.0, "sj_dive"]]},
	}


func _initialize() -> void:
	var ps := load("res://moves/poses.tres") as PoseSet
	var ps_new := poses(ps)
	for k in ps_new:
		ps.diffs[k] = ps_new[k]
	var e := ResourceSaver.save(ps, "res://moves/poses.tres")
	print("poses : ", ps_new.size(), " (", e, ")")
	var ms := moves()
	for id in ms:
		var d: Dictionary = ms[id]
		var path := "res://moves/%s.tres" % id
		var m: MoveData = load(path) if ResourceLoader.exists(path) else MoveData.new()
		m.id = id
		for k in d:
			if k == "flags":
				m.flags = PackedStringArray(d.flags)
			elif k == "keys":
				m.keys = d.keys
			else:
				m.set(k, d[k])
		if m.notes == "":
			m.notes = "Version 0.11 (retours de Paul)."
		var err := ResourceSaver.save(m, path)
		if err != OK:
			print("ERREUR ", id, " ", err)
	print("fiches : ", ms.size())
	quit()

extends SceneTree
## Outil : poses et fiches des coups de la v0.212 (« À tester » du site). Relançable : remplace ce qu'il a créé.
##   ../godot --headless --path . -s tools/gen_v0212_moves.gd
## La vague (L1 + X), toile d'araignée (R1 sans personne à portée : tir, traction, lâcher), tomoe nage (chope + B),
## désarmer (X juste après une parade), pluie d'objets (R2).

const N := null


func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


func poses() -> Dictionary:
	var air_legs := {"foot_l": N, "foot_r": N}
	return {
		# La vague : un bras en haut, l'autre en bas, puis l'inverse (la vague passe d'un bras à l'autre par les épaules).
		"wv_a": {"hips_pos": V(0, -0.05, 0), "hips": V(0, 12, 0), "spine": V(4, 10, 12), "head": V(-6, -12, 0),
			"sh_l": V(172, 0, 18), "el_l": V(18, 0, 0), "sh_r": V(25, 0, -60), "el_r": V(85, 0, 0)},
		"wv_b": {"hips_pos": V(0, -0.05, 0), "hips": V(0, -12, 0), "spine": V(4, -10, -12), "head": V(-6, 12, 0),
			"sh_r": V(172, 0, -18), "el_r": V(18, 0, 0), "sh_l": V(25, 0, 60), "el_l": V(85, 0, 0)},
		"wv_c": {"hips_pos": V(0, 0.03, 0), "hips": V(6, 0, 0), "spine": V(14, 0, 0), "head": V(-20, 0, 0),
			"sh_l": V(176, 0, 28), "el_l": V(8, 0, 0), "sh_r": V(176, 0, -28), "el_r": V(8, 0, 0)},
		# Toile d'araignée : bras tendu, main ouverte ; traction (le bras revient, il se penche en arrière) ; lâcher (bras qui fouette).
		"web_aim": {"hips_pos": V(0, -0.1, 0), "hips": V(0, -18, 0), "spine": V(-6, -25, 0), "head": V(0, 25, 0),
			"sh_r": V(92, 0, -4), "el_r": V(0, 0, 0), "sh_l": V(60, 0, 30), "el_l": V(110, 0, 0)},
		"web_pull": {"hips_pos": V(0, -0.18, 0.06), "hips": V(14, 15, 0), "spine": V(-12, 22, 0), "head": V(10, -15, 0),
			"sh_r": V(65, 0, -35), "el_r": V(125, 0, 0), "sh_l": V(35, 0, 45), "el_l": V(80, 0, 0),
			"foot_l": V(-0.2, 0.02, -0.25), "foot_r": V(0.2, 0.02, 0.25)},
		"web_fling": {"hips_pos": V(0, -0.1, 0), "hips": V(-8, -30, 0), "spine": V(-18, -35, 0), "head": V(10, 30, 0),
			"sh_r": V(150, 0, -25), "el_r": V(10, 0, 0), "sh_l": V(40, 0, 40), "el_l": V(90, 0, 0)},
		# Tomoe nage : il s'assoit en arrière, pied dans le ventre de l'ennemi, roule sur le dos et le fait passer par-dessus.
		"tm_sit": air_legs.merged({"hips_pos": V(0, -0.55, 0.22), "hips": V(42, 0, 0), "spine": V(12, 0, 0), "head": V(14, 0, 0),
			"sh_l": V(100, 0, 30), "el_l": V(60, 0, 0), "sh_r": V(100, 0, -30), "el_r": V(60, 0, 0),
			"hip_r": V(115, 0, 0), "kn_r": V(-60, 0, 0), "hip_l": V(60, 0, 8), "kn_l": V(-95, 0, 0)}),
		"tm_back": air_legs.merged({"hips_pos": V(0, -0.72, 0.15), "hips": V(98, 0, 0), "spine": V(10, 0, 0), "head": V(-12, 0, 0),
			"sh_l": V(160, 0, 30), "el_l": V(30, 0, 0), "sh_r": V(160, 0, -30), "el_r": V(30, 0, 0),
			"hip_r": V(150, 0, 0), "kn_r": V(-8, 0, 0), "hip_l": V(95, 0, 8), "kn_l": V(-80, 0, 0)}),
		# Désarmer : la main fonce sur l'arme, puis la ramène contre lui.
		"dis_grab": {"hips_pos": V(0, -0.14, 0), "hips": V(-10, -15, 0), "spine": V(-16, -22, 0), "head": V(6, 20, 0),
			"sh_r": V(78, 0, -10), "el_r": V(8, 0, 0), "sh_l": V(70, 0, 30), "el_l": V(100, 0, 0)},
		"dis_pull": {"hips_pos": V(0, -0.08, 0.04), "hips": V(4, 22, 0), "spine": V(6, 28, 0), "head": V(0, -18, 0),
			"sh_r": V(45, 0, -55), "el_r": V(130, 0, 0), "sh_l": V(80, 0, 20), "el_l": V(110, 0, 0)},
		# Pluie d'objets : bras levés en V (les objets s'envolent), puis les deux bras pointés devant.
		"rain_up": {"hips_pos": V(0, 0.03, 0), "hips": V(4, 0, 0), "spine": V(14, 0, 0), "head": V(-28, 0, 0),
			"sh_l": V(165, 0, 45), "el_l": V(10, 0, 0), "sh_r": V(165, 0, -45), "el_r": V(10, 0, 0)},
		"rain_point": {"hips_pos": V(0, -0.12, 0), "hips": V(-8, 0, 0), "spine": V(-18, 0, 0), "head": V(12, 0, 0),
			"sh_l": V(98, 0, 25), "el_l": V(0, 0, 0), "sh_r": V(98, 0, -25), "el_r": V(0, 0, 0),
			"foot_l": V(-0.2, 0.02, -0.2), "foot_r": V(0.2, 0.02, 0.22)},
	}


func moves() -> Dictionary:
	return {
		"wave": {"display_name": "La vague", "active": 0.5, "cancel": 1.0, "end": 1.15, "hitstop": 0.06, "shake": 0.6, "flags": ["v212"],
			"keys": [[0.0, "from"], [0.12, "wv_a"], [0.3, "wv_b", "inout"], [0.48, "wv_a", "inout"], [0.66, "wv_b", "inout"], [0.84, "wv_c", "inout"], [1.15, "guard", "inout"]]},
		"web": {"display_name": "Toile d'araignée (tir et traction)", "active": 0.08, "cancel": 99.0, "end": 99.0, "flags": ["v212"],
			"keys": [[0.0, "from"], [0.08, "web_aim"], [0.3, "web_pull", "inout"], [99.0, "web_pull"]]},
		"web_throw": {"display_name": "Toile d'araignée (lâcher)", "active": 99.0, "cancel": 0.25, "end": 0.4,
			"keys": [[0.0, "from"], [0.1, "web_fling"], [0.4, "guard", "inout"]]},
		"tomoe": {"display_name": "Tomoe nage", "active": 0.34, "cancel": 0.8, "end": 0.95, "hitstop": 0.08, "shake": 0.8, "flags": ["v212"],
			"keys": [[0.0, "from"], [0.12, "tm_sit"], [0.32, "tm_back", "inout"], [0.55, "back_lie"], [0.78, "crouch", "inout"], [0.95, "guard", "inout"]]},
		"disarm": {"display_name": "Désarmer", "active": 0.1, "cancel": 0.3, "end": 0.42, "hitstop": 0.07, "shake": 0.5, "flags": ["v212"],
			"keys": [[0.0, "from"], [0.08, "dis_grab"], [0.2, "dis_pull"], [0.42, "guard", "inout"]]},
		"rain": {"display_name": "Pluie d'objets", "active": 0.55, "cancel": 0.9, "end": 1.15, "hitstop": 0.05, "shake": 0.7, "flags": ["v212"],
			"keys": [[0.0, "from"], [0.18, "rain_up"], [0.55, "rain_up"], [0.75, "rain_point", "in"], [1.15, "guard", "inout"]]},
	}


func _initialize() -> void:
	var ps := load("res://moves/poses.tres") as PoseSet
	var ps_new := poses()
	for k in ps_new:
		ps.diffs[k] = ps_new[k]
	print("poses : ", ps_new.size(), " (", ResourceSaver.save(ps, "res://moves/poses.tres"), ")")
	var ms := moves()
	for id in ms:
		var d: Dictionary = ms[id]
		var m := MoveData.new()
		m.id = id
		for k in d:
			if k == "flags":
				m.flags = PackedStringArray(d.flags)
			elif k == "keys":
				m.keys = d.keys
			else:
				m.set(k, d[k])
		m.notes = "v0.212 (à tester)."
		var err := ResourceSaver.save(m, "res://moves/%s.tres" % id)
		if err != OK:
			print("ERREUR ", id, " ", err)
	print("fiches : ", ms.size())
	quit()

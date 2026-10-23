extends SceneTree
## Outil (à lancer une fois, sans écran) : ajoute les poses et les fiches des coups de l'atelier (statut « À tester »).
##   ../godot --headless --path . -s tools/gen_atelier_moves.gd
## Relançable : il remplace les poses et fiches qu'il a lui-même créées.

const N := null

func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


func poses() -> Dictionary:
	var air_legs := {"foot_l": N, "foot_r": N}
	return {
		# Superman punch : armé accroupi, poing droit tiré en arrière ; puis vol à l'horizontale, poing tendu.
		"sm_load": {"hips_pos": V(0, -0.24, 0.05), "hips": V(-10, 30, 0), "spine": V(-18, 32, 0), "head": V(-8, -30, 0),
			"sh_l": V(75, 0, 22), "el_l": V(105, 0, 0), "sh_r": V(-35, 0, -25), "el_r": V(125, 0, 0),
			"foot_l": V(-0.16, 0.02, -0.32), "foot_r": V(0.18, 0.02, 0.3)},
		"sm_fly": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(-62, -15, 0), "spine": V(-12, -25, 0), "head": V(40, 30, 0),
			"sh_l": V(35, 0, 35), "el_l": V(115, 0, 0), "sh_r": V(172, 0, -5), "el_r": V(0, 0, 0),
			"hip_l": V(-20, 0, 6), "kn_l": V(-45, 0, 0), "hip_r": V(-35, 0, -6), "kn_r": V(-12, 0, 0)}),
		# Drop kick : à plat sur le dos (après), relevé.
		"back_lie": air_legs.merged({"hips_pos": V(0, -0.72, -0.05), "hips": V(86, 0, 0), "spine": V(4, 0, 0), "head": V(-20, 0, 0),
			"sh_l": V(100, 0, 65), "el_l": V(20, 0, 0), "sh_r": V(100, 0, -65), "el_r": V(20, 0, 0),
			"hip_l": V(-4, 0, 8), "kn_l": V(-15, 0, 0), "hip_r": V(-4, 0, -8), "kn_r": V(-25, 0, 0)}),
		# Plaquage : course épaule en avant, puis écrasé au sol à genoux.
		"tk_run": air_legs.merged({"hips_pos": V(0, -0.16, 0), "hips": V(-48, 0, 0), "spine": V(-18, -10, 0), "head": V(45, 0, 0),
			"sh_l": V(85, 0, 45), "el_l": V(55, 0, 0), "sh_r": V(85, 0, -45), "el_r": V(55, 0, 0),
			"hip_l": V(45, 0, 0), "kn_l": V(-70, 0, 0), "hip_r": V(-35, 0, 0), "kn_r": V(-85, 0, 0)}),
		"tk_slam": {"hips_pos": V(0, -0.46, -0.12), "hips": V(-45, 0, 0), "spine": V(-30, 0, 0), "head": V(35, 0, 0),
			"sh_l": V(100, 0, 15), "el_l": V(10, 0, 0), "sh_r": V(100, 0, -15), "el_r": V(10, 0, 0),
			"foot_l": V(-0.16, 0.02, -0.38), "foot_r": V(0.16, 0.02, 0.45)},
		# Suplex : il le prend à la taille, se redresse, puis se cambre en pont : l'ennemi passe par-dessus sa tête.
		"sx_grip": {"hips_pos": V(0, -0.26, 0), "hips": V(-15, 0, 0), "spine": V(-12, 0, 0), "head": V(12, 0, 0),
			"sh_l": V(85, 0, 42), "el_l": V(100, 0, 0), "sh_r": V(85, 0, -42), "el_r": V(100, 0, 0),
			"foot_l": V(-0.18, 0.02, -0.15), "foot_r": V(0.18, 0.02, 0.15)},
		"sx_lift": {"hips_pos": V(0, -0.1, 0.05), "hips": V(15, 0, 0), "spine": V(28, 0, 0), "head": V(25, 0, 0),
			"sh_l": V(125, 0, 22), "el_l": V(60, 0, 0), "sh_r": V(125, 0, -22), "el_r": V(60, 0, 0),
			"foot_l": V(-0.18, 0.02, -0.12), "foot_r": V(0.18, 0.02, 0.12)},
		"sx_arch": {"hips_pos": V(0, -0.36, 0.38), "hips": V(58, 0, 0), "spine": V(62, 0, 0), "head": V(60, 0, 0),
			"sh_l": V(172, 0, 18), "el_l": V(20, 0, 0), "sh_r": V(172, 0, -18), "el_r": V(20, 0, 0),
			"foot_l": V(-0.18, 0.02, -0.18), "foot_r": V(0.18, 0.02, -0.18)},
		# Prise de catch : soulevé par le cou à bout de bras, saut, et il l'écrase sur le dos.
		"pd_lift": {"hips_pos": V(0, -0.04, 0), "hips": V(8, 0, 0), "spine": V(12, 0, 0), "head": V(18, 0, 0),
			"sh_l": V(120, 0, 25), "el_l": V(45, 0, 0), "sh_r": V(172, 0, -8), "el_r": V(8, 0, 0),
			"foot_l": V(-0.17, 0.02, -0.2), "foot_r": V(0.17, 0.02, 0.2)},
		"pd_crouch": {"hips_pos": V(0, -0.32, 0), "hips": V(-12, 0, 0), "spine": V(-8, 0, 0), "head": V(20, 0, 0),
			"sh_l": V(150, 0, 20), "el_l": V(25, 0, 0), "sh_r": V(172, 0, -8), "el_r": V(8, 0, 0),
			"foot_l": V(-0.2, 0.02, -0.15), "foot_r": V(0.2, 0.02, 0.15)},
		"pd_air": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(-5, 0, 0), "spine": V(5, 0, 0), "head": V(10, 0, 0),
			"sh_l": V(165, 0, 15), "el_l": V(15, 0, 0), "sh_r": V(165, 0, -15), "el_r": V(15, 0, 0),
			"hip_l": V(70, 0, 0), "kn_l": V(-95, 0, 0), "hip_r": V(60, 0, 0), "kn_r": V(-100, 0, 0)}),
		# Projection de hanche : il se retourne dans l'ennemi, puis se plie en avant en tirant.
		"ht_turn": {"hips_pos": V(0, -0.3, 0), "hips": V(0, 135, 0), "spine": V(-20, 25, 0), "head": V(0, -70, 0),
			"sh_l": V(95, 0, 20), "el_l": V(60, 0, 0), "sh_r": V(70, 0, -35), "el_r": V(85, 0, 0),
			"foot_l": V(-0.14, 0.02, -0.12), "foot_r": V(0.14, 0.02, -0.05)},
		"ht_throw": {"hips_pos": V(0, -0.36, 0), "hips": V(-40, 150, 0), "spine": V(-40, 10, 0), "head": V(30, -40, 0),
			"sh_l": V(40, 0, 12), "el_l": V(20, 0, 0), "sh_r": V(40, 0, -12), "el_r": V(20, 0, 0),
			"foot_l": V(-0.16, 0.02, -0.12), "foot_r": V(0.16, 0.02, -0.05)},
		# Râpe à fromage : il traîne l'ennemi contre le mur, bras tendus vers le mur (à gauche ou à droite).
		"cg_drag_l": {"hips_pos": V(0, -0.15, 0), "hips": V(-15, 30, 0), "spine": V(-12, 30, 0), "head": V(5, 40, 0),
			"sh_l": V(30, 0, -85), "el_l": V(10, 0, 0), "sh_r": V(80, 50, 0), "el_r": V(30, 0, 0)},
		"cg_drag_r": {"hips_pos": V(0, -0.15, 0), "hips": V(-15, -30, 0), "spine": V(-12, -30, 0), "head": V(5, -40, 0),
			"sh_r": V(30, 0, 85), "el_r": V(10, 0, 0), "sh_l": V(80, -50, 0), "el_l": V(30, 0, 0)},
		# Objet-bouclier : l'objet tenu devant la poitrine.
		"ps_hold": {"hips_pos": V(0, -0.16, 0.02), "hips": V(0, -5, 0), "spine": V(-12, 0, 0), "head": V(8, 0, 0),
			"sh_l": V(88, 0, 14), "el_l": V(70, 0, 0), "sh_r": V(88, 0, -14), "el_r": V(70, 0, 0)},
		# Coups tournants (le perso entier tourne) : revers bras tendu ; capoeira mains au sol, jambe tendue.
		"sc_load": {"hips_pos": V(0, -0.18, 0), "hips": V(0, 55, 0), "spine": V(-10, 30, 0), "head": V(0, -40, 0),
			"sh_l": V(0, -55, -80), "el_l": V(90, 0, 0), "sh_r": V(55, 0, -20), "el_r": V(120, 0, 0)},
		"sc_out": {"hips_pos": V(0, -0.16, 0), "hips": V(0, -20, 0), "spine": V(-12, -20, 12), "head": V(-5, 30, 0),
			"sh_l": V(5, 15, -92), "el_l": V(5, 0, 0), "sh_r": V(50, 0, -30), "el_r": V(125, 0, 0)},
		"cp_hands": {"hips_pos": V(0, -0.58, 0.05), "hips": V(-55, 0, 0), "spine": V(-28, 0, 0), "head": V(45, 0, 0),
			"sh_l": V(100, 0, 30), "el_l": V(0, 0, 0), "sh_r": V(100, 0, -30), "el_r": V(0, 0, 0),
			"foot_l": V(-0.12, 0.02, 0.12), "foot_r": N, "hip_r": V(35, 0, 75), "kn_r": V(-5, 0, 0)},
		# Poing marteau : deux poings joints au-dessus de la tête.
		"hf_up": {"hips_pos": V(0, 0.02, 0.02), "hips": V(8, 0, 0), "spine": V(18, 0, 0), "head": V(-12, 0, 0),
			"sh_l": V(176, 0, 6), "el_l": V(22, 0, 0), "sh_r": V(176, 0, -6), "el_r": V(22, 0, 0),
			"foot_l": V(-0.2, 0.02, -0.15), "foot_r": V(0.2, 0.02, 0.15)},
		# Shoot (ennemi couché ou objet) : jambe armée loin derrière, puis frappe en se penchant en arrière.
		"sk2_back": {"hips_pos": V(0, -0.06, 0), "hips": V(0, 18, 0), "spine": V(12, 10, 0), "head": V(-20, 0, 0),
			"sh_l": V(45, 0, 35), "el_l": V(40, 0, 0), "sh_r": V(-25, 0, -25), "el_r": V(30, 0, 0),
			"foot_l": V(-0.1, 0.02, -0.15), "foot_r": N, "hip_r": V(-60, 0, 0), "kn_r": V(-105, 0, 0)},
		"sk2_kick": {"hips_pos": V(0, -0.05, -0.05), "hips": V(0, -18, 0), "spine": V(32, -10, 0), "head": V(-25, 0, 0),
			"sh_l": V(-40, 0, -45), "el_l": V(20, 0, 0), "sh_r": V(65, 0, -45), "el_r": V(30, 0, 0),
			"foot_l": V(-0.08, 0.02, -0.05), "foot_r": N, "hip_r": V(95, 0, 0), "kn_r": V(-5, 0, 0)},
		# Rafale de poings : gauche, droite.
		"rush_l": {"hips_pos": V(0, -0.12, -0.06), "hips": V(0, -12, 0), "spine": V(-15, 18, 0), "head": V(-8, -15, 0),
			"sh_l": V(92, 12, 0), "el_l": V(0, 0, 0), "sh_r": V(55, 0, -18), "el_r": V(125, 0, 0),
			"foot_l": V(-0.13, 0.02, -0.34)},
		"rush_r": {"hips_pos": V(0, -0.12, -0.06), "hips": V(0, 14, 0), "spine": V(-15, -18, 0), "head": V(-8, 15, 0),
			"sh_r": V(92, -12, 0), "el_r": V(0, 0, 0), "sh_l": V(55, 0, 18), "el_l": V(115, 0, 0),
			"foot_l": V(-0.13, 0.02, -0.34)},
		# Moulinet : jambe droite tendue à l'horizontale, bras écartés (le perso entier tourne).
		"mill": {"hips_pos": V(0, -0.05, 0), "hips": V(14, 0, 0), "spine": V(8, 0, 0), "head": V(-10, 0, 0),
			"sh_l": V(25, 0, -80), "el_l": V(10, 0, 0), "sh_r": V(25, 0, 80), "el_r": V(10, 0, 0),
			"foot_l": V(0, 0.02, 0.02), "foot_r": N, "hip_r": V(92, 0, 0), "kn_r": V(0, 0, 0)},
		# Coup de chaise : objet levé au-dessus de la tête, puis abattu devant.
		"pb_up": {"hips_pos": V(0, -0.04, 0.05), "hips": V(12, 0, 0), "spine": V(26, 0, 0), "head": V(-8, 0, 0),
			"sh_l": V(170, 0, 10), "el_l": V(35, 0, 0), "sh_r": V(170, 0, -10), "el_r": V(35, 0, 0),
			"foot_l": V(-0.16, 0.02, -0.22), "foot_r": V(0.16, 0.02, 0.22)},
		"pb_down": {"hips_pos": V(0, -0.26, -0.06), "hips": V(-10, 0, 0), "spine": V(-36, 0, 0), "head": V(28, 0, 0),
			"sh_l": V(55, 0, 10), "el_l": V(10, 0, 0), "sh_r": V(55, 0, -10), "el_r": V(10, 0, 0),
			"foot_l": V(-0.18, 0.02, -0.38), "foot_r": V(0.18, 0.02, 0.25)},
		# Course au mur : il court sur le mur (penché en arrière), salto arrière en boule, puis piqué pieds en avant.
		"wr_run1": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(55, 0, 0), "spine": V(-25, 0, 0), "head": V(-25, 0, 0),
			"sh_l": V(-35, 0, 15), "el_l": V(80, 0, 0), "sh_r": V(80, 0, -15), "el_r": V(80, 0, 0),
			"hip_l": V(105, 0, 0), "kn_l": V(-70, 0, 0), "hip_r": V(25, 0, 0), "kn_r": V(-30, 0, 0)}),
		"wr_run2": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(55, 0, 0), "spine": V(-25, 0, 0), "head": V(-25, 0, 0),
			"sh_l": V(80, 0, 15), "el_l": V(80, 0, 0), "sh_r": V(-35, 0, -15), "el_r": V(80, 0, 0),
			"hip_l": V(25, 0, 0), "kn_l": V(-30, 0, 0), "hip_r": V(105, 0, 0), "kn_r": V(-70, 0, 0)}),
		"bf_1": air_legs.merged({"hips_pos": V(0, 0.1, 0), "hips": V(120, 0, 0), "spine": V(-30, 0, 0), "head": V(-20, 0, 0),
			"sh_l": V(70, 0, 10), "el_l": V(120, 0, 0), "sh_r": V(70, 0, -10), "el_r": V(120, 0, 0),
			"hip_l": V(125, 0, 0), "kn_l": V(-145, 0, 0), "hip_r": V(125, 0, 0), "kn_r": V(-145, 0, 0)}),
		"bf_2": air_legs.merged({"hips_pos": V(0, 0.1, 0), "hips": V(240, 0, 0), "spine": V(-30, 0, 0), "head": V(-20, 0, 0),
			"sh_l": V(70, 0, 10), "el_l": V(120, 0, 0), "sh_r": V(70, 0, -10), "el_r": V(120, 0, 0),
			"hip_l": V(125, 0, 0), "kn_l": V(-145, 0, 0), "hip_r": V(125, 0, 0), "kn_r": V(-145, 0, 0)}),
		"wr_dive": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(410, 0, 0), "spine": V(-10, 0, 0), "head": V(-30, 0, 0),
			"sh_l": V(150, 0, 30), "el_l": V(10, 0, 0), "sh_r": V(150, 0, -30), "el_r": V(10, 0, 0),
			"hip_l": V(70, 0, 0), "kn_l": V(-120, 0, 0), "hip_r": V(-5, 0, 0), "kn_r": V(0, 0, 0)}),
		# Bicyclette : renversé en arrière, la jambe passe au-dessus de la tête.
		"bc_load": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(70, 0, 0), "spine": V(-10, 0, 0), "head": V(-30, 0, 0),
			"sh_l": V(-30, 0, 40), "el_l": V(30, 0, 0), "sh_r": V(-30, 0, -40), "el_r": V(30, 0, 0),
			"hip_l": V(125, 0, 0), "kn_l": V(-35, 0, 0), "hip_r": V(20, 0, 0), "kn_r": V(-70, 0, 0)}),
		"bc_kick": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(125, 0, 0), "spine": V(-12, 0, 0), "head": V(-45, 0, 0),
			"sh_l": V(-50, 0, 55), "el_l": V(20, 0, 0), "sh_r": V(-50, 0, -55), "el_r": V(20, 0, 0),
			"hip_l": V(15, 0, 0), "kn_l": V(-70, 0, 0), "hip_r": V(125, 0, 0), "kn_r": V(0, 0, 0)}),
		# Trampoline / super saut : groupé, puis grand ouvert bras en V.
		"tramp_tuck": air_legs.merged({"hips_pos": V(0, 0.05, 0), "hips": V(-15, 0, 0), "spine": V(-15, 0, 0), "head": V(10, 0, 0),
			"sh_l": V(60, 0, 15), "el_l": V(110, 0, 0), "sh_r": V(60, 0, -15), "el_r": V(110, 0, 0),
			"hip_l": V(115, 0, 0), "kn_l": V(-135, 0, 0), "hip_r": V(115, 0, 0), "kn_r": V(-135, 0, 0)}),
		"tramp_open": air_legs.merged({"hips_pos": V(0, 0, 0), "hips": V(0, 0, 0), "spine": V(5, 0, 0), "head": V(-18, 0, 0),
			"sh_l": V(172, 0, 32), "el_l": V(5, 0, 0), "sh_r": V(172, 0, -32), "el_r": V(5, 0, 0),
			"hip_l": V(-4, 0, 6), "kn_l": V(-6, 0, 0), "hip_r": V(-4, 0, -6), "kn_r": V(-6, 0, 0)}),
	}


## id : [nom affiché, durées, frappe, clés, comportements]
func moves() -> Dictionary:
	return {
		"superman": {"display_name": "Superman punch", "active": 0.2, "cancel": 0.5, "end": 0.6, "tip": "fist_r", "radius": 0.55, "damage": 18.0,
			"force_mult": 0.9, "heavy": true, "drop": 1.0, "up": 0.35, "guard_break": true, "hitstop": 0.11, "shake": 0.9, "air": true,
			"keys": [[0.0, "from"], [0.09, "sm_load"], [0.2, "sm_fly", "in"], [0.34, "sm_fly"], [0.6, "air_rest"]]},
		"drop_kick": {"display_name": "Drop kick", "active": 0.18, "cancel": 0.6, "end": 0.7, "tip": "foot_r", "radius": 0.7, "damage": 24.0,
			"force_mult": 1.25, "heavy": true, "drop": 1.0, "up": 0.35, "guard_break": true, "hitstop": 0.13, "shake": 1.1, "air": true,
			"keys": [[0.0, "from"], [0.08, "dk_tuck1"], [0.18, "dk_ext", "in"], [0.4, "dk_ext"], [0.7, "dk_ext"]]},
		"drop_land": {"display_name": "Drop kick (réception sur le dos)", "active": 99.0, "cancel": 0.6, "end": 0.85,
			"keys": [[0.0, "from"], [0.06, "back_lie"], [0.45, "back_lie"], [0.65, "crouch"], [0.85, "guard"]]},
		"tackle": {"display_name": "Plaquage", "active": 99.0, "cancel": 99.0, "end": 99.0, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.08, "tk_run"], [99.0, "tk_run"]]},
		"tackle_slam": {"display_name": "Plaquage (écrasé au sol)", "active": 0.12, "cancel": 0.35, "end": 0.6, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.12, "tk_slam", "in"], [0.32, "tk_slam"], [0.6, "guard"]]},
		"suplex": {"display_name": "Suplex", "active": 0.5, "cancel": 0.8, "end": 1.05, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.1, "sx_grip"], [0.3, "sx_lift"], [0.5, "sx_arch", "in"], [0.75, "sx_arch"], [1.05, "guard"]]},
		"piledriver": {"display_name": "Prise de catch (soulevé par le cou)", "active": 99.0, "cancel": 99.0, "end": 99.0, "air": true, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.15, "pd_lift"], [0.3, "pd_crouch"], [0.42, "pd_air"], [99.0, "pd_air"]]},
		"pd_land": {"display_name": "Prise de catch (écrasé)", "active": 99.0, "cancel": 0.35, "end": 0.6,
			"keys": [[0.0, "from"], [0.05, "pound", "in"], [0.32, "pound"], [0.6, "guard"]]},
		"hip_throw": {"display_name": "Projection de hanche", "active": 0.32, "cancel": 0.6, "end": 0.8, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.12, "ht_turn"], [0.32, "ht_throw", "in"], [0.5, "ht_throw"], [0.8, "guard"]]},
		"cheese_grater": {"display_name": "Râpe à fromage", "active": 99.0, "cancel": 99.0, "end": 99.0, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.12, "cg_drag_l"], [99.0, "cg_drag_l"]]},
		"cheese_grater_r": {"display_name": "Râpe à fromage (mur à droite)", "active": 99.0, "cancel": 99.0, "end": 99.0, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.12, "cg_drag_r"], [99.0, "cg_drag_r"]]},
		"prop_shield": {"display_name": "Objet-bouclier", "active": 99.0, "cancel": 99.0, "end": 99.0,
			"keys": [[0.0, "from"], [0.12, "ps_hold"], [99.0, "ps_hold"]]},
		"spin_counter": {"display_name": "Contre tournant", "active": 0.14, "cancel": 0.32, "end": 0.45, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.05, "sc_load"], [0.12, "sc_out", "in"], [0.3, "sc_out"], [0.45, "guard"]]},
		"capoeira": {"display_name": "Retourné capoeira", "active": 0.12, "cancel": 0.42, "end": 0.6, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.08, "cp_hands"], [0.42, "cp_hands"], [0.6, "guard"]]},
		"hammer_fist": {"display_name": "Poing marteau", "active": 0.22, "cancel": 0.4, "end": 0.6, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.12, "hf_up"], [0.22, "pound", "in"], [0.4, "pound"], [0.6, "guard"]]},
		"soccer_kick": {"display_name": "Shoot de foot", "active": 0.19, "cancel": 0.32, "end": 0.55, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.11, "sk2_back"], [0.19, "sk2_kick", "in"], [0.3, "sk2_kick"], [0.55, "guard"]]},
		"prop_kick": {"display_name": "Shoot d'objet", "active": 0.19, "cancel": 0.32, "end": 0.55, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.11, "sk2_back"], [0.19, "sk2_kick", "in"], [0.3, "sk2_kick"], [0.55, "guard"]]},
		"rush": {"display_name": "Rafale de poings", "active": 99.0, "cancel": 99.0, "end": 99.0, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.04, "rush_l"], [0.08, "rush_r"], [0.12, "rush_l"], [0.16, "rush_r"], [99.0, "rush_r"]]},
		"rush_end": {"display_name": "Rafale de poings (dernier coup)", "active": 0.14, "cancel": 0.3, "end": 0.42, "tip": "fist_l", "radius": 0.6,
			"damage": 14.0, "force_mult": 1.2, "heavy": true, "drop": 1.0, "up": 1.0, "guard_break": true, "hitstop": 0.12, "shake": 0.9,
			"keys": [[0.0, "from"], [0.07, "upper_load"], [0.14, "upper", "in"], [0.22, "upper"], [0.42, "guard"]]},
		"leg_mill": {"display_name": "Moulinet de jambes", "active": 99.0, "cancel": 99.0, "end": 99.0, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.08, "mill"], [99.0, "mill"]]},
		"prop_bash": {"display_name": "Coup de chaise", "active": 0.2, "cancel": 0.35, "end": 0.5, "flags": ["atelier"],
			"keys": [[0.0, "from"], [0.1, "pb_up"], [0.2, "pb_down", "in"], [0.32, "pb_down"], [0.5, "grab_lift"]]},
		"wall_run": {"display_name": "Course au mur", "active": 0.58, "cancel": 99.0, "end": 99.0, "tip": "foot_r", "radius": 0.65, "damage": 18.0,
			"force_mult": 0.9, "heavy": true, "drop": 1.0, "up": 0.3, "hitstop": 0.1, "shake": 0.9, "air": true,
			"keys": [[0.0, "from"], [0.08, "wr_run1"], [0.18, "wr_run2"], [0.28, "wr_run1"], [0.38, "bf_1"], [0.5, "bf_2"], [0.58, "wr_dive", "in"], [99.0, "wr_dive"]]},
		"bicycle": {"display_name": "Bicyclette", "active": 0.18, "cancel": 0.4, "end": 0.55, "tip": "foot_r", "radius": 0.7, "damage": 20.0,
			"force_mult": 1.0, "heavy": true, "drop": 1.0, "up": -1.3, "hitstop": 0.12, "shake": 1.0, "air": true,
			"keys": [[0.0, "from"], [0.08, "bc_load"], [0.18, "bc_kick", "in"], [0.3, "bc_kick"], [0.55, "air_rest"]]},
		"tramp": {"display_name": "Trampoline", "active": 99.0, "cancel": 0.15, "end": 0.6, "air": true,
			"keys": [[0.0, "from"], [0.06, "tramp_tuck"], [0.28, "tramp_open"], [0.6, "air_rest"]]},
		"super_jump": {"display_name": "Super saut", "active": 99.0, "cancel": 0.3, "end": 99.0, "air": true,
			"keys": [[0.0, "from"], [0.1, "tramp_tuck"], [0.35, "tramp_open"], [99.0, "tramp_open"]]},
	}


func _initialize() -> void:
	var ps := load("res://moves/poses.tres") as PoseSet
	var ps_new := poses()
	for k in ps_new:
		ps.diffs[k] = ps_new[k]
	var e := ResourceSaver.save(ps, "res://moves/poses.tres")
	print("poses : ", ps_new.size(), " (", e, ")")
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
		m.notes = "Atelier des coups (à tester)."
		var err := ResourceSaver.save(m, "res://moves/%s.tres" % id)
		if err != OK:
			print("ERREUR ", id, " ", err)
	print("fiches : ", ms.size())
	quit()

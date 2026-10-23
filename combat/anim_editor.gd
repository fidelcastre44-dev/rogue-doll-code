extends Node3D
## Éditeur d'animation des coups (F3), pour retoucher les poses clés sans toucher au code.
##
## Au centre : le héros en cubes ; on attrape un membre à la souris et on le fait tourner (anneau de rotation autour de
## l'articulation), ou on règle finement avec les curseurs X / Y / Z. Vue de profil fixe par défaut (Tab : vue 3D libre).
## En bas : la frise des poses clés (ajouter, supprimer, déplacer une clé pour changer le rythme), la courbe entre deux clés,
## lecture en boucle, ralenti, image par image, pelure d'oignon (clé précédente en transparence). Un sbire en face pour juger l'impact.
## À droite : versions nommées du coup ; celle qui est cochée est celle que le jeu utilise (enregistrée dans user://, voir AnimStore).
## « Tout exporter » : un seul fichier avec toutes les animations modifiées, à déposer sur le site (Atelier Rogue Doll).
##
## L'ergonomie va bouger (Thibaud donnera ses préférences) : raccourcis, couleurs et tailles sont regroupés dans CONFIG,
## l'interface est construite dans _build_ui, la souris dans _unhandled_input.

const PLAYER := preload("res://player.gd")
const JOINTS := AnimStore.JOINTS
const JOINT_NAMES := {"hips": "Bassin", "spine": "Buste", "head": "Tête", "sh_l": "Épaule G", "el_l": "Coude G", "sh_r": "Épaule D",
	"el_r": "Coude D", "hip_l": "Hanche G", "kn_l": "Genou G", "hip_r": "Hanche D", "kn_r": "Genou D"}
const PARENT := {"hips": "", "spine": "hips", "head": "spine", "sh_l": "spine", "el_l": "sh_l", "sh_r": "spine", "el_r": "sh_r",
	"hip_l": "hips", "kn_l": "hip_l", "hip_r": "hips", "kn_r": "hip_r"}
const MIRROR := {"sh_l": "sh_r", "sh_r": "sh_l", "el_l": "el_r", "el_r": "el_l", "hip_l": "hip_r", "hip_r": "hip_l", "kn_l": "kn_r", "kn_r": "kn_l"}
const FPS := 60.0   # une « image » de la frise

## Réglages d'ergonomie (à adapter aux préférences de Thibaud).
const CONFIG := {
	"pick_radius": 34.0,          # px : distance de la souris à un membre pour l'attraper
	"ring_radius": 48.0,          # px : anneau de rotation autour de l'articulation choisie
	"snap_frames": true,          # les clés déplacées s'aimantent aux images (1/60 s) ; Ctrl = sans aimant
	"speeds": [1.0, 0.5, 0.25, 0.1],
	"sel_color": Color(1.0, 0.8, 0.2),
	"hero_color": Color(0.25, 0.45, 0.85),
	"foe_color": Color(0.85, 0.3, 0.25),
	"ghost_color": Color(0.6, 0.85, 1.0, 0.28),
	"timeline_h": 96,
}

## Coups du labo -> animations (fiches) qui les composent. Les coups dont le mouvement est calculé par le code
## (roulade, balayage, tacle glissé, strafe) n'ont pas d'animation à clés : ils ne sont pas encore modifiables ici.
const CARD_MOVES := {
	"mseed00": ["jab", "cross", "jab2"], "mseed01": ["upper", "hook", "knee"], "mseed02": ["air", "air_cross", "air_upper", "air_hook", "air_knee"],
	"mseed04": ["flop_prep", "flop", "flop_land"], "mseed16": ["spin_counter", "spin_counter3"], "mseed19": ["prop_bash"],
	"mseed05": ["kick", "kick2", "kick3", "hikick", "spinkick", "axe", "quake"], "mseed06": ["air_bigknee", "air_kick", "dive_kick"],
	"mseed07": ["charge", "charge_sho", "charge_hado", "shoryu", "hadoken"], "mseed26": ["bicycle"], "mseed25": ["capoeira"],
	"mseed29": ["soccer_kick"], "mseed27": ["wall_run", "wall_run_h"], "mseed28": ["prop_kick"],
	"mseed24": ["run_kick"], "mseed08": ["grab", "collar", "collar_punch", "headbutt", "slam", "collar_finish"],
	"mseed09": ["swing", "swing_finish"], "mseed10": ["air_slam", "airslam_land"], "mseed53": ["piledriver", "pd_land"],
	"mseed39": ["hip_throw"], "mseed36": ["cheese_grater", "cheese_grater_r"], "mseed32": ["tackle", "tackle_slam", "tackle_wall"],
	"mseed33": ["suplex"], "mseed13": ["flip_jump", "dive", "dive_land"], "mseed50": ["tramp"],
	"mseed52": ["super_jump", "sj_grab", "sj_pin", "pin_punch"], "mseed58": ["superman", "sm_land"],
	"m_mvkqgf3gh3hrj": ["wave"], "m_mvkqkuvl0el5d": ["web", "web_throw"], "mseed49": ["tomoe"], "mseed45": ["disarm"], "mseed56": ["rain"],
}

# ---------------------------------------------------------------- état
var hero: CharacterBody3D
var ghost: CharacterBody3D
var foe: CharacterBody3D
var cam: Camera3D
var hit_ball: MeshInstance3D
var cards := []            # [[id carte, nom], ...] (même ordre que le labo, + « Autres »)
var card_i := 0
var move_id := ""
var keys := []             # [{t, pose (dict du héros ou "from"), curve}]
var timing := {"active": 0.1, "cancel": 0.2, "end": 0.4}
var version := ""          # version affichée ("" = fiche d'origine du jeu)
var dirty := false
var t := 0.0
var playing := false
var loop := true
var speed_i := 0
var onion := true
var sel_key := -1
var sel_joint := "spine"
var undo_stack := []
var redo_stack := []
var clipboard = null
var view_3d := false
var orbit := Vector2(-0.6, -0.25)    # lacet, tangage (vue 3D)
var dist := 4.5
var ortho_size := 3.6
var focus := Vector3(0.5, 1.05, 0)
var drag := {}             # membre attrapé : {joint, center (écran), a0, q0, bp} ; ou {pan} ; ou {orbit}
var guard_pose := {}
var status_t := 0.0

# ---------------------------------------------------------------- interface
var ui := CanvasLayer.new()
var overlay: Control
var card_opt := OptionButton.new()
var move_opt := OptionButton.new()
var info_lbl := Label.new()
var joint_btns := {}
var sliders := []          # 3 HSlider (X, Y, Z)
var slider_lbls := []
var hips_sliders := []
var hips_box := VBoxContainer.new()
var ver_list := ItemList.new()
var name_edit := LineEdit.new()
var choose_btn := Button.new()
var curve_opt := OptionButton.new()
var spin := {}             # active / cancel / end
var play_btn := Button.new()
var loop_btn := CheckButton.new()
var onion_btn := CheckButton.new()
var view_btn := Button.new()
var speed_opt := OptionButton.new()
var time_lbl := Label.new()
var status_lbl := Label.new()
var timeline: Timeline
var confirm := ConfirmationDialog.new()
var _pending := Callable()
var _slider_lock := false


func _ready() -> void:
	AnimStore.ensure()
	_build_world()
	_build_ui()
	for m in LaboCatalog.MOVES:
		if CARD_MOVES.has(m.id):
			cards.append([m.id, m.name])
	cards.append(["#autres", "Autres animations"])
	for c in cards:
		card_opt.add_item(c[1])
	select_card(0)


# ================================================================ monde 3D

func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = PlaneMesh.new()
	floor_mi.mesh.size = Vector2(20, 20)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.43, 0.46)
	floor_mi.material_override = fm
	add_child(floor_mi)
	for i in range(-10, 11):   # quadrillage (repères de distance, 1 m)
		for along in [true, false]:
			var l := MeshInstance3D.new()
			l.mesh = BoxMesh.new()
			l.mesh.size = Vector3(20, 0.004, 0.012) if along else Vector3(0.012, 0.004, 20)
			l.position = Vector3(0, 0.002, i) if along else Vector3(i, 0.002, 0)
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color(0.36, 0.37, 0.4)
			l.material_override = lm
			add_child(l)
	hero = _puppet(CONFIG.hero_color)
	hero.rotation.y = -PI / 2   # il regarde vers la droite de l'écran (+X)
	ghost = _puppet(CONFIG.ghost_color)
	ghost.rotation.y = -PI / 2
	ghost.mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foe = _puppet(CONFIG.foe_color)
	foe.rotation.y = PI / 2     # le sbire lui fait face
	hit_ball = MeshInstance3D.new()
	hit_ball.mesh = SphereMesh.new()
	var hm := StandardMaterial3D.new()
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(1, 0.3, 0.2, 0.25)
	hit_ball.material_override = hm
	add_child(hit_ball)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_place_camera()
	guard_pose = to_fk(hero._resolve(hero._pose("guard")))
	foe.apply_pose(foe._resolve(hero._pose("guard")))


## Un héros en cubes, figé (pas de physique, pas de commandes) : on lui donne des poses.
func _puppet(c: Color) -> CharacterBody3D:
	var p: CharacterBody3D = PLAYER.new()
	p.set_physics_process(false)
	add_child(p)
	p.set_physics_process(false)
	p.mat.albedo_color = c
	p.collision_layer = 0
	p.collision_mask = 0
	return p


func _place_camera() -> void:
	if view_3d:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 45
		var d := Vector3(cos(orbit.y) * sin(orbit.x), sin(-orbit.y), cos(orbit.y) * cos(orbit.x))
		cam.global_position = focus + d * dist
		cam.look_at(focus)
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = ortho_size
		cam.global_position = focus + Vector3(0, 0, 8)   # profil : on regarde le héros de côté
		cam.global_rotation = Vector3.ZERO


# ================================================================ choix du coup / versions

func select_card(i: int) -> void:
	card_i = clampi(i, 0, cards.size() - 1)
	card_opt.select(card_i)
	move_opt.clear()
	for id in _card_moves(cards[card_i][0]):
		var md: MoveData = MoveLibrary.moves().get(id)
		move_opt.add_item("%s  (%s)" % [md.display_name if md and md.display_name != "" else id, id])
		move_opt.set_item_metadata(move_opt.item_count - 1, id)
	if move_opt.item_count > 0:
		move_opt.select(0)
		load_move(move_opt.get_item_metadata(0))


## Les deux listes du haut montrent le coup ouvert (même s'il a été ouvert autrement).
func _sync_pickers(id: String) -> void:
	var cur = move_opt.get_item_metadata(move_opt.selected) if move_opt.selected >= 0 else ""
	if cur == id:
		return
	for c in cards.size():
		if id in _card_moves(cards[c][0]):
			card_i = c
			card_opt.select(c)
			move_opt.clear()
			for mid in _card_moves(cards[c][0]):
				var md: MoveData = MoveLibrary.moves().get(mid)
				move_opt.add_item("%s  (%s)" % [md.display_name if md and md.display_name != "" else mid, mid])
				move_opt.set_item_metadata(move_opt.item_count - 1, mid)
				if mid == id:
					move_opt.select(move_opt.item_count - 1)
			return


func _card_moves(card: String) -> Array:
	var ms := MoveLibrary.moves()
	if card == "#autres":
		var used := {}
		for c in CARD_MOVES:
			for id in CARD_MOVES[c]:
				used[id] = true
		var rest := []
		for id in ms:
			if not used.has(id) and (ms[id] as MoveData).keys.size() > 1:
				rest.append(id)
		rest.sort()
		return rest
	return CARD_MOVES.get(card, []).filter(func(id): return ms.has(id))


## Ouvre un coup : la version cochée s'il y en a une, sinon la fiche d'origine.
func load_move(id: String) -> void:
	move_id = id
	_sync_pickers(id)
	undo_stack.clear()
	redo_stack.clear()
	var ch := AnimStore.chosen(id)
	load_version(ch if ch != "" and not AnimStore.find_version(id, ch).is_empty() else "")


func load_version(vname: String) -> void:
	if vname != "" and AnimStore.find_version(move_id, vname).is_empty():
		vname = ""   # version introuvable (supprimée) : la fiche d'origine
	version = vname
	if vname == "":
		var md: MoveData = MoveLibrary.moves()[move_id]
		keys = []
		for k in md.keys:
			var pose = "from" if k[1] == "from" else to_fk(hero._resolve(hero.GUARD.merged(hero.POSE_DIFF[k[1]], true)))
			keys.append({"t": float(k[0]), "pose": pose, "curve": k[2] if k.size() > 2 else ""})
		timing = {"active": md.active, "cancel": md.cancel, "end": md.end}
	else:
		var v := AnimStore.find_version(move_id, vname)
		keys = []
		for k in v.keys:
			keys.append({"t": float(k.t), "pose": "from" if typeof(k.pose) != TYPE_DICTIONARY else AnimStore.pose_from_json(k.pose), "curve": k.get("curve", "")})
		timing = {"active": float(v.active), "cancel": float(v.cancel), "end": float(v.end)}
	# Les clés posées très loin (99 s = « jusqu'à la fin du geste ») sont ramenées juste après la dernière vraie clé.
	for k in keys:
		if k.t > 10.0:
			k.t = _last_real_t() + 0.3
	for k in ["active", "cancel", "end"]:
		if timing[k] > 10.0:
			timing[k] = 99.0
	dirty = false
	sel_key = mini(1, keys.size() - 1)
	t = keys[sel_key].t if sel_key >= 0 else 0.0
	_refresh_versions()
	_refresh_ui()
	var foe_d: float = hero.IDEAL.get(move_id, 1.0)
	foe.position = Vector3(foe_d + 0.15, 0, 0)


func _last_real_t() -> float:
	var m := 0.0
	for k in keys:
		if k.t < 10.0:
			m = maxf(m, k.t)
	return m


func _refresh_versions() -> void:
	ver_list.clear()
	var ch := AnimStore.chosen(move_id)
	ver_list.add_item(("✔ " if ch == "" else "    ") + "Fiche d'origine (le jeu)")
	ver_list.set_item_metadata(0, "")
	for v in AnimStore.versions(move_id):
		ver_list.add_item(("✔ " if ch == v.name else "    ") + v.name)
		ver_list.set_item_metadata(ver_list.item_count - 1, v.name)
	for i in ver_list.item_count:
		if ver_list.get_item_metadata(i) == version:
			ver_list.select(i)
	name_edit.text = version
	choose_btn.disabled = ch == version
	choose_btn.text = "C'est la bonne (utilisée par le jeu)" if ch != version else "✔ Utilisée par le jeu"


## Version courante -> format du fichier.
func to_version(vname: String) -> Dictionary:
	var ks := []
	for k in keys:
		ks.append({"t": snappedf(k.t, 0.0005), "pose": "from" if typeof(k.pose) != TYPE_DICTIONARY else AnimStore.pose_to_json(k.pose), "curve": k.curve})
	return {"name": vname, "saved_at": Time.get_datetime_string_from_system(), "author": OS.get_environment("USERNAME"),
		"active": timing.active, "cancel": timing.cancel, "end": timing.end, "keys": ks}


## Enregistre (remplace la version affichée ; depuis la fiche d'origine, il faut un nom).
func save(vname := "") -> bool:
	if vname == "":
		vname = version
	vname = vname.strip_edges()
	if vname == "":
		_status("Donne un nom à la version (champ « Nom ») avant d'enregistrer.")
		return false
	AnimStore.put_version(move_id, to_version(vname))
	if AnimStore.chosen(move_id) == "" and AnimStore.versions(move_id).size() == 1:
		AnimStore.choose(move_id, vname)   # première version d'un coup : c'est elle que le jeu prend
	var ok := AnimStore.save_file()
	AnimStore.apply(MoveLibrary.table())   # le jeu la voit tout de suite (labo, F2)
	version = vname
	dirty = false
	_refresh_versions()
	_status("Enregistré : « %s »%s" % [vname, " — c'est celle que le jeu utilise." if AnimStore.chosen(move_id) == vname else "."] if ok else "Erreur d'écriture.")
	return ok


func save_new(vname: String) -> bool:
	vname = vname.strip_edges()
	if vname == "":
		_status("Donne un nom à la nouvelle version.")
		return false
	var base := vname
	var n := 2
	while not AnimStore.find_version(move_id, vname).is_empty():
		vname = "%s %d" % [base, n]
		n += 1
	return save(vname)


func choose_current() -> void:
	if version != "" and dirty:
		save()
	AnimStore.choose(move_id, version)
	if not AnimStore.data.moves.has(move_id) and version == "":
		pass
	AnimStore.save_file()
	AnimStore.apply(MoveLibrary.table())
	_refresh_versions()
	_status("Le jeu utilise maintenant : %s" % ("la fiche d'origine" if version == "" else "« %s »" % version))


func rename_current(new_name: String) -> void:
	new_name = new_name.strip_edges()
	if version == "" or new_name == "" or new_name == version:
		return
	if not AnimStore.find_version(move_id, new_name).is_empty():
		_status("Ce nom existe déjà.")
		return
	var was_chosen := AnimStore.chosen(move_id) == version
	var v := to_version(new_name)
	AnimStore.delete_version(move_id, version)
	AnimStore.put_version(move_id, v)
	if was_chosen:
		AnimStore.choose(move_id, new_name)
	AnimStore.save_file()
	AnimStore.apply(MoveLibrary.table())
	version = new_name
	dirty = false
	_refresh_versions()


func delete_current() -> void:
	if version == "":
		return
	AnimStore.delete_version(move_id, version)
	AnimStore.save_file()
	AnimStore.apply(MoveLibrary.table())
	_status("Version « %s » supprimée." % version)
	load_version("")


func export_all() -> String:
	if dirty and version != "":
		save()
	var p := AnimStore.export_all()
	_status("Exporté : %s — dépose ce fichier sur le site (Atelier Rogue Doll, onglet Animations)." % p if p != "" else "Export impossible.")
	return p


# ================================================================ poses

func deg(q: Quaternion) -> Vector3:
	return q.get_euler() * (180.0 / PI)


## Pose résolue du héros (quaternions, pieds plantés éventuels) -> pose de l'éditeur (degrés, jambes en angles).
func to_fk(r: Dictionary) -> Dictionary:
	var out := {"hips_pos": r.hips_pos - Vector3(0, 0.9, 0), "foot_l": null, "foot_r": null}
	for n in JOINTS:
		out[n] = deg(r[n])
	for side in r.ik:
		var leg: Array = hero._ik(r, side)
		out["hip_" + side] = deg(leg[0])
		out["kn_" + side] = deg(leg[1])
	return out


func _key_pose(i: int) -> Dictionary:
	return guard_pose if typeof(keys[i].pose) != TYPE_DICTIONARY else keys[i].pose


## Pose à l'instant tt (mêmes courbes que le jeu, player.pose_at).
func pose_at(tt: float) -> Dictionary:
	if keys.is_empty():
		return hero._resolve(guard_pose)
	for i in range(keys.size() - 1):
		if tt <= keys[i + 1].t or i == keys.size() - 2:
			var u := clampf((tt - keys[i].t) / maxf(keys[i + 1].t - keys[i].t, 0.0001), 0.0, 1.0)
			match keys[i + 1].curve:
				"lin":
					pass
				"in":
					u = u * u * u
				"inout":
					u = u * u * (3.0 - 2.0 * u)
				"step":
					u = 0.0 if u < 1.0 else 1.0
				_:
					u = 1.0 - (1.0 - u) * (1.0 - u)
			return hero._mix(hero._resolve(_key_pose(i)), hero._resolve(_key_pose(i + 1)), u)
	return hero._resolve(_key_pose(0))


func key_at(tt: float) -> int:
	for i in keys.size():
		if absf(keys[i].t - tt) < 0.0015:
			return i
	return -1


## La clé à modifier à l'instant courant : la clé sous le curseur, sinon une nouvelle clé (pose du moment).
func _edit_key() -> int:
	var i := key_at(t)
	if i < 0:
		i = add_key(t)
	if i == 0 and typeof(keys[0].pose) != TYPE_DICTIONARY:
		_status("La première clé est « la pose d'avant le coup » (elle s'adapte au jeu) : ajoute une clé juste après pour changer le départ.")
		return -1
	sel_key = i
	return i


## Tourne une articulation de la clé courante (rotation monde autour de axis, en radians).
func rotate_joint(joint: String, axis: Vector3, angle: float, q0 = null, bp = null) -> void:
	var i := _edit_key()
	if i < 0:
		return
	var p: Dictionary = keys[i].pose
	if q0 == null:
		q0 = Quaternion.from_euler(p[joint] * (PI / 180.0))
	if bp == null:
		bp = _parent_basis(joint)
	var q: Quaternion = (bp.inverse() * Basis(axis.normalized(), angle) * bp * Basis(q0)).get_rotation_quaternion()
	p[joint] = deg(q)
	dirty = true
	_refresh_ui()


func set_joint(joint: String, v: Vector3) -> void:
	var i := _edit_key()
	if i < 0:
		return
	keys[i].pose[joint] = v
	dirty = true
	_refresh_ui()


func set_hips_pos(v: Vector3) -> void:
	var i := _edit_key()
	if i < 0:
		return
	keys[i].pose.hips_pos = v
	dirty = true
	_refresh_ui()


func _parent_basis(joint: String) -> Basis:
	hero.apply_pose(pose_at(t))
	var par: String = PARENT[joint]
	return (hero.global_basis if par == "" else hero.j[par].global_basis).orthonormalized()


func add_key(tt: float) -> int:
	push_undo()
	var pose := to_fk(pose_at(tt))
	var i := 0
	while i < keys.size() and keys[i].t < tt:
		i += 1
	keys.insert(i, {"t": tt, "pose": pose, "curve": ""})
	sel_key = i
	dirty = true
	_refresh_ui()
	return i


func delete_key(i: int) -> void:
	if i <= 0 or i >= keys.size() or keys.size() <= 2:
		_status("Il faut garder la première clé et au moins une autre.")
		return
	push_undo()
	keys.remove_at(i)
	sel_key = mini(i, keys.size() - 1)
	dirty = true
	_refresh_ui()


## Déplace une clé dans le temps (entre ses voisines) : c'est ce qui change le rythme.
func move_key(i: int, tt: float, snap := true) -> void:
	if i <= 0 or i >= keys.size():
		return
	if snap and CONFIG.snap_frames:
		tt = roundf(tt * FPS) / FPS
	var lo: float = keys[i - 1].t + 0.004
	var hi: float = keys[i + 1].t - 0.004 if i < keys.size() - 1 else 9.0
	keys[i].t = clampf(tt, lo, hi)
	t = keys[i].t
	dirty = true
	_refresh_ui()


func set_curve(i: int, c: String) -> void:
	if i <= 0 or i >= keys.size():
		return
	push_undo()
	keys[i].curve = c
	dirty = true
	_refresh_ui()


func copy_pose() -> void:
	clipboard = to_fk(pose_at(t))
	_status("Pose copiée.")


func paste_pose() -> void:
	if clipboard == null:
		return
	push_undo()
	var i := _edit_key()
	if i < 0:
		return
	keys[i].pose = clipboard.duplicate(true)
	dirty = true
	_refresh_ui()
	_status("Pose collée.")


## Miroir gauche-droite de la pose courante (les bras et les jambes s'échangent, les rotations sont reflétées).
func mirror_pose() -> void:
	push_undo()
	var i := _edit_key()
	if i < 0:
		return
	var p: Dictionary = keys[i].pose
	var out := p.duplicate(true)
	for n in JOINTS:
		var src: String = MIRROR.get(n, n)
		var v: Vector3 = p[src]
		out[n] = Vector3(v.x, -v.y, -v.z)
	out.hips_pos = Vector3(-p.hips_pos.x, p.hips_pos.y, p.hips_pos.z)
	keys[i].pose = out
	dirty = true
	_refresh_ui()


func set_timing(k: String, v: float) -> void:
	push_undo()
	timing[k] = v
	dirty = true
	_refresh_ui()


# ---------------------------------------------------------------- annuler / rétablir

func _snapshot() -> Dictionary:
	return {"keys": keys.duplicate(true), "timing": timing.duplicate()}


func push_undo() -> void:
	undo_stack.append(_snapshot())
	if undo_stack.size() > 200:
		undo_stack.pop_front()
	redo_stack.clear()


func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_snapshot())
	var s: Dictionary = undo_stack.pop_back()
	keys = s.keys
	timing = s.timing
	sel_key = mini(sel_key, keys.size() - 1)
	dirty = true
	_refresh_ui()


func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_snapshot())
	var s: Dictionary = redo_stack.pop_back()
	keys = s.keys
	timing = s.timing
	sel_key = mini(sel_key, keys.size() - 1)
	dirty = true
	_refresh_ui()


# ================================================================ boucle

func span() -> float:
	var e := _last_real_t()
	if timing.end < 10.0:
		e = maxf(e, timing.end)
	return maxf(e + 0.05, 0.3)


func _process(dt: float) -> void:
	if playing:
		t += dt * hero.attack_speed * CONFIG.speeds[speed_i]
		if t > span():
			if loop:
				t = 0.0
			else:
				t = span()
				playing = false
				play_btn.text = "▶ Lire"
	var r := pose_at(t)
	hero.apply_pose(r)
	var ka := key_at(t)
	if ka >= 0 and ka != sel_key:
		sel_key = ka
		_refresh_ui()
	# Pelure d'oignon : la clé d'avant, en transparence.
	var prev := -1
	for i in keys.size():
		if keys[i].t < t - 0.0015:
			prev = i
	ghost.visible = onion and prev >= 0
	if ghost.visible:
		ghost.apply_pose(hero._resolve(_key_pose(prev)))
	# Zone de frappe : autour du membre qui frappe, plus vive à l'impact.
	var md: MoveData = MoveLibrary.moves().get(move_id)
	hit_ball.visible = md != null and md.tip != "" and hero.j.has(md.tip)
	if hit_ball.visible:
		hit_ball.global_position = hero.j[md.tip].global_position
		hit_ball.scale = Vector3.ONE * maxf(md.radius, 0.1) * 2.0
		var near := absf(t - timing.active) < 0.025
		(hit_ball.material_override as StandardMaterial3D).albedo_color = Color(1, 0.25, 0.15, 0.5 if near else 0.08)
	time_lbl.text = "t = %.3f s   image %d   %s" % [t, int(roundf(t * FPS)), ("clé %d / %d" % [key_at(t), keys.size() - 1]) if key_at(t) >= 0 else "entre deux clés"]
	status_t -= dt
	if status_t <= 0.0 and status_lbl.text != "":
		status_lbl.modulate.a = maxf(status_lbl.modulate.a - dt, 0.35)
	if overlay:
		overlay.queue_redraw()
	if timeline:
		timeline.queue_redraw()


func _status(s: String) -> void:
	status_lbl.text = s
	status_lbl.modulate.a = 1.0
	status_t = 4.0


# ================================================================ souris et clavier

## Membre le plus proche de la souris (à l'écran), ou "".
func pick_joint(at: Vector2) -> String:
	var best := ""
	var bd: float = CONFIG.pick_radius
	for n in JOINTS:
		var c := cam.unproject_position(_joint_center(n))
		var d := c.distance_to(at)
		if d < bd:
			bd = d
			best = n
	return best


## Centre du cube d'un membre (là où on l'attrape).
func _joint_center(n: String) -> Vector3:
	var node: Node3D = hero.j[n]
	for c in node.get_children():
		if c is MeshInstance3D:
			return c.global_position
	return node.global_position


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			var n := pick_joint(ev.position)
			if n != "":
				select_joint(n)
				var i := _edit_key()
				if i < 0:
					return
				push_undo()
				var center := cam.unproject_position(hero.j[n].global_position)
				drag = {"joint": n, "center": center, "a0": (ev.position - center).angle(), "q0": Quaternion.from_euler(keys[i].pose[n] * (PI / 180.0)),
					"bp": _parent_basis(n), "shift": ev.shift_pressed and n == "hips", "m0": ev.position, "hp0": keys[i].pose.hips_pos}
				get_viewport().set_input_as_handled()
		elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			drag = {}
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			drag = {"orbit": ev.position} if ev.pressed else {}
		elif ev.button_index == MOUSE_BUTTON_MIDDLE:
			drag = {"pan": ev.position} if ev.pressed else {}
		elif ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and ev.pressed:
			var k := 0.9 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			ortho_size = clampf(ortho_size * k, 0.8, 8.0)
			dist = clampf(dist * k, 1.2, 15.0)
			_place_camera()
	elif ev is InputEventMouseMotion and not drag.is_empty():
		if drag.has("joint"):
			var n: String = drag.joint
			if drag.shift:   # Maj + bassin : on le déplace (position) au lieu de le tourner
				var w := _screen_to_world_delta(ev.position - drag.m0)
				set_hips_pos(drag.hp0 + hero.global_basis.inverse() * w)
			else:
				var a: float = (ev.position - drag.center).angle()
				rotate_joint(n, cam.global_basis.z, -(a - drag.a0), drag.q0, drag.bp)
		elif drag.has("orbit") and view_3d:
			orbit += ev.relative * Vector2(-0.008, 0.008)
			orbit.y = clampf(orbit.y, -1.4, 1.4)
			_place_camera()
		elif drag.has("pan") or (drag.has("orbit") and not view_3d):
			focus += _screen_to_world_delta(-ev.relative)
			_place_camera()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		_key_input(ev)


func _screen_to_world_delta(d: Vector2) -> Vector3:
	var scale_px := (cam.size if not view_3d else dist * 0.8) / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	return (cam.global_basis.x * d.x - cam.global_basis.y * d.y) * scale_px


func _key_input(ev: InputEventKey) -> void:
	get_viewport().set_input_as_handled()
	var ctrl := ev.ctrl_pressed or ev.meta_pressed
	match ev.physical_keycode:
		KEY_SPACE:
			toggle_play()
		KEY_LEFT:
			if ev.shift_pressed:
				_jump_key(-1)
			else:
				step(-1)
		KEY_RIGHT:
			if ev.shift_pressed:
				_jump_key(1)
			else:
				step(1)
		KEY_K, KEY_INSERT:
			add_key(t)
		KEY_DELETE, KEY_BACKSPACE:
			delete_key(sel_key)
		KEY_C:
			if ctrl:
				copy_pose()
		KEY_V:
			if ctrl:
				paste_pose()
			else:
				toggle_view()
		KEY_M:
			mirror_pose()
		KEY_Z:
			if ctrl and ev.shift_pressed:
				redo()
			elif ctrl:
				undo()
		KEY_Y:
			if ctrl:
				redo()
		KEY_S:
			if ctrl:
				if version == "":
					save_new(name_edit.text if name_edit.text != "" else "ma version")
				else:
					save()
		KEY_O:
			onion = not onion
			onion_btn.set_pressed_no_signal(onion)
		KEY_L:
			loop = not loop
			loop_btn.set_pressed_no_signal(loop)
		KEY_TAB:
			toggle_view()
		KEY_F2:
			_leave("res://labo.tscn")
		KEY_ESCAPE:
			_leave("res://hub.tscn")


func toggle_play() -> void:
	playing = not playing
	if playing and t >= span() - 0.001:
		t = 0.0
	play_btn.text = "⏸ Pause" if playing else "▶ Lire"


func step(n: int) -> void:
	playing = false
	play_btn.text = "▶ Lire"
	t = clampf(roundf(t * FPS + n) / FPS, 0.0, span())


func _jump_key(d: int) -> void:
	playing = false
	var target := -1
	if d > 0:
		for i in keys.size():
			if keys[i].t > t + 0.0015:
				target = i
				break
	else:
		for i in range(keys.size() - 1, -1, -1):
			if keys[i].t < t - 0.0015:
				target = i
				break
	if target >= 0:
		sel_key = target
		t = keys[target].t
		_refresh_ui()


func toggle_view() -> void:
	view_3d = not view_3d
	view_btn.text = "Vue : 3D libre" if view_3d else "Vue : profil"
	_place_camera()


func select_joint(n: String) -> void:
	sel_joint = n
	_refresh_ui()


## Quitter vers le labo (F2) ou le jeu : en demandant si des changements ne sont pas enregistrés.
func _leave(scene: String) -> void:
	_ask_discard(func(): get_tree().change_scene_to_file(scene))


func _ask_discard(then: Callable) -> void:
	if not dirty:
		then.call()
		return
	_pending = then
	confirm.dialog_text = "Des changements ne sont pas enregistrés. Les abandonner ?"
	confirm.popup_centered()


# ================================================================ interface (construite ici, pour pouvoir la changer facilement)

func _build_ui() -> void:
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	overlay = Overlay.new()
	overlay.ed = self
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)

	# --- barre du haut : coup, animation
	var top := _panel_row(col)
	top.add_child(_lbl("ÉDITEUR D'ANIMATION", 18, Color(1, 0.85, 0.4)))
	top.add_child(_lbl("   Coup :", 14))
	card_opt.custom_minimum_size.x = 240
	card_opt.item_selected.connect(func(i): _ask_discard(func(): select_card(i)))
	top.add_child(card_opt)
	top.add_child(_lbl("  Animation :", 14))
	move_opt.custom_minimum_size.x = 260
	move_opt.item_selected.connect(func(i): _ask_discard(func(): load_move(move_opt.get_item_metadata(i))))
	top.add_child(move_opt)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	top.add_child(_btn("Labo (F2)", func(): _leave("res://labo.tscn")))
	top.add_child(_btn("Salon (Échap)", func(): _leave("res://hub.tscn")))

	# --- milieu : membres à gauche, vue au centre, versions à droite
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)
	var left := _side_panel(mid, 250)
	left.add_child(_lbl("Membres", 16, Color(1, 0.85, 0.4)))
	left.add_child(_lbl("Clic sur un membre puis glisser = tourner.\nMaj + glisser le bassin = le déplacer.", 12, Color(0.75, 0.75, 0.8), true))
	var grid := GridContainer.new()
	grid.columns = 2
	left.add_child(grid)
	for n in JOINTS:
		var b := Button.new()
		b.text = JOINT_NAMES[n]
		b.toggle_mode = true
		b.pressed.connect(func(): select_joint(n))
		joint_btns[n] = b
		grid.add_child(b)
	left.add_child(_lbl("Réglage fin (degrés)", 13))
	for a in ["X (avant / arrière)", "Y (tourner)", "Z (côté)"]:
		var lb := _lbl(a, 12)
		lb.set_meta("base", a)
		left.add_child(lb)
		slider_lbls.append(lb)
		var s := HSlider.new()
		s.min_value = -180
		s.max_value = 180
		s.step = 0.5
		s.custom_minimum_size.x = 220
		s.drag_started.connect(push_undo)
		s.value_changed.connect(_on_slider)
		left.add_child(s)
		sliders.append(s)
	hips_box.add_child(_lbl("Position du bassin (m)", 13))
	for a in ["X (avant)", "Y (hauteur)", "Z (côté)"]:
		hips_box.add_child(_lbl(a, 12))
		var s := HSlider.new()
		s.min_value = -1.2
		s.max_value = 1.2
		s.step = 0.005
		s.drag_started.connect(push_undo)
		s.value_changed.connect(_on_hips_slider)
		hips_box.add_child(s)
		hips_sliders.append(s)
	left.add_child(hips_box)
	left.add_child(_lbl("Pose", 16, Color(1, 0.85, 0.4)))
	var prow := HBoxContainer.new()
	left.add_child(prow)
	prow.add_child(_btn("Copier", copy_pose))
	prow.add_child(_btn("Coller", paste_pose))
	prow.add_child(_btn("Miroir G/D", mirror_pose))
	var urow := HBoxContainer.new()
	left.add_child(urow)
	urow.add_child(_btn("↶ Annuler", undo))
	urow.add_child(_btn("↷ Rétablir", redo))

	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(center)

	var right := _side_panel(mid, 290)
	right.add_child(_lbl("Versions de ce coup", 16, Color(1, 0.85, 0.4)))
	right.add_child(_lbl("✔ = celle que le jeu utilise.", 12, Color(0.75, 0.75, 0.8)))
	ver_list.custom_minimum_size = Vector2(260, 170)
	ver_list.item_selected.connect(func(i): _ask_discard(func(): load_version(ver_list.get_item_metadata(i))))
	right.add_child(ver_list)
	right.add_child(_lbl("Nom", 12))
	name_edit.placeholder_text = "ex. rapide, courte…"
	right.add_child(name_edit)
	right.add_child(_btn("Enregistrer (Ctrl+S)", func(): save() if version != "" else save_new(name_edit.text)))
	right.add_child(_btn("Enregistrer comme nouvelle version", func(): save_new(name_edit.text if name_edit.text != version else name_edit.text + " bis")))
	var vrow := HBoxContainer.new()
	right.add_child(vrow)
	vrow.add_child(_btn("Renommer", func(): rename_current(name_edit.text)))
	vrow.add_child(_btn("Supprimer", delete_current))
	choose_btn.pressed.connect(choose_current)
	right.add_child(choose_btn)
	right.add_child(_lbl("Rythme du coup (s)", 16, Color(1, 0.85, 0.4)))
	for k in [["active", "Impact (le coup touche)"], ["cancel", "Annulable à partir de"], ["end", "Fin du coup"]]:
		var row := HBoxContainer.new()
		right.add_child(row)
		var l := _lbl(k[1], 12)
		l.custom_minimum_size.x = 160
		row.add_child(l)
		var sb := SpinBox.new()
		sb.min_value = 0.0
		sb.max_value = 99.0
		sb.step = 0.005
		sb.value_changed.connect(func(v): if not _slider_lock: set_timing(k[0], v))
		spin[k[0]] = sb
		row.add_child(sb)
	right.add_child(_lbl("99 = « jusqu'à ce que le jeu l'arrête » (réception, prise…).", 11, Color(0.7, 0.7, 0.75), true))
	right.add_child(_lbl("Partager", 16, Color(1, 0.85, 0.4)))
	right.add_child(_btn("Tout exporter (un fichier)", export_all))
	right.add_child(_btn("Ouvrir le dossier des exports", func(): OS.shell_open(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))))
	right.add_child(_lbl("Le fichier va sur ton Bureau : dépose-le sur le site, onglet « Animations ».", 11, Color(0.7, 0.7, 0.75), true))

	# --- bas : lecture, frise, aide
	var bottom := PanelContainer.new()
	col.add_child(bottom)
	var bcol := VBoxContainer.new()
	bottom.add_child(bcol)
	var tr := HBoxContainer.new()
	bcol.add_child(tr)
	tr.add_child(_btn("⏮", func(): t = 0.0))
	tr.add_child(_btn("◀ image", func(): step(-1)))
	play_btn.text = "▶ Lire"
	play_btn.pressed.connect(toggle_play)
	tr.add_child(play_btn)
	tr.add_child(_btn("image ▶", func(): step(1)))
	tr.add_child(_btn("◆ clé préc.", func(): _jump_key(-1)))
	tr.add_child(_btn("clé suiv. ◆", func(): _jump_key(1)))
	loop_btn.text = "Boucle"
	loop_btn.button_pressed = loop
	loop_btn.toggled.connect(func(on): loop = on)
	tr.add_child(loop_btn)
	for i in CONFIG.speeds.size():
		speed_opt.add_item("×%s" % str(CONFIG.speeds[i]))
	speed_opt.item_selected.connect(func(i): speed_i = i)
	tr.add_child(_lbl(" Vitesse", 12))
	tr.add_child(speed_opt)
	onion_btn.text = "Pelure d'oignon"
	onion_btn.button_pressed = onion
	onion_btn.toggled.connect(func(on): onion = on)
	tr.add_child(onion_btn)
	view_btn.text = "Vue : profil"
	view_btn.pressed.connect(toggle_view)
	tr.add_child(view_btn)
	tr.add_child(_lbl("   Clé :", 12))
	tr.add_child(_btn("+ Ajouter", func(): add_key(t)))
	tr.add_child(_btn("− Supprimer", func(): delete_key(sel_key)))
	tr.add_child(_lbl(" Courbe vers cette clé :", 12))
	for c in AnimStore.CURVES:
		curve_opt.add_item(c[1])
	curve_opt.item_selected.connect(func(i): set_curve(sel_key, AnimStore.CURVES[i][0]))
	tr.add_child(curve_opt)
	timeline = Timeline.new()
	timeline.ed = self
	timeline.custom_minimum_size.y = CONFIG.timeline_h
	bcol.add_child(timeline)
	var info := HBoxContainer.new()
	bcol.add_child(info)
	time_lbl.custom_minimum_size.x = 330
	info.add_child(time_lbl)
	status_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	info.add_child(status_lbl)
	bcol.add_child(_lbl("Espace lire · ←/→ image · Maj+←/→ clé · K ajouter une clé · Suppr supprimer · double-clic sur la frise = clé · glisser une clé = rythme (Ctrl : sans aimant) · Ctrl+C/V pose · M miroir · Ctrl+Z/Y · O oignon · Tab vue 3D (clic droit tourner, molette zoom, clic milieu déplacer) · F2 labo",
		11, Color(0.7, 0.7, 0.75), true))
	for c in [card_opt, move_opt, speed_opt, curve_opt, loop_btn, onion_btn, view_btn, play_btn, choose_btn, ver_list]:
		c.focus_mode = Control.FOCUS_NONE   # la barre d'espace reste à la lecture
	for n in joint_btns:
		joint_btns[n].focus_mode = Control.FOCUS_NONE
	add_child(confirm)
	confirm.confirmed.connect(func():
		dirty = false
		if _pending.is_valid():
			_pending.call())


func _panel_row(parent: Control) -> HBoxContainer:
	var pc := PanelContainer.new()
	parent.add_child(pc)
	var h := HBoxContainer.new()
	pc.add_child(h)
	return h


func _side_panel(parent: Control, w: int) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = w
	parent.add_child(pc)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func _lbl(text: String, size: int, c := Color(0.92, 0.92, 0.95), wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 200
	return l


func _btn(text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(f)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _on_slider(_v: float) -> void:
	if _slider_lock:
		return
	set_joint(sel_joint, Vector3(sliders[0].value, sliders[1].value, sliders[2].value))


func _on_hips_slider(_v: float) -> void:
	if _slider_lock:
		return
	set_hips_pos(Vector3(-hips_sliders[2].value, hips_sliders[1].value, -hips_sliders[0].value))


## Remet l'interface à jour depuis l'état (sans déclencher les curseurs).
func _refresh_ui() -> void:
	_slider_lock = true
	for n in joint_btns:
		joint_btns[n].button_pressed = n == sel_joint
	var i := key_at(t)
	var p: Dictionary = _key_pose(i) if i >= 0 else to_fk(pose_at(t))
	var v: Vector3 = p[sel_joint]
	for k in 3:
		sliders[k].value = wrapf(v[k], -180.0, 180.0)
		slider_lbls[k].text = "%s : %.1f°" % [slider_lbls[k].get_meta("base"), wrapf(v[k], -180.0, 180.0)]
	var hp: Vector3 = p.hips_pos
	hips_sliders[0].value = -hp.z
	hips_sliders[1].value = hp.y
	hips_sliders[2].value = -hp.x
	hips_box.visible = sel_joint == "hips"
	for k in spin:
		spin[k].value = timing[k]
	if sel_key > 0 and sel_key < keys.size():
		for c in AnimStore.CURVES.size():
			if AnimStore.CURVES[c][0] == keys[sel_key].curve:
				curve_opt.select(c)
	curve_opt.disabled = sel_key <= 0
	_slider_lock = false


# ================================================================ frise des clés

class Timeline extends Control:
	var ed
	var dragging := -1      # clé en train d'être déplacée
	var scrubbing := false
	const M := 14.0

	func _x(tt: float) -> float:
		return M + (size.x - 2 * M) * tt / ed.span()

	func _t(x: float) -> float:
		return clampf((x - M) / (size.x - 2 * M) * ed.span(), 0.0, ed.span())

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12))
		var sp: float = ed.span()
		var y0 := 22.0
		# images (1/60 s) et dixièmes de seconde
		var n := int(sp * ed.FPS)
		for f in n + 1:
			var x := _x(f / ed.FPS)
			var tall := f % 6 == 0
			draw_line(Vector2(x, y0), Vector2(x, y0 + (10.0 if tall else 4.0)), Color(0.5, 0.5, 0.55) if tall else Color(0.3, 0.3, 0.33))
			if tall:
				draw_string(ThemeDB.fallback_font, Vector2(x + 2, y0 - 6), "%.1f" % (f / ed.FPS), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.6, 0.65))
		# rythme : impact, annulation, fin
		for m in [["active", Color(1, 0.3, 0.2), "impact"], ["cancel", Color(1, 0.65, 0.2), "annulable"], ["end", Color(0.6, 0.6, 0.7), "fin"]]:
			var v: float = ed.timing[m[0]]
			if v <= sp:
				var x := _x(v)
				draw_line(Vector2(x, y0), Vector2(x, size.y - 4), m[1], 2.0)
				draw_string(ThemeDB.fallback_font, Vector2(x + 3, size.y - 8), m[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, m[1])
		# clés
		var ky := y0 + 34.0
		for i in ed.keys.size():
			var x := _x(ed.keys[i].t)
			var c := Color(0.55, 0.7, 1.0)
			if typeof(ed.keys[i].pose) != TYPE_DICTIONARY:
				c = Color(0.5, 0.5, 0.55)
			if i == ed.sel_key:
				c = ed.CONFIG.sel_color
			var pts := PackedVector2Array([Vector2(x, ky - 9), Vector2(x + 9, ky), Vector2(x, ky + 9), Vector2(x - 9, ky)])
			draw_colored_polygon(pts, c)
			if i > 0 and ed.keys[i].curve != "":
				draw_string(ThemeDB.fallback_font, Vector2(x - 12, ky + 22), ed.keys[i].curve, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.7, 0.75))
		# curseur
		var cx := _x(ed.t)
		draw_line(Vector2(cx, 4), Vector2(cx, size.y), Color.WHITE, 2.0)

	func _key_under(x: float) -> int:
		for i in ed.keys.size():
			if absf(_x(ed.keys[i].t) - x) < 10.0:
				return i
		return -1

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				var i := _key_under(ev.position.x)
				if ev.double_click and i < 0:
					ed.add_key(_t(ev.position.x))
				elif i >= 0:
					ed.sel_key = i
					ed.t = ed.keys[i].t
					ed.playing = false
					if i > 0:
						ed.push_undo()
						dragging = i
					ed._refresh_ui()
				else:
					scrubbing = true
					ed.playing = false
					ed.t = _t(ev.position.x)
					ed._refresh_ui()
			else:
				dragging = -1
				scrubbing = false
			accept_event()
		elif ev is InputEventMouseMotion:
			if dragging > 0:
				ed.move_key(dragging, _t(ev.position.x), not ev.ctrl_pressed)
			elif scrubbing:
				ed.t = _t(ev.position.x)
				ed._refresh_ui()
			accept_event()


# ================================================================ anneau de rotation (dessiné par-dessus la vue)

class Overlay extends Control:
	var ed

	func _draw() -> void:
		if ed == null or ed.hero == null or not ed.hero.j.has(ed.sel_joint):
			return
		var c: Vector2 = ed.cam.unproject_position(ed.hero.j[ed.sel_joint].global_position)
		var r: float = ed.CONFIG.ring_radius
		draw_arc(c, r, 0, TAU, 48, ed.CONFIG.sel_color, 2.0)
		draw_circle(c, 4.0, ed.CONFIG.sel_color)
		var tip: Vector2 = ed.cam.unproject_position(ed._joint_center(ed.sel_joint))
		draw_line(c, c + (tip - c).normalized() * r, ed.CONFIG.sel_color, 2.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(r + 6, -r * 0.6), ed.JOINT_NAMES[ed.sel_joint], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ed.CONFIG.sel_color)
		if ed.drag.has("joint"):
			draw_line(ed.drag.center, get_local_mouse_position(), Color(1, 1, 1, 0.5), 1.0)

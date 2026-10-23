class_name Hub
extends Node3D
## Le salon (v0.211) : la scène lancée au démarrage. On s'y déplace avec le héros et on choisit ce qu'on lance en
## s'approchant d'un objet puis RB (R1, L au clavier) :
##   punching-ball -> le labo des coups       établi -> la salle des paliers (Vanilla, Palier 1, 2, 3)
##   ordinateur    -> l'éditeur d'animation   porte  -> la run classique (Monde 1)
## Le labo, l'éditeur et la run reviennent ici (Échap / F2 / bouton « Salon »).

const MAIN := preload("res://main.tscn")
const REACH := 1.9          # m : distance à laquelle un objet propose son action
const START := Vector3(0, 0, 1.0)

var main: Node3D
var player: CharacterBody3D
var ui := CanvasLayer.new()
var prompt := Label.new()
var tiers_box := PanelContainer.new()
var tiers_btns: Array[Button] = []
var near := -1              # station la plus proche à portée (-1 : aucune)
var menu_open := false
var bag: Node3D             # le sac du punching-ball (il se balance quand on passe près)
var bag_swing := 0.0
var bag_v := 0.0
var dry := false            # tests : on note la scène demandée sans y aller
var went := ""

## Stations : nom affiché, action, position du point d'accès (devant l'objet).
var stations := [
	{"name": "Labo des coups", "what": "punching-ball", "act": "labo", "at": Vector3(-2.6, 0, -0.6)},
	{"name": "Salle des paliers", "what": "établi", "act": "tiers", "at": Vector3(0.9, 0, -2.4)},
	{"name": "Éditeur d'animation", "what": "ordinateur", "act": "editor", "at": Vector3(3.4, 0, 0.2)},
	{"name": "Run classique", "what": "porte", "act": "run", "at": Vector3(-1.6, 0, -2.6)},
]
var labels := []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = MAIN.instantiate()
	main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(main)
	player = main.player
	for c in main.get_children():
		if c.get_script() == preload("res://menu_ctl.gd"):
			c.process_mode = Node.PROCESS_MODE_DISABLED   # pas de menu pause dans le salon
	# Le sbire de la scène de jeu n'a rien à faire ici : rangé loin et figé.
	for e in main.enemies:
		e.ai_on = false
		e.visible = false
		e.global_position = Vector3(300, 0, 300)
		e.build()
		e.process_mode = Node.PROCESS_MODE_DISABLED
	for b in [main.hp_bar, main.player_bar, main.special_bar]:
		b.visible = false
	main.hint.text = "Stick : se déplacer   ·   approche-toi d'un objet puis RB (L au clavier)   ·   F2 : labo   ·   F3 : éditeur d'animation"
	player.global_position = START
	player.rotation.y = 0.0
	main.cam_base = player.global_position + main.CAM_OFFSET * main.cam_zoom
	_build_room()
	_build_ui()


# ---------------------------------------------------------------- décor

func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


## Un bloc (collision facultative), posé par son centre.
func _box(size: Vector3, at: Vector3, c: Color, solid := true, parent: Node3D = null, emit := 0.0) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = size
	mi.material_override = _mat(c, emit)
	var node: Node3D = mi
	if solid:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		cs.shape.size = size
		sb.add_child(cs)
		sb.add_child(mi)
		node = sb
	(parent if parent else main).add_child(node)
	node.position = at
	return node


func _cyl(r: float, h: float, at: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = r
	mi.mesh.bottom_radius = r
	mi.mesh.height = h
	mi.material_override = _mat(c)
	(parent if parent else main).add_child(mi)
	mi.position = at
	return mi


func _build_room() -> void:
	var wall := Color(0.36, 0.33, 0.42)
	var wood := Color(0.55, 0.36, 0.22)
	var dark := Color(0.16, 0.16, 0.2)
	# Sol (tapis) et murs : les deux murs du fond sont hauts, ceux de devant (côté caméra) ne sont que des plinthes.
	_box(Vector3(10.0, 0.02, 7.6), Vector3(0.4, 0.01, -0.2), Color(0.42, 0.24, 0.24), false)
	_box(Vector3(9.0, 0.025, 6.6), Vector3(0.4, 0.015, -0.2), Color(0.5, 0.3, 0.27), false)
	_box(Vector3(10.4, 3.0, 0.3), Vector3(0.4, 1.5, -4.15), wall)          # fond
	_box(Vector3(0.3, 3.0, 8.0), Vector3(5.45, 1.5, -0.2), wall)           # droite
	_box(Vector3(10.4, 0.25, 0.3), Vector3(0.4, 0.125, 3.75), wall)        # devant (plinthe)
	_box(Vector3(0.3, 0.25, 8.0), Vector3(-4.65, 0.125, -0.2), wall)       # gauche (plinthe)
	# Une lampe au plafond (lumière chaude).
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.65)
	lamp.light_energy = 1.4
	lamp.omni_range = 9.0
	main.add_child(lamp)
	lamp.position = Vector3(0.3, 3.2, -0.6)

	# Punching-ball : pied, potence, sac rouge suspendu.
	var pb := Vector3(-3.0, 0, -1.6)
	_box(Vector3(0.8, 0.08, 0.8), pb + Vector3(0, 0.04, 0), dark)
	_box(Vector3(0.12, 2.5, 0.12), pb + Vector3(0, 1.25, 0), dark)
	_box(Vector3(0.12, 0.12, 0.9), pb + Vector3(0, 2.44, 0.4), dark, false)
	bag = Node3D.new()
	main.add_child(bag)
	bag.position = pb + Vector3(0, 2.4, 0.8)
	_box(Vector3(0.03, 0.4, 0.03), Vector3(0, -0.2, 0), Color(0.7, 0.7, 0.7), false, bag)
	_cyl(0.3, 1.1, Vector3(0, -0.95, 0), Color(0.75, 0.12, 0.12), bag)
	_cyl(0.31, 0.08, Vector3(0, -0.55, 0), dark, bag)
	_cyl(0.31, 0.08, Vector3(0, -1.35, 0), dark, bag)

	# Établi : plateau, pieds, étau, outils, panneau à outils au mur.
	var wb := Vector3(1.0, 0, -3.5)
	_box(Vector3(2.2, 0.1, 0.9), wb + Vector3(0, 0.9, 0), wood)
	for x in [-1.0, 1.0]:
		for z in [-0.35, 0.35]:
			_box(Vector3(0.1, 0.85, 0.1), wb + Vector3(x, 0.425, z), wood.darkened(0.3))
	_box(Vector3(2.0, 0.06, 0.7), wb + Vector3(0, 0.25, 0), wood.darkened(0.2), false)
	_box(Vector3(0.25, 0.2, 0.25), wb + Vector3(-0.75, 1.05, 0.2), Color(0.3, 0.45, 0.6), false)   # étau
	_box(Vector3(0.5, 0.05, 0.08), wb + Vector3(0.1, 0.98, 0.15), Color(0.6, 0.6, 0.62), false)     # marteau (manche)
	_box(Vector3(0.1, 0.1, 0.18), wb + Vector3(0.35, 1.0, 0.15), dark, false)                     # marteau (tête)
	_box(Vector3(0.35, 0.18, 0.25), wb + Vector3(0.7, 1.04, -0.1), Color(0.85, 0.6, 0.15), false)  # boîte à outils
	_box(Vector3(2.0, 1.1, 0.05), wb + Vector3(0, 1.85, -0.38), Color(0.62, 0.52, 0.38), false)     # panneau
	for k in 5:
		_box(Vector3(0.06, 0.4, 0.04), wb + Vector3(-0.8 + k * 0.4, 1.9, -0.33), Color(0.4, 0.4, 0.45), false)

	# Ordinateur : bureau contre le mur de droite, écran allumé, clavier, chaise.
	var pc := Vector3(4.6, 0, 0.2)
	_box(Vector3(1.0, 0.08, 1.8), pc + Vector3(0, 0.76, 0), Color(0.85, 0.85, 0.82))
	for z in [-0.8, 0.8]:
		_box(Vector3(0.9, 0.72, 0.06), pc + Vector3(0, 0.36, z), Color(0.75, 0.75, 0.72))
	_box(Vector3(0.08, 0.55, 0.95), pc + Vector3(0.25, 1.15, 0), dark, false)                     # écran
	_box(Vector3(0.02, 0.47, 0.86), pc + Vector3(0.2, 1.15, 0), Color(0.35, 0.7, 1.0), false, null, 1.6)
	_box(Vector3(0.06, 0.25, 0.06), pc + Vector3(0.3, 0.92, 0), dark, false)
	_box(Vector3(0.22, 0.03, 0.6), pc + Vector3(-0.2, 0.81, 0), dark, false)                      # clavier
	_box(Vector3(0.12, 0.03, 0.08), pc + Vector3(-0.2, 0.81, 0.45), dark, false)                  # souris
	_box(Vector3(0.5, 0.08, 0.5), pc + Vector3(-1.0, 0.5, 0), Color(0.2, 0.25, 0.35), false)       # chaise
	_box(Vector3(0.08, 0.6, 0.5), pc + Vector3(-1.25, 0.8, 0), Color(0.2, 0.25, 0.35), false)
	_box(Vector3(0.06, 0.46, 0.06), pc + Vector3(-1.0, 0.23, 0), dark, false)

	# Porte : dans le mur du fond, cadre, battant entrouvert, lumière derrière.
	var dr := Vector3(-1.6, 0, -3.98)
	_box(Vector3(1.3, 2.4, 0.06), dr + Vector3(0, 1.2, -0.02), Color(1.0, 0.92, 0.7), false, null, 2.5)   # lumière dehors
	_box(Vector3(0.12, 2.5, 0.2), dr + Vector3(-0.7, 1.25, 0.05), wood.darkened(0.35), false)
	_box(Vector3(0.12, 2.5, 0.2), dr + Vector3(0.7, 1.25, 0.05), wood.darkened(0.35), false)
	_box(Vector3(1.52, 0.12, 0.2), dr + Vector3(0, 2.5, 0.05), wood.darkened(0.35), false)
	var leaf := Node3D.new()
	main.add_child(leaf)
	leaf.position = dr + Vector3(-0.62, 0, 0.1)
	leaf.rotation.y = deg_to_rad(-35)
	_box(Vector3(1.22, 2.36, 0.06), Vector3(0.61, 1.18, 0), wood, false, leaf)
	_box(Vector3(0.08, 0.08, 0.1), Vector3(1.08, 1.05, 0.06), Color(0.85, 0.75, 0.3), false, leaf)

	# Étiquettes au-dessus des objets.
	var tops := [pb + Vector3(0, 2.95, 0.6), wb + Vector3(0, 2.7, 0), pc + Vector3(0, 1.85, 0), dr + Vector3(0, 2.95, 0.3)]
	for i in stations.size():
		var l := Label3D.new()
		l.text = stations[i].name
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 44
		l.outline_size = 10
		l.pixel_size = 0.0009
		l.fixed_size = true
		l.no_depth_test = true
		main.add_child(l)
		l.position = tops[i]
		labels.append(l)


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	ui.layer = 5
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var title := Label.new()
	title.text = "ROGUE DOLL  ·  v%s" % GameVersion.NUM
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.55, 0.72, 1.0))
	ui.add_child(title)
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 8)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.0
	prompt.anchor_right = 1.0
	prompt.anchor_top = 0.72
	prompt.anchor_bottom = 0.72
	ui.add_child(prompt)
	# Menu de l'établi : choix du palier.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.09, 0.15, 0.94)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	tiers_box.add_theme_stylebox_override("panel", bg)
	tiers_box.anchor_left = 0.5
	tiers_box.anchor_right = 0.5
	tiers_box.anchor_top = 0.5
	tiers_box.anchor_bottom = 0.5
	tiers_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tiers_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	tiers_box.custom_minimum_size = Vector2(460, 0)
	tiers_box.visible = false
	ui.add_child(tiers_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	tiers_box.add_child(col)
	var h := Label.new()
	h.text = "SALLE DES PALIERS"
	h.add_theme_font_size_override("font_size", 22)
	h.add_theme_color_override("font_color", Color(0.55, 0.72, 1.0))
	col.add_child(h)
	var sub := Label.new()
	sub.text = "Choisis un build, contre trois sbires qui attaquent. B / Échap : fermer."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.modulate = Color(1, 1, 1, 0.7)
	col.add_child(sub)
	for i in BuildTiers.TIERS.size():
		var b := Button.new()
		b.text = BuildTiers.TIERS[i].name + "  —  " + BuildTiers.TIERS[i].desc
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(open_tier.bind(i))
		col.add_child(b)
		tiers_btns.append(b)


func open_tiers_menu(on: bool) -> void:
	menu_open = on
	tiers_box.visible = on
	prompt.visible = not on
	get_tree().paused = on
	if on:
		tiers_btns[0].grab_focus()
	else:
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
	for a in ["light", "heavy", "grab", "jump", "roll", "guard"]:
		Input.action_release(a)   # l'appui qui a ouvert / fermé le menu ne part pas en coup


# ---------------------------------------------------------------- actions

func use(i: int) -> void:
	match stations[i].act:
		"labo":
			_go("res://labo.tscn")
		"tiers":
			open_tiers_menu(true)
		"editor":
			_go("res://anim_editor.tscn")
		"run":
			_go("res://main.tscn")


## Salle des paliers : le labo s'ouvre directement sur la salle des builds du palier choisi, menu fermé.
func open_tier(i: int) -> void:
	LaboCatalog.start_id = BuildTiers.TIERS[i].get("lab", "build_" + BuildTiers.TIERS[i].id)
	_go("res://labo.tscn")


func _go(scene: String) -> void:
	went = scene
	if dry:
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(scene)


func _physics_process(dt: float) -> void:
	if menu_open:
		return
	player.grab_cd = 1.0   # RB sert à utiliser les objets : pas de chope dans le salon
	player.hp = 100.0
	# Station la plus proche à portée.
	near = -1
	var best := REACH
	for i in stations.size():
		var d: float = ((stations[i].at - player.global_position) * Vector3(1, 0, 1)).length()
		if d < best:
			best = d
			near = i
	for i in labels.size():
		labels[i].modulate = Color(1, 0.85, 0.3) if i == near else Color(1, 1, 1, 0.85)
		labels[i].font_size = 54 if i == near else 44
	prompt.text = ("RB : %s" % stations[near].name) if near >= 0 else ""
	if near >= 0 and Input.is_action_just_pressed("grab"):
		use(near)
	# Le sac se balance quand le héros le frôle ou le frappe.
	var to_bag: Vector3 = (bag.global_position - player.global_position) * Vector3(1, 0, 1)
	if to_bag.length() < 1.6 and player.attack != "" and player.connected == false and player.t > 0.05 and player.t < 0.2:
		bag_v += 1.2 * dt * 60.0 * 0.05
	bag_v += -bag_swing * 18.0 * dt - bag_v * 1.5 * dt
	bag_swing += bag_v * dt
	bag.rotation.x = clampf(bag_swing, -0.5, 0.5)


func _unhandled_input(ev: InputEvent) -> void:
	if menu_open and (ev.is_action_pressed("ui_cancel") or (ev is InputEventKey and ev.pressed and ev.physical_keycode == KEY_ESCAPE)):
		open_tiers_menu(false)
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and not menu_open:
		match ev.physical_keycode:
			KEY_F2:
				_go("res://labo.tscn")
			KEY_F3:
				_go("res://anim_editor.tscn")

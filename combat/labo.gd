extends Node3D
## Labo des coups : on choisit un coup dans le menu, « Tester ce coup » te met dans la situation exacte (sbire couché,
## en garde, en l'air, déjà chopé, mur, objet...), avec la commande et ce que fait le coup. Tout se joue à la manette.
##
## Start (ou Tab) ouvre / ferme le menu du labo : menu ouvert = le jeu est en pause et la manette pilote le menu ;
## menu fermé = la manette pilote le héros (une petite fiche du coup reste affichée en haut à droite).
## Menu fermé : croix ▲ ou Select (R au clavier) = remettre la situation. F2 = retour au jeu.
## Les sbires ne meurent pas (leur vie est rendue) et restent dans leur état (couché, en garde, en l'air).

const MAIN := preload("res://main.tscn")
const SPEEDS := [1.0, 0.5, 0.25]
const KEEP := 0.7          # s debout avant de remettre un sbire couché / en l'air

var main: Node3D
var player: CharacterBody3D
var map: TestMap            # le « Terrain d'essai » (v0.212)
var cur := 0               # index dans LaboCatalog.MOVES
var variant := {}          # id -> valeur choisie
var modes := {}            # sbire -> "stand" / "guard" / "down" / "air" / "attack"
var stand_t := {}
var spawned: Array[Node] = []
var auto_reset := true
var idle_t := 0.0
var tried := false         # un coup a été lancé depuis la mise en situation
var speed_i := 0

var ui := CanvasLayer.new()
var pick := OptionButton.new()
var var_box := HBoxContainer.new()
var var_opt := OptionButton.new()
var name_lbl := Label.new()
var status_lbl := Label.new()
var button_lbl := Label.new()
var cmd_lbl := Label.new()
var what_lbl := Label.new()
var note_lbl := Label.new()
var scene_lbl := Label.new()
var speed_btns: Array[Button] = []
var id_lbl := Label.new()
var panel := PanelContainer.new()
var pick_first: Control
var mini := PanelContainer.new()
var mini_lbl := Label.new()
var menu_open := false
var lock_slider := HSlider.new()
var extra := 0              # sbires en plus dans chaque situation (5 au total au maximum)
var extra_mode := "stand"
var extra_slider := HSlider.new()
var extra_lbl := Label.new()
var extra_opt := OptionButton.new()
const EXTRA_MODES := [["stand", "Immobiles"], ["guard", "En garde"], ["attack", "Qui attaquent"]]
const MAX_ENEMIES := 5
var lock_lbl := Label.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = MAIN.instantiate()
	main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(main)
	player = main.player
	map = TestMap.new()
	main.add_child(map)
	main.hint.visible = false
	for c in main.get_children():
		if c.get_script() == preload("res://menu_ctl.gd"):
			c.process_mode = Node.PROCESS_MODE_DISABLED   # Start ouvre le menu du labo, pas le menu pause du jeu
	_build_ui()
	select(0)
	set_menu(true)
	if LaboCatalog.start_id != "":   # ouvert depuis l'établi du salon : directement dans la salle du palier choisi
		for i in LaboCatalog.MOVES.size():
			if LaboCatalog.MOVES[i].id == LaboCatalog.start_id:
				select(i)
				set_menu(false)
		LaboCatalog.start_id = ""


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	ui.layer = 5
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -430
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = -12
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.09, 0.15, 0.9)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", bg)
	var th := Theme.new()
	th.default_font_size = 14
	panel.theme = th
	ui.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true   # à la manette, le menu défile vers ce qui est sélectionné
	panel.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	sc.add_child(col)

	col.add_child(_lbl("LABO DES COUPS", 20, Color(0.55, 0.72, 1.0)))
	col.add_child(_lbl("Choisis un coup, puis « Tester ce coup ». Start : fermer le menu et jouer (le jeu est en pause tant qu'il est ouvert). Menu fermé : croix ▲ ou Select remet la situation.", 12, Color(1, 1, 1, 0.7), true))
	# Coups rangés et colorés par bouton (v0.216, idée de Thibaud) : X bleu, Y jaune, B rouge, A vert, puis les autres.
	for i in _sorted_moves():
		var m: Dictionary = LaboCatalog.MOVES[i]
		pick.add_item("[%s]  %s%s" % [m.button, m.name, "   • nouveau" if m.status == "tester" else ""], i)
		var col_b := btn_color(m.button)
		if col_b.a > 0.0:
			pick.set_item_icon(pick.item_count - 1, _dot(col_b))
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.item_selected.connect(func(k): select(pick.get_item_id(k)))
	col.add_child(pick)
	var_box.add_child(_lbl("Variante", 13, Color(1, 1, 1, 0.75)))
	var_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var_opt.item_selected.connect(_on_variant)
	var_box.add_child(var_opt)
	col.add_child(var_box)
	var test := Button.new()
	test.text = "Tester ce coup"
	test.add_theme_font_size_override("font_size", 16)
	test.pressed.connect(func():
		setup()
		set_menu(false))
	col.add_child(test)

	col.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name_lbl)
	status_lbl.add_theme_font_size_override("font_size", 12)
	head.add_child(status_lbl)
	col.add_child(head)
	button_lbl.add_theme_font_size_override("font_size", 30)
	button_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	col.add_child(button_lbl)
	col.add_child(_lbl("COMMANDE", 11, Color(0.55, 0.72, 1.0)))
	cmd_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cmd_lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(cmd_lbl)
	col.add_child(_lbl("CE QUE ÇA FAIT", 11, Color(0.55, 0.72, 1.0)))
	what_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(what_lbl)
	col.add_child(_lbl("LA SITUATION", 11, Color(0.55, 0.72, 1.0)))
	scene_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_lbl.modulate = Color(1, 1, 1, 0.85)
	col.add_child(scene_lbl)
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_lbl.add_theme_font_size_override("font_size", 12)
	note_lbl.add_theme_color_override("font_color", Color(1, 0.75, 0.4))
	col.add_child(note_lbl)

	col.add_child(HSeparator.new())
	var r := HBoxContainer.new()
	r.add_child(_lbl("Vitesse", 13, Color(1, 1, 1, 0.75)))
	for i in SPEEDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = "×%s" % str(SPEEDS[i])
		b.pressed.connect(func(): set_speed(i))
		speed_btns.append(b)
		r.add_child(b)
	col.add_child(r)
	var lr := HBoxContainer.new()
	lr.add_child(_lbl("Aimantation", 13, Color(1, 1, 1, 0.75)))
	lock_slider.min_value = 0.0
	lock_slider.max_value = 1.0
	lock_slider.step = 0.05
	lock_slider.value = player.lock_power
	lock_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_slider.value_changed.connect(set_lock)
	lr.add_child(lock_slider)
	lock_lbl.custom_minimum_size.x = 92
	lr.add_child(lock_lbl)
	col.add_child(lr)
	col.add_child(_lbl("0 = désactivée (comme dans le jeu) · 1 = très forte : il se tourne vers le sbire, fonce dessus et reste collé en l'air.", 11, Color(1, 1, 1, 0.55), true))
	set_lock(player.lock_power)
	var zr := HBoxContainer.new()
	zr.add_child(_lbl("Zoom caméra", 13, Color(1, 1, 1, 0.75)))
	var zs := HSlider.new()
	zs.min_value = main.ZOOM_PREF_MIN
	zs.max_value = main.ZOOM_PREF_MAX
	zs.step = 0.05
	zs.value = main.zoom_pref
	zs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var zlbl := _lbl("%.2f" % main.zoom_pref, 13, Color(1, 1, 1, 0.75))
	zlbl.custom_minimum_size.x = 92
	zs.value_changed.connect(func(v): main.zoom_pref = v; zlbl.text = "%.2f" % v)
	zr.add_child(zs)
	zr.add_child(zlbl)
	col.add_child(zr)
	col.add_child(_lbl("Petit = caméra plus près. Gardé pour le jeu et le menu pause.", 11, Color(1, 1, 1, 0.55), true))
	var er := HBoxContainer.new()
	er.add_child(_lbl("Sbires en plus", 13, Color(1, 1, 1, 0.75)))
	extra_slider.min_value = 0
	extra_slider.max_value = MAX_ENEMIES - 1
	extra_slider.step = 1
	extra_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extra_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	extra_slider.value_changed.connect(func(v): set_extra(int(v), extra_mode))
	er.add_child(extra_slider)
	extra_lbl.custom_minimum_size.x = 92
	er.add_child(extra_lbl)
	col.add_child(er)
	var em := HBoxContainer.new()
	em.add_child(_lbl("Ils sont", 13, Color(1, 1, 1, 0.75)))
	for m in EXTRA_MODES:
		extra_opt.add_item(m[1])
	extra_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extra_opt.item_selected.connect(func(k): set_extra(extra, EXTRA_MODES[k][0]))
	em.add_child(extra_opt)
	col.add_child(em)
	_show_extra()
	var ar := CheckBox.new()
	ar.text = "Remettre la situation tout seul après chaque essai"
	ar.button_pressed = auto_reset
	ar.toggled.connect(func(on): auto_reset = on)
	col.add_child(ar)
	id_lbl.add_theme_font_size_override("font_size", 11)
	id_lbl.modulate = Color(1, 1, 1, 0.5)
	id_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(id_lbl)
	var back := Button.new()
	back.text = "Retour au salon (F2)"
	back.pressed.connect(back_to_game)
	col.add_child(back)
	var edit := Button.new()
	edit.text = "Éditeur d'animation (F3)"
	edit.pressed.connect(open_editor)
	col.add_child(edit)
	set_speed(0)

	# Petite fiche quand le menu est fermé.
	mini.anchor_left = 1.0
	mini.anchor_right = 1.0
	mini.offset_left = -360
	mini.offset_top = 12
	mini.offset_right = -12
	var mb := StyleBoxFlat.new()
	mb.bg_color = Color(0.07, 0.09, 0.15, 0.75)
	mb.set_corner_radius_all(8)
	mb.set_content_margin_all(10)
	mini.add_theme_stylebox_override("panel", mb)
	mini_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mini_lbl.add_theme_font_size_override("font_size", 14)
	mini.add_child(mini_lbl)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(mini)


## Ouvre (pause, la manette pilote le menu) ou ferme (la manette pilote le héros) le menu du labo.
func set_menu(on: bool) -> void:
	menu_open = on
	panel.visible = on
	mini.visible = not on
	get_tree().paused = on
	if on:
		pick.grab_focus()
	else:
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
		for a in ["light", "heavy", "grab", "jump", "roll", "guard", "special"]:
			if InputMap.has_action(a):
				Input.action_release(a)   # l'appui qui a fermé le menu ne part pas en coup


func _lbl(t: String, size: int, c: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


const SCENE_TEXT := {
	"stand": "Un sbire debout devant toi, immobile.",
	"guard": "Un sbire en garde devant toi.",
	"guard_far": "Un sbire en garde, à deux pas devant toi.",
	"down": "Un sbire couché devant toi. Il reste au sol.",
	"air": "Un sbire relancé en l'air devant toi, en boucle. Saute pour le cueillir.",
	"attack": "Un sbire qui t'attaque.",
	"crowd": "Trois sbires immobiles tout autour de toi.",
	"far": "Un sbire debout loin devant : prends ton élan.",
	"grabbed": "Tu tiens déjà un sbire par le col.",
	"grab_wall": "Tu tiens un sbire par le col, le long d'un mur (à ta gauche).",
	"wall": "Un mur juste devant toi, un sbire derrière toi.",
	"prop_hand": "Tu tiens un objet au-dessus de ta tête, un sbire devant toi.",
	"prop_hand_attack": "Tu tiens un objet au-dessus de ta tête, un sbire t'attaque.",
	"prop_ground": "Un objet posé devant toi, un sbire derrière l'objet.",
	"line": "Un sbire couché devant toi, deux autres debout plus loin dans l'axe.",
	"free": "Deux sbires immobiles un peu plus loin.",
	"arena": "Salle des builds : trois sbires qui attaquent tout autour (immortels). Le héros a tous les coups du palier choisi.",
	"shooter": "Un sbire tireur à 7 m : il te lance une boule toutes les 2 secondes.",
	"armed": "Un sbire armé d'un bâton qui t'attaque.",
	"shooter_grab": "Tu tiens un sbire par le col ; un tireur en face.",
	"shooter_prop": "Tu tiens une caisse ; un tireur en face.",
	"dummy": "Salle libre : un pantin à vie infinie, qui ne riposte pas.",
	"wall_side": "Un mur le long de toi, sur ta droite ; deux sbires plus loin le long du mur.",
}


## Couleur d'un bouton (premier bouton de la commande) : X bleu, Y jaune, B rouge, A vert ; transparent pour les autres.
const BTN_COLORS := {"X": Color(0.35, 0.6, 1.0), "Y": Color(1.0, 0.85, 0.25), "B": Color(1.0, 0.35, 0.3), "A": Color(0.35, 0.9, 0.45)}
const BTN_ORDER := ["X", "Y", "B", "A"]


static func first_button(b: String) -> String:
	for w in b.replace("/", " ").replace("+", " ").split(" ", false):
		return w
	return ""


static func btn_color(b: String) -> Color:
	return BTN_COLORS.get(first_button(b), Color(0, 0, 0, 0))


## Ordre d'affichage : pantin et salles des builds d'abord, puis X, Y, B, A, puis les autres boutons (ordre du catalogue dans chaque groupe).
static func _sorted_moves() -> Array:
	var idx := []
	for i in LaboCatalog.MOVES.size():
		idx.append(i)
	var rank := func(i: int) -> int:
		var b: String = first_button(LaboCatalog.MOVES[i].button)
		if b == "—":
			return 0
		var k := BTN_ORDER.find(b)
		return 1 + (k if k >= 0 else BTN_ORDER.size())
	idx.sort_custom(func(a, c): return rank.call(a) < rank.call(c) or (rank.call(a) == rank.call(c) and a < c))
	return idx


## Petite pastille de couleur (icône de la liste).
static func _dot(c: Color) -> ImageTexture:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 14:
		for x in 14:
			if Vector2(x - 6.5, y - 6.5).length() <= 6.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func entry() -> Dictionary:
	return LaboCatalog.MOVES[cur]


func select(i: int) -> void:
	cur = wrapi(i, 0, LaboCatalog.MOVES.size())
	pick.select(pick.get_item_index(cur))
	var m := entry()
	name_lbl.text = m.name
	var bc := btn_color(m.button)
	button_lbl.add_theme_color_override("font_color", bc if bc.a > 0.0 else Color(1, 0.85, 0.35))
	status_lbl.text = "NOUVEAU" if m.status == "tester" else "EXISTANT"
	status_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0.3) if m.status == "tester" else Color(0.5, 0.9, 0.6))
	button_lbl.text = m.button
	cmd_lbl.text = m.command
	what_lbl.text = m.what + ("\n\n" + BuildTiers.describe(m.build) if m.has("build") else "")
	scene_lbl.text = SCENE_TEXT.get(m.scene, "")
	note_lbl.text = m.get("note", "")
	note_lbl.visible = m.has("note")
	mini_lbl.text = "%s   [%s]\n%s\nStart : menu du labo · ▲ / Select : remettre · v%s" % [m.name, m.button, m.command, GameVersion.NUM]
	id_lbl.text = "Version v%s · carte du site : %s — tes retours sur l'atelier des coups (filtre « Dans le labo »)." % [GameVersion.NUM, m.id]
	var_box.visible = m.has("variants")
	var_opt.clear()
	if m.has("variants"):
		for v in m.variants[1]:
			var_opt.add_item(v[1])
		var chosen = variant.get(m.id, m.variants[1][0][0])
		for k in m.variants[1].size():
			if m.variants[1][k][0] == chosen:
				var_opt.select(k)
	setup()


func _on_variant(k: int) -> void:
	var m := entry()
	variant[m.id] = m.variants[1][k][0]
	setup()


func set_speed(i: int) -> void:
	speed_i = i
	main.base_time_scale = SPEEDS[i]
	Engine.time_scale = SPEEDS[i]
	for k in speed_btns.size():
		speed_btns[k].button_pressed = k == i


## Sbires en plus autour de la situation (immobiles, en garde ou qui attaquent), puis remise en situation.
func set_extra(n: int, mode: String) -> void:
	extra = clampi(n, 0, MAX_ENEMIES - 1)
	extra_mode = mode
	_show_extra()
	setup()


func _show_extra() -> void:
	extra_lbl.text = "aucun" if extra == 0 else "+%d" % extra
	extra_slider.set_value_no_signal(extra)
	for k in EXTRA_MODES.size():
		if EXTRA_MODES[k][0] == extra_mode:
			extra_opt.select(k)


## Aimantation : 0 = désactivée, 1 = très forte.
func set_lock(v: float) -> void:
	player.lock_power = v
	lock_lbl.text = "désactivée" if v <= 0.0 else "%.2f" % v
	if lock_slider.value != v:
		lock_slider.set_value_no_signal(v)


## Éditeur d'animation (F3) : on retouche le coup, on revient ici avec F2 pour l'essayer.
func open_editor() -> void:
	get_tree().paused = false
	main.base_time_scale = 1.0
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://anim_editor.tscn")


func back_to_game() -> void:
	get_tree().paused = false
	main.base_time_scale = 1.0
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://hub.tscn")


# ---------------------------------------------------------------- mise en situation

## Remet tout à zéro et installe la situation du coup choisi.
func setup() -> void:
	var m := entry()
	var sc: String = m.scene
	if m.has("variants") and m.variants[0] == "@scene":   # la variante choisit la situation (ex. course au mur : face / le long)
		sc = variant.get(m.id, m.variants[1][0][0])
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()
	spawned.clear()
	# Héros : réglages de base, puis ceux du coup.
	if player.held_prop and is_instance_valid(player.held_prop):
		player.held_prop = null
	for k in LaboCatalog.DEFAULTS:
		player.set(k, _copy(LaboCatalog.DEFAULTS[k]))
	if m.has("build"):
		var bs := BuildTiers.settings(m.build)
		for k in bs:
			player.set(k, _copy(bs[k]))
	for k in m.get("loadout", {}):
		player.set(k, _copy(m.loadout[k]))
	if m.has("variants") and m.variants[0] != "@scene":
		player.set(m.variants[0], _copy(variant.get(m.id, m.variants[1][0][0])))
	for n in get_tree().get_nodes_in_group("projectiles"):
		n.queue_free()
	shoot_t.clear()
	if player.ragdoll_t >= 0.0:
		player._ragdoll_off()
	player.attack = ""
	player.roll = -1.0
	player.hurt = 0.0
	player.sprinting = false
	player.velocity = Vector3.ZERO
	# Appuis gardés en mémoire : on les oublie (un coup pressé avant la remise ne part pas dans la nouvelle situation).
	for k in ["light_buf", "heavy_buf", "grab_buf", "jump_buf", "roll_buf", "air_buf", "recover_t", "grab_cd", "sweep_cd"]:
		player.set(k, 0.0)
	player.queued = false
	player.queued2_t = -9.0
	player.roll_atk = ""
	player.y_hold = -1.0
	# « Devant » = vers le haut du stick (la caméra regarde en diagonale) : pousser le stick vers le haut mène au sbire.
	var f := Vector3(1, 0, -1).normalized()
	var rt := f.cross(Vector3.UP)
	var o := Vector3.ZERO
	player.global_position = o
	player.rotation.y = atan2(-f.x, -f.z)
	player.hp = 100.0
	player.grab_cd = 0.0
	player.sweep_cd = 0.0
	player.special = 0.0
	modes.clear()
	stand_t.clear()
	if sc.begins_with("map:"):   # carte de test : héros à un endroit précis du décor, sbires placés autour
		var an: Dictionary = map.anchors[sc.substr(4)]
		o = an.at
		f = an.f
		rt = f.cross(Vector3.UP)
		player.global_position = o + Vector3.UP * 0.02
		player.rotation.y = atan2(-f.x, -f.z)
		var foes := []
		for d in m.get("foes", []):
			foes.append([o + f * d[0] + rt * d[1], d[2]])
		_dummies(foes)
	match sc:
		"stand":
			_dummies([[o + f * 1.1, "stand"]])
		"guard":
			_dummies([[o + f * 1.1, "guard"]])
		"guard_far":
			_dummies([[o + f * 2.6, "guard"]])
		"down":
			_dummies([[o + f * 1.0, "down"]])
		"air":
			_dummies([[o + f * 1.2, "air"]])
		"attack":
			_dummies([[o + f * 1.6, "attack"]])
		"crowd":
			_dummies([[o + f * 1.2, "stand"], [o + f.rotated(Vector3.UP, TAU / 3) * 1.2, "stand"], [o + f.rotated(Vector3.UP, -TAU / 3) * 1.2, "stand"]])
		"far":
			_dummies([[o + f * 7.0, "stand"]])
		"free":
			_dummies([[o + f * 3.0 - rt * 2.5, "stand"], [o + f * 3.0 + rt * 2.5, "stand"]])
		"line":
			_dummies([[o + f * 1.0, "down"], [o + f * 4.0, "stand"], [o + f * 6.0 + rt * 0.6, "stand"]])
		"shooter":
			_dummies([[o + f * 7.0, "shoot"]])
		"armed":
			_dummies([[o + f * 1.6, "armed"]])
		"shooter_grab":
			_dummies([[o + f * 0.75, "stand"], [o + f * 7.5, "shoot"]])
			_grab_first()
		"shooter_prop":
			_dummies([[o + f * 7.5, "shoot"]])
			var bp := _prop(o + f * 0.75)
			player.throw_move = "slam"
			player.held_prop = null
			await get_tree().physics_frame
			if is_instance_valid(bp):
				player._try_prop()
		"grabbed":
			_dummies([[o + f * 0.75, "stand"]])
			_grab_first()
		"grab_wall":   # le long du mur B de la carte (sur la droite)
			var an: Dictionary = map.anchors.wall_side
			f = an.f
			o = an.at - f * 2.5
			player.global_position = o
			player.rotation.y = atan2(-f.x, -f.z)
			_dummies([[o + f * 0.75, "stand"]])
			_grab_first()
		"dummy":
			_dummies([[o + f * 1.4, "stand"]])
		"arena":
			_dummies([[o + f * 4.0, "attack"], [o + f.rotated(Vector3.UP, TAU / 3) * 4.0, "attack"], [o + f.rotated(Vector3.UP, -TAU / 3) * 4.0, "attack"]])
		"wall_side":   # mur B de la carte, sur la droite
			var an: Dictionary = map.anchors.wall_side
			f = an.f
			rt = f.cross(Vector3.UP)
			o = an.at - f * 2.0
			player.global_position = o
			player.rotation.y = atan2(-f.x, -f.z)
			_dummies([[o + f * 3.2 + rt * 0.1, "stand"], [o + f * 5.5 - rt * 0.4, "stand"]])
		"wall":   # mur A de la carte, juste devant
			var an: Dictionary = map.anchors.wall_front
			f = an.f
			o = an.at + f * 0.25
			player.global_position = o
			player.rotation.y = atan2(-f.x, -f.z)
			_dummies([[o - f * 3.0, "stand"]])
		"prop_hand", "prop_hand_attack":
			_dummies([[o + f * 1.6, "attack" if sc == "prop_hand_attack" else "stand"]])
			var b := _prop(o + f * 0.75)
			player.throw_move = "slam"
			player.held_prop = null
			await get_tree().physics_frame
			if is_instance_valid(b):
				player._try_prop()
		"prop_ground":
			_prop(o + f * 0.85)
			_dummies([[o + f * 3.5, "stand"]])
	if player.lc:
		player.lc.reset()
	idle_t = 0.0
	tried = false


## Place les sbires : [[position, mode], ...] (positions par rapport au centre).
func _dummies(list: Array) -> void:
	list = list.duplicate()
	var f := Vector3(1, 0, -1).normalized()
	var o := player.global_position
	var slots := [-55.0, 55.0, -110.0, 110.0, 180.0]   # en éventail devant et sur les côtés, à 3.2 m
	var n := mini(extra, MAX_ENEMIES - list.size())
	for k in n:
		list.append([o + f.rotated(Vector3.UP, deg_to_rad(slots[k])) * 3.2, extra_mode])
	main.set_enemy_count(list.size())
	player.enemies = main.enemies
	for i in list.size():
		var e = main.enemies[i]
		e.global_position = list[i][0]
		if map:
			e.global_position.y = map.ground_y(list[i][0])   # sur l'escalier, la plateforme…
		e.build()
		var d: Vector3 = player.global_position - e.global_position
		if d.length() > 0.01:
			e.root.basis = Basis(Vector3.UP, atan2(d.x, d.z))   # il te regarde
		modes[e] = list[i][1]
		e.ai_on = list[i][1] in ["attack", "armed"]
		if list[i][1] == "armed":
			e.give_weapon()
		stand_t[e] = KEEP   # « couché » ou « en l'air » s'applique tout de suite
	player.enemy = main.enemies[0]


## Le premier sbire est déjà tenu par le col (il ne se dégage pas).
func _grab_first() -> void:
	await get_tree().physics_frame
	var e = main.enemies[0]
	var d: Vector3 = e.global_position - player.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.enemy = e
	e.collar_grab()
	player.collar_limit = 999.0
	player.collar_held = 0.0
	player.collar_hits = 0
	player.collar_q = false
	player.start("collar")


func _wall(at: Vector3, size: Vector3, f: Vector3) -> void:
	var w := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = size
	w.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = size
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.45, 0.42, 0.5)
	mi.material_override = mt
	w.add_child(mi)
	w.collision_layer = 1
	main.add_child(w)
	w.global_position = at + Vector3.UP * size.y * 0.5
	w.rotation.y = atan2(-f.x, -f.z)   # largeur en travers, profondeur dans l'axe
	spawned.append(w)


func _prop(at: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	var size := Vector3(0.55, 0.6, 0.55)
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = size
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = size
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.62, 0.45, 0.28)
	mi.material_override = mt
	b.add_child(mi)
	b.mass = 20.0   # v0.218 : plus lourde (6 kg avant)
	preload("res://room.gd")._steady(b, "crate")
	b.collision_layer = 1
	b.collision_mask = 1 | 2 | 8
	b.add_to_group("reactive")
	b.set_meta("kind", "caisse")
	main.add_child(b)
	b.global_position = at + Vector3.UP * size.y * 0.5
	spawned.append(b)
	return b


# ---------------------------------------------------------------- boucle

func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton and ev.pressed:
		if ev.button_index == JOY_BUTTON_START:
			_toggle_menu()
		elif not menu_open and ev.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_BACK]:
			setup()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.physical_keycode:
			KEY_TAB:
				_toggle_menu()
			KEY_R:
				if not menu_open:
					setup()
			KEY_F2:
				back_to_game()
			KEY_F3:
				open_editor()


func _toggle_menu() -> void:
	# Une liste déroulante ouverte se ferme d'abord.
	for o in [pick, var_opt]:
		if o.get_popup().visible:
			o.get_popup().hide()
	set_menu(not menu_open)
	get_viewport().set_input_as_handled()


## Valeur d'un réglage (les dictionnaires et listes sont copiés : le héros les modifie).
func _copy(v: Variant) -> Variant:
	return v.duplicate(true) if typeof(v) in [TYPE_DICTIONARY, TYPE_ARRAY] else v


var shoot_t := {}   # sbire tireur -> temps avant son prochain tir


func _shoot(e: Node, dt: float) -> void:
	if e.state != "stand":
		return
	var to: Vector3 = player.global_position - e.root.origin
	to.y = 0.0
	e.root.basis = Basis(Vector3.UP, atan2(to.x, to.z))
	shoot_t[e] = shoot_t.get(e, 1.0) - dt
	if shoot_t[e] > 0.0 or to.length() < 2.0:
		return
	shoot_t[e] = 1.8
	var pr := Projectile.new()
	pr.shooter = e
	pr.hero = player
	main.add_child(pr)
	var at: Vector3 = e.parts.chest.global_position + to.normalized() * 0.5
	pr.global_position = at
	pr.velocity = ((player.global_position + Vector3.UP * 1.1) - at).normalized() * Projectile.SPEED


func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	player.hp = 100.0
	for e in main.enemies:
		if not is_instance_valid(e) or e.parts.is_empty():
			continue
		e.hp = e.MAX_HP   # jamais mort
		var mode: String = modes.get(e, "stand")
		e.ai_on = mode in ["attack", "armed"]
		if mode == "shoot":
			_shoot(e, dt)
		if e.state == "down" and mode == "down" and e.parts.pelvis.global_position.y < 0.6:
			e.timer = maxf(e.timer, 1.0)   # il reste couché
		if e.state != "stand":
			stand_t[e] = 0.0
			continue
		stand_t[e] = stand_t.get(e, 0.0) + dt
		match mode:
			"guard":
				e.ai = "block"
				e.block_t = 1.0
			"down":
				if stand_t[e] >= KEEP:
					var d: Vector3 = (player.global_position - e.global_position) * Vector3(1, 0, 1)
					e.trip(-d.normalized() if d.length() > 0.01 else Vector3.BACK, 0.0, 1.0)
			"air":
				if stand_t[e] >= KEEP:
					_launch_up(e)
	# Remise automatique : après un essai, quand tout est calme, on réinstalle la situation.
	if player.attack != "" or player.roll >= 0.0:
		tried = true
		idle_t = 0.0
	elif tried:
		idle_t += dt
		if auto_reset and idle_t > 1.6 and entry().scene in ["grabbed", "grab_wall", "prop_hand", "prop_hand_attack", "prop_ground", "wall", "wall_side", "line"]:
			setup()


func _launch_up(e) -> void:
	e.state = "down"
	e.timer = e.DOWN_TIME
	e.air_recover = true
	e.juggles = 0
	for b in e.parts.values():
		b.freeze = false
		b.gravity_scale = 1.6
		b.linear_velocity = Vector3.UP * 8.5
		b.angular_velocity = Vector3.ZERO

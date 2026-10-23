extends Node3D
## Salle de test des coups. Lancer move_lab.tscn (F6 sur la scène, ou clic droit > Lancer).
##
## - Liste de tous les coups (fiches de res://moves/) : double-clic ou Entrée = le héros le joue face au mannequin.
## - Mannequins : libres (IA normale), immobiles, en garde, en l'air ou au sol ; ils reviennent tout seuls dans l'état choisi
##   et ne meurent jamais (les dégâts s'affichent dans le journal).
## - Ralenti, pause, image par image ; zone de frappe affichée ; durées du coup en images (60 par seconde).
## - F5 recharge les fiches : on règle un coup dans l'inspecteur de Godot, on enregistre, F5, on rejoue.
##
## Raccourcis clavier : Entrée jouer · F rejouer · 1 2 3 4 vitesse · P pause · N image suivante · H zones de frappe ·
## C caméra · M état des mannequins · F5 recharger. La manette marche comme en jeu (Start = menu des améliorations).

const MAIN := preload("res://main.tscn")
const SPEEDS := [1.0, 0.5, 0.25, 0.1]
const STATES := [["free", "Libres (IA normale)"], ["stand", "Immobiles"], ["guard", "En garde"], ["air", "En l'air"], ["ground", "Au sol"]]
const CAMS := ["Vue du jeu", "De côté", "De face", "De près"]
const REAPPLY := 0.7      # s debout avant de remettre un mannequin en l'air / au sol
const FPS := 60.0

var main: Node3D
var player: CharacterBody3D
var speed_i := 0
var dummy_state := "stand"
var cam_i := 0
var show_hit := true
var keep_close := true
var last_move := ""
var cur_move := ""        # coup en cours (ou le dernier joué, pour la frise)
var cur_t := 0.0
var cur_hit_t := -1.0     # instant où il a touché
var stand_t := {}         # mannequin -> temps passé debout
var log_lines: Array[String] = []
var ids: Array[String] = []   # index de la liste -> id du coup ("" = titre de groupe)

var ui := CanvasLayer.new()
var list := ItemList.new()
var info := RichTextLabel.new()
var timeline := Control.new()
var log_label := Label.new()
var speed_btns: Array[Button] = []
var pause_btn := Button.new()
var state_opt := OptionButton.new()
var cam_opt := OptionButton.new()
var count_spin := SpinBox.new()
var hit_ball := MeshInstance3D.new()
var hit_mat := StandardMaterial3D.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100   # après main : la caméra de la salle passe en dernier
	main = MAIN.instantiate()
	main.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(main)
	player = main.player
	hit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hit_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hit_mat.no_depth_test = true
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	hit_ball.mesh = sm
	hit_ball.material_override = hit_mat
	hit_ball.visible = false
	add_child(hit_ball)
	_build_ui()
	_set_dummies(dummy_state)


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	ui.layer = 5
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -420
	panel.offset_top = 12
	panel.offset_right = -12
	panel.offset_bottom = -12
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.1, 0.16, 0.88)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", bg)
	var th := Theme.new()
	th.default_font_size = 13
	panel.theme = th
	main.hint.visible = false   # l'aide du jeu passerait sous le panneau
	ui.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)

	col.add_child(_title("SALLE DE TEST DES COUPS", 18))
	col.add_child(_small("Double-clic ou Entrée : jouer · F : rejouer · F5 : recharger les fiches"))

	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(0, 220)
	list.item_activated.connect(func(i): _play_index(i))
	col.add_child(list)
	_fill_list()

	var row := HBoxContainer.new()
	var play := Button.new()
	play.text = "Jouer (Entrée)"
	play.pressed.connect(func(): _play_selected())
	var again := Button.new()
	again.text = "Rejouer (F)"
	again.pressed.connect(func(): replay())
	var reload_b := Button.new()
	reload_b.text = "Recharger (F5)"
	reload_b.pressed.connect(func(): reload())
	var back := Button.new()
	back.text = "Retour au salon (F2)"
	back.pressed.connect(back_to_game)
	for b in [play, again, reload_b]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	col.add_child(row)
	col.add_child(back)

	col.add_child(_title("Mannequins", 14))
	var r2 := HBoxContainer.new()
	for s in STATES:
		state_opt.add_item(s[1])
	state_opt.select(1)
	state_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_opt.item_selected.connect(func(i): _set_dummies(STATES[i][0]))
	r2.add_child(state_opt)
	count_spin.min_value = 1
	count_spin.max_value = 6
	count_spin.value = 1
	count_spin.prefix = "×"
	count_spin.value_changed.connect(func(v): _set_count(int(v)))
	r2.add_child(count_spin)
	col.add_child(r2)
	var r2b := HBoxContainer.new()
	var close := CheckBox.new()
	close.text = "Placer à portée du coup"
	close.button_pressed = keep_close
	close.toggled.connect(func(on): keep_close = on)
	r2b.add_child(close)
	var reset := Button.new()
	reset.text = "Remettre en place"
	reset.pressed.connect(func(): _reset_dummies())
	r2b.add_child(reset)
	col.add_child(r2b)

	col.add_child(_title("Temps et affichage", 14))
	var r3 := HBoxContainer.new()
	for i in SPEEDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = "×%s" % str(SPEEDS[i])
		b.tooltip_text = "Touche %d" % (i + 1)
		b.pressed.connect(func(): set_speed(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speed_btns.append(b)
		r3.add_child(b)
	col.add_child(r3)
	var r3b := HBoxContainer.new()
	pause_btn.text = "Pause (P)"
	pause_btn.toggle_mode = true
	pause_btn.pressed.connect(func(): toggle_pause())
	pause_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3b.add_child(pause_btn)
	var step := Button.new()
	step.text = "+1 image (N)"
	step.pressed.connect(func(): step_frame())
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r3b.add_child(step)
	col.add_child(r3b)
	var r4 := HBoxContainer.new()
	var hb := CheckBox.new()
	hb.text = "Zones de frappe (H)"
	hb.button_pressed = show_hit
	hb.toggled.connect(func(on): show_hit = on)
	r4.add_child(hb)
	for c in CAMS:
		cam_opt.add_item(c)
	cam_opt.item_selected.connect(func(i): cam_i = i)
	cam_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r4.add_child(cam_opt)
	col.add_child(r4)

	col.add_child(_title("Le coup", 14))
	timeline.custom_minimum_size = Vector2(0, 46)
	timeline.draw.connect(_draw_timeline)
	col.add_child(timeline)
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.add_theme_font_size_override("normal_font_size", 13)
	info.add_theme_font_size_override("bold_font_size", 13)
	col.add_child(info)
	col.add_child(_title("Journal des touches", 14))
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.modulate = Color(1, 1, 1, 0.85)
	col.add_child(log_label)
	set_speed(0)
	_refresh_info()


func _title(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.55, 0.72, 1.0))
	return l


func _small(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.modulate = Color(1, 1, 1, 0.7)
	return l


## Groupes de la liste : on range chaque fiche d'après ce qu'elle fait.
static func group_of(m: MoveData) -> String:
	if "projectile" in m.flags or "quake" in m.flags:
		return "Spéciaux"
	if m.tip == "":
		return "Prises, objets, enchaînements (à la manette)"
	if m.air:
		return "En l'air"
	if m.heavy:
		return "Coups lourds"
	return "Coups légers"


## Un coup se lance seul depuis la liste s'il frappe directement (les prises demandent un ennemi en main : à la manette).
static func playable(m: MoveData) -> bool:
	return m.tip != "" or "projectile" in m.flags or "quake" in m.flags


func _fill_list() -> void:
	list.clear()
	ids.clear()
	var groups := {}
	var moves := MoveLibrary.moves()
	for id in moves:
		var g := group_of(moves[id])
		if not groups.has(g):
			groups[g] = []
		groups[g].append(id)
	for g in ["Coups légers", "Coups lourds", "En l'air", "Spéciaux", "Prises, objets, enchaînements (à la manette)"]:
		if not groups.has(g):
			continue
		var i := list.add_item("— " + g + " —")
		list.set_item_selectable(i, false)
		list.set_item_custom_fg_color(i, Color(0.55, 0.72, 1.0))
		ids.append("")
		var names: Array = groups[g]
		names.sort_custom(func(a, b): return String(moves[a].display_name).naturalnocasecmp_to(String(moves[b].display_name)) < 0)
		for id in names:
			var m: MoveData = moves[id]
			var label := "   %s   (%s)" % [m.display_name if m.display_name != "" else id, id]
			i = list.add_item(label)
			if not playable(m):
				list.set_item_custom_fg_color(i, Color(1, 1, 1, 0.45))
				list.set_item_tooltip(i, "Se joue à la manette, en situation (il faut tenir un ennemi ou un objet).")
			ids.append(id)


# ---------------------------------------------------------------- actions

func _play_selected() -> void:
	var sel := list.get_selected_items()
	if sel.size() > 0:
		_play_index(sel[0])


func _play_index(i: int) -> void:
	if i >= 0 and i < ids.size() and ids[i] != "":
		play(ids[i])


func replay() -> void:
	if last_move != "":
		play(last_move)


## Le héros joue ce coup, tourné vers le mannequin (un coup aérien part d'un saut).
func play(id: String) -> void:
	var m: MoveData = MoveLibrary.moves().get(id)
	if m == null:
		return
	last_move = id
	if not playable(m):
		_log("%s : à jouer à la manette (il faut tenir un ennemi ou un objet)" % m.display_name)
		return
	var e = _first_dummy()
	if e and keep_close and e.state == "stand" and not m.air:
		var fwd: Vector3 = -player.global_basis.z
		var dist: float = player.IDEAL.get(id, 0.9)
		e.global_position = player.global_position + fwd * (dist + 0.15)
		e.build()
	if e:
		var d: Vector3 = e.global_position - player.global_position
		d.y = 0
		if d.length() > 0.01:
			player.rotation.y = atan2(-d.x, -d.z)
	player.attack = ""
	if m.air and player.is_on_floor():
		player.velocity.y = player.JUMP_SPEED
		await get_tree().create_timer(0.16, false).timeout
	player.start(id)


## Relit les fiches sur le disque (après une modification dans l'inspecteur) et les donne au héros.
func reload() -> void:
	MoveLibrary.reload()
	player.ATK = MoveLibrary.table()
	player.GUARD = MoveLibrary.poses().guard
	player.POSE_DIFF = MoveLibrary.poses().diffs
	_fill_list()
	_log("Fiches rechargées (%d coups)" % player.ATK.size())


func back_to_game() -> void:
	get_tree().paused = false
	main.base_time_scale = 1.0
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://hub.tscn")


func set_speed(i: int) -> void:
	speed_i = i
	main.base_time_scale = SPEEDS[i]
	Engine.time_scale = SPEEDS[i]
	for k in speed_btns.size():
		speed_btns[k].button_pressed = k == i


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_btn.button_pressed = get_tree().paused


func step_frame() -> void:
	if not get_tree().paused:
		toggle_pause()
		return
	get_tree().paused = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = true


func _set_dummies(s: String) -> void:
	dummy_state = s
	for i in STATES.size():
		if STATES[i][0] == s:
			state_opt.select(i)
	for e in main.enemies:
		e.ai_on = s == "free"
		stand_t[e] = REAPPLY   # on applique tout de suite
		if e.state != "stand":
			e.build()   # debout tout de suite, puis l'état choisi s'applique à l'image suivante


func _set_count(n: int) -> void:
	main.set_enemy_count(n)
	player.enemies = main.enemies
	_reset_dummies()


func _reset_dummies() -> void:
	var n: int = main.enemies.size()
	for i in n:
		var e = main.enemies[i]
		var a := -PI / 2 + (i - (n - 1) / 2.0) * 0.5
		var fwd: Vector3 = -player.global_basis.z
		e.global_position = player.global_position + fwd.rotated(Vector3.UP, a + PI / 2) * (1.3 + 0.4 * i)
		e.build()
	_set_dummies(dummy_state)


func _first_dummy():
	return main.enemies[0] if main.enemies.size() > 0 else null


func _log(s: String) -> void:
	log_lines.push_front(s)
	if log_lines.size() > 7:
		log_lines.resize(7)
	log_label.text = "\n".join(log_lines)


# ---------------------------------------------------------------- boucle

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	match ev.physical_keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_play_selected()
		KEY_F:
			replay()
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_speed(ev.physical_keycode - KEY_1)
		KEY_P:
			toggle_pause()
		KEY_N:
			step_frame()
		KEY_H:
			show_hit = not show_hit
		KEY_C:
			cam_i = (cam_i + 1) % CAMS.size()
			cam_opt.select(cam_i)
		KEY_M:
			var i := 0
			for k in STATES.size():
				if STATES[k][0] == dummy_state:
					i = k
			_set_dummies(STATES[(i + 1) % STATES.size()][0])
		KEY_F5:
			reload()
		KEY_F2:
			back_to_game()


func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	for e in main.enemies:
		if not is_instance_valid(e):
			continue
		# Jamais mort : on note les dégâts et on lui rend sa vie.
		if e.hp < e.MAX_HP:
			var dmg: float = e.MAX_HP - e.hp
			e.hp = e.MAX_HP
			var by := cur_move if cur_move != "" else "?"
			_log("%s : %d dégâts (mannequin %s)" % [by, roundi(dmg), _state_name(e.state)])
			if cur_hit_t < 0:
				cur_hit_t = cur_t
		e.ai_on = dummy_state == "free"
		if e.state != "stand":
			stand_t[e] = 0.0
			continue
		stand_t[e] = stand_t.get(e, 0.0) + dt
		match dummy_state:
			"guard":
				e.ai = "block"
				e.block_t = 1.0
			"air":
				if stand_t[e] >= REAPPLY:
					_launch_up(e)
			"ground":
				if stand_t[e] >= REAPPLY:
					e.trip(-_dir_to_player(e), 0.0, 1.2)


## Mannequin « en l'air » : il décolle tout droit, haut et longtemps, puis se rattrape sur ses pieds (et on recommence).
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


func _dir_to_player(e) -> Vector3:
	var d: Vector3 = player.global_position - e.global_position
	d.y = 0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


static func _state_name(s: String) -> String:
	return {"stand": "debout", "down": "au sol", "dead": "au sol", "getup": "se relève", "launch": "projeté", "crisp": "en l'air",
		"held": "tenu", "swung": "tenu", "techroll": "roulade", "rise": "se relève"}.get(s, s)


func _process(_dt: float) -> void:
	# Coup en cours : on le suit pour la frise ; à la fin, on garde le dernier affiché.
	if player.attack != "" and player.ATK.has(player.attack):
		if player.attack != cur_move or player.t < cur_t - 0.001:
			cur_move = player.attack
			cur_hit_t = -1.0
		cur_t = player.t
	_update_hitbox()
	_update_camera()
	timeline.queue_redraw()
	_refresh_info()


func _update_hitbox() -> void:
	var a: Dictionary = player.ATK.get(player.attack, {})
	if not show_hit or player.attack == "" or not a.has("tip") or not player.j.has(a.tip):
		hit_ball.visible = false
		return
	hit_ball.visible = true
	hit_ball.global_position = player.j[a.tip].global_position
	hit_ball.scale = Vector3.ONE * maxf(a.get("r", 0.3), 0.05)
	var t: float = player.t
	var c := Color(1.0, 0.75, 0.2, 0.18)       # avant l'impact : orange pâle
	if absf(t - a.active) < 0.03:
		c = Color(1.0, 0.15, 0.1, 0.55)         # l'instant où il frappe : rouge vif
	elif t > a.active:
		c = Color(0.7, 0.7, 0.8, 0.12)          # après : gris
	hit_mat.albedo_color = c


func _update_camera() -> void:
	if cam_i == 0:
		return
	var p: Vector3 = player.global_position
	var fwd: Vector3 = -player.global_basis.z
	var right: Vector3 = player.global_basis.x
	var eye: Vector3
	match cam_i:
		1:
			eye = p + right * 3.6 + Vector3.UP * 1.2 + fwd * 0.6
		2:
			eye = p + fwd * 3.6 + Vector3.UP * 1.3
		_:
			eye = p + right * 1.6 + fwd * 1.4 + Vector3.UP * 1.4
	var target := p + Vector3.UP * 0.9 + fwd * 0.5
	var e = _first_dummy()
	if e and e.parts.has("pelvis"):
		var to: Vector3 = e.parts.pelvis.global_position - p
		target = p + Vector3.UP * 0.9 + Vector3(to.x, 0, to.z).limit_length(2.0) * 0.5   # entre les deux, sans suivre un mannequin parti loin
	# Le panneau couvre la droite de l'écran : on décale la vue pour que l'action reste dans la partie visible.
	var cr := (target - eye).cross(Vector3.UP).normalized()
	main.cam.look_at_from_position(eye + cr * 0.6, target + cr * 0.6)


# ---------------------------------------------------------------- frise et infos

func _frames(x: float) -> int:
	return roundi(x / player.attack_speed * FPS)


func _draw_timeline() -> void:
	var w := timeline.size.x
	var h := 18.0
	var y := 6.0
	var font := ThemeDB.fallback_font
	if cur_move == "" or not player.ATK.has(cur_move):
		timeline.draw_string(font, Vector2(0, 30), "Jouez un coup pour voir ses durées.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
		return
	var a: Dictionary = player.ATK[cur_move]
	var end: float = minf(a.end, 3.0) if a.end < 90.0 else maxf(cur_t + 0.2, 1.0)
	var sx := w / maxf(end, 0.01)
	var act: float = minf(a.active, end)
	var can: float = minf(a.cancel, end)
	timeline.draw_rect(Rect2(0, y, act * sx, h), Color(0.35, 0.5, 0.85))                       # démarrage
	timeline.draw_rect(Rect2(act * sx, y, maxf((end - act) * sx, 0), h), Color(0.3, 0.32, 0.4))  # récupération
	timeline.draw_rect(Rect2(act * sx - 2, y - 3, 4, h + 6), Color(1, 0.2, 0.15))              # impact
	timeline.draw_line(Vector2(can * sx, y - 4), Vector2(can * sx, y + h + 4), Color(0.4, 1, 0.5), 2.0)   # annulable dès
	if cur_hit_t >= 0:
		timeline.draw_circle(Vector2(cur_hit_t * sx, y + h / 2), 5, Color(1, 1, 1))
	var tx := clampf(cur_t, 0, end) * sx
	timeline.draw_line(Vector2(tx, y - 6), Vector2(tx, y + h + 6), Color(1, 1, 1), 2.0)
	timeline.draw_string(font, Vector2(0, y + h + 16), "démarrage", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.75, 1))
	timeline.draw_string(font, Vector2(can * sx + 3, y + h + 16), "annulable", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 1, 0.5))


func _refresh_info() -> void:
	var id := cur_move if cur_move != "" else last_move
	var m: MoveData = MoveLibrary.moves().get(id) if id != "" else null
	if m == null:
		info.text = "[i]Aucun coup joué.[/i]\nVitesse ×%s · mannequins : %s" % [str(SPEEDS[speed_i]), STATES.filter(func(s): return s[0] == dummy_state)[0][1].to_lower()]
		return
	var a: Dictionary = player.ATK.get(id, {})
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]  (%s)  —  res://moves/%s.tres" % [m.display_name, id, id])
	if a.get("end", 0.0) < 90.0:
		lines.append("Démarrage [b]%d[/b] im · annulable dès [b]%d[/b] · fin [b]%d[/b] im  (%d im de récupération)" % [
			_frames(a.active), _frames(a.cancel), _frames(a.end), _frames(a.end - a.active)])
	else:
		lines.append("Coup tenu (dure tant que la situation dure)")
	if m.tip != "":
		lines.append("Frappe : %s, rayon %.2f m · dégâts %d · force ×%.2f%s" % [m.tip, m.radius, roundi(m.damage), m.force_mult, " (lourd)" if m.heavy else ""])
		lines.append("Déséquilibre %.2f · vers le haut %.2f · %s%s" % [m.drop, m.up, ["devant", "sur le côté", "vers la droite"][m.side], " · brise-garde" if m.guard_break else ""])
		lines.append("Hitstop %.2f s · secousse %.2f · élan %.1f · pas %.1f" % [m.hitstop, m.shake, m.lunge, m.step])
	if m.flags.size() > 0:
		lines.append("Comportements : " + ", ".join(m.flags))
	if m.notes != "":
		lines.append("[i]%s[/i]" % m.notes)
	lines.append("t = %.3f · vitesse ×%s · vitesse d'attaque %.2f" % [cur_t, str(SPEEDS[speed_i]), player.attack_speed])
	info.text = "\n".join(lines)

class_name LabPanel
extends CanvasLayer
## Menu (Start / Tab) : options du labo (sbires, situation, ralenti, image par image, 2e joueur, modèle, ragdoll, caméra) et
## PANNEAU DE RÉGLAGE : vitesses, aimantation, élan, roulade, ragdoll… modifiés en direct (data/tuning.gd), gardés sur le
## disque, « Exporter » copie le texte des réglages pour le coller dans une note du carnet. Tout se pilote à la manette :
## haut / bas = choisir, gauche / droite = changer, A = valider, B ou Start = reprendre. Le menu est hors du temps du jeu.

signal closed

var main: Node
var panel: PanelContainer
var box: VBoxContainer
var rows := []
var sel := 0
var opts := []        # {title, kind: "choice"|"num"|"action"|"title", values, get, set, step, min, max}
var open := false
var _rep := 0.0
var page := 0
const PAGES := ["Labo", "Réglages : déplacement", "Réglages : combat", "Réglages : ennemis, ragdoll, caméra"]
var info: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.93)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	visible = false


func num(title: String, key: String, step: float, lo: float, hi: float) -> Dictionary:
	return {"title": title, "kind": "num", "read": func(): return Tuning.v(key), "write": func(v): Tuning.set_value(key, v), "step": step, "min": lo, "max": hi}


func _build() -> void:
	for c in box.get_children():
		c.queue_free()
	rows = []
	opts = []
	var t := Label.new()
	t.text = "PAUSE — %s   (L1 / R1 : page %d / %d)" % [PAGES[page], page + 1, PAGES.size()]
	t.add_theme_font_size_override("font_size", 26)
	box.add_child(t)
	match page:
		0: opts = main.lab_options()
		1: opts = [num("Course (m/s)", "run_speed", 0.1, 3, 10), num("Sprint (m/s)", "sprint_speed", 0.1, 4, 14), num("Marche (m/s)", "walk_speed", 0.1, 1, 5),
			num("Accélération", "accel", 5, 20, 200), num("Freinage", "decel", 5, 20, 200), num("Rotation (rad/s)", "turn_rate", 2, 6, 80),
			num("Sprint : stick à fond (s)", "sprint_hold", 0.05, 0.1, 1.0), num("Saut (m/s)", "jump_speed", 0.2, 4, 14),
			num("Gravité montée", "grav_up", 1, 8, 60), num("Gravité descente", "grav_down", 1, 8, 80), num("Double saut", "double_jump", 0.2, 3, 12),
			num("Roulade : images", "roll_frames", 1, 10, 40), num("Roulade : distance (m)", "roll_dist", 0.1, 1, 7),
			num("Roulade : invincible jusqu'à", "roll_inv_to", 1, 2, 30), num("Roulade : attaque dès", "roll_attack_from", 1, 1, 30),
			num("Roulade : délai avant la suivante", "roll_cooldown", 1, 0, 40), num("Dash aérien : images", "air_dash_frames", 1, 6, 30),
			num("Dash aérien : distance", "air_dash_dist", 0.1, 1, 7), num("Atterrissage : images", "land_frames", 1, 0, 20), num("Atterrissage lourd", "land_heavy_frames", 1, 0, 30)]
		2: opts = [num("Aide à la visée (0-1)", "assist", 0.05, 0, 1), num("Aide : portée (m)", "assist_range", 0.2, 1, 6), num("Aide : cône (°)", "assist_cone", 5, 20, 180),
			num("Élan des coups (×)", "lunge_scale", 0.05, 0, 3), num("Tampon d'entrées (images)", "buffer", 1, 1, 20),
			num("X maintenu → balayette (images)", "hold_sweep", 1, 4, 30), num("Y maintenu en l'air → plongeant", "hold_dive", 1, 4, 30),
			num("Charge mini (s)", "charge_min", 0.05, 0.1, 1), num("Charge maxi (s)", "charge_max", 0.1, 0.3, 3),
			num("Parade : fenêtre (images)", "parry_window", 1, 2, 20), num("Riposte : fenêtre (images)", "riposte_frames", 2, 10, 90),
			num("Parade : délai (images)", "parry_cooldown", 1, 0, 60), num("Esquive parfaite : fenêtre", "perfect_dodge_window", 1, 2, 20),
			num("Jongle : décroissance", "juggle_decay", 0.02, 0.5, 1), num("Jongle : gravité", "juggle_grav", 1, 8, 40),
			num("Figé à l'impact (×)", "hitstop_scale", 0.1, 0, 3), num("Secousse caméra (×)", "shake_scale", 0.1, 0, 3),
			num("Chope : portée", "grab_reach", 0.1, 0.8, 3), num("Chope : tenu maxi (images)", "grab_hold_max", 10, 60, 400),
			num("Chope : coups toutes les N images", "grab_pummel_every", 1, 6, 40), num("Chope : dégâts du slam", "grab_slam_dmg", 1, 4, 40)]
		3: opts = [num("Sbires : vie", "foe_hp", 10, 30, 400), num("Sbires : attaquants à la fois", "foe_attackers_max", 1, 1, 5),
			num("Sbires : distance de ronde", "foe_ring", 0.1, 1, 5), num("Sbires : vitesse", "foe_speed", 0.2, 1, 8),
			num("Au sol : images", "down_frames", 5, 10, 200), num("Relevé : images", "getup_frames", 5, 10, 200), num("Relevé rapide après N chutes", "quick_getup_after", 1, 1, 6),
			num("Ragdoll : poids (kg)", "rag_mass", 5, 20, 200), num("Ragdoll : gravité (×)", "rag_gravity", 0.1, 0.5, 5), num("Ragdoll : amortissement", "rag_damp", 0.5, 0, 12),
			num("Ragdoll : rebond", "rag_bounce", 0.02, 0, 0.8),
			num("Caméra : rotation (°)", "cam_yaw", 15, -180, 180), num("Caméra : inclinaison (°)", "cam_pitch", 1, 25, 65), num("Caméra : zoom", "cam_zoom", 0.05, 0.5, 2.0)]
	if page > 0:
		opts.append({"title": "Exporter les réglages (copie le texte)", "kind": "action", "do": func(): DisplayServer.clipboard_set(Tuning.export_text()); info.text = "Réglages copiés : colle-les dans une note du carnet."})
		opts.append({"title": "Remettre les valeurs de départ", "kind": "action", "do": func(): Tuning.reset(); main.apply_tuning(); _refresh()})
	for i in opts.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		box.add_child(l)
		rows.append(l)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 16)
	info.modulate = Color(0.8, 0.85, 0.9)
	info.text = "Haut / bas : choisir · gauche / droite : changer · A : valider · B ou Start : reprendre"
	box.add_child(info)
	sel = clampi(sel, 0, maxi(opts.size() - 1, 0))
	_refresh()


func _refresh() -> void:
	for i in opts.size():
		var o: Dictionary = opts[i]
		var val := ""
		match o.kind:
			"choice":
				val = "<  %s  >" % str(o.values[int(o.read.call())])
			"num":
				var v: float = o.read.call()
				val = "<  %s  >" % (str(int(round(v))) if o.step >= 1.0 else "%.2f" % v)
			"action":
				val = "[A]"
		rows[i].text = "%s %s   %s" % ["▶" if i == sel else " ", o.title, val]
		rows[i].modulate = Color(1, 0.9, 0.5) if i == sel else Color(0.9, 0.9, 0.95)


func toggle() -> void:
	open = not open
	visible = open
	get_tree().paused = open
	if open:
		_build()
	else:
		Tuning.save()
		main.apply_tuning()
		closed.emit()


func _change(d: int) -> void:
	if opts.is_empty():
		return
	var o: Dictionary = opts[sel]
	match o.kind:
		"choice":
			var n: int = o.values.size()
			o.write.call(posmod(int(o.read.call()) + d, n))
		"num":
			var v: float = o.read.call()
			v = clampf(snappedf(v + d * float(o.step), float(o.step)), float(o.min), float(o.max))
			o.write.call(v)
			main.apply_tuning()
		"action":
			o.do.call()
	_refresh()


func _input(e: InputEvent) -> void:
	if not open:
		return
	if e.is_action_pressed("ui_cancel") or (e is InputEventJoypadButton and e.pressed and e.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]) \
			or (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_TAB, KEY_ESCAPE]):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_A:
			_change(1)
		elif e.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			page = posmod(page + (1 if e.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1), PAGES.size())
			_build()
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_UP, KEY_W: _move(-1)
			KEY_DOWN, KEY_S: _move(1)
			KEY_LEFT, KEY_A: _change(-1)
			KEY_RIGHT, KEY_D, KEY_ENTER, KEY_SPACE, KEY_J: _change(1)
			KEY_Q, KEY_U: page = posmod(page - 1, PAGES.size()); _build()
			KEY_E, KEY_L: page = posmod(page + 1, PAGES.size()); _build()


func _move(d: int) -> void:
	if opts.is_empty():
		return
	sel = posmod(sel + d, opts.size())
	_refresh()


func _process(dt: float) -> void:
	if not open:
		return
	# stick / croix de la manette avec répétition
	var v := Vector2.ZERO
	for d in Input.get_connected_joypads():
		v = Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP): v.y = -1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN): v.y = 1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT): v.x = -1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT): v.x = 1
		break
	if v.length() < 0.5:
		_rep = 0.0
		return
	if _rep <= 0.0:
		if absf(v.y) > absf(v.x):
			_move(1 if v.y > 0 else -1)
		else:
			_change(1 if v.x > 0 else -1)
		_rep = 0.18
	_rep -= dt

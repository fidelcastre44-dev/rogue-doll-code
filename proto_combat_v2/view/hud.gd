class_name Hud
extends CanvasLayer
## Interface : barres de vie (joueurs en bas, sbires au-dessus de leur tête), version, aide « possible maintenant »
## (boutons utiles à cet instant, calculés avec les vraies règles), frise des images du coup en cours (F1 = débogage).

const VERSION := "0.2"
var world: SimWorld
var cam: Camera3D
var debug := false
var bars := {}            # id -> ProgressBar
var hint: Label
var dbg: Label
var top: Label
var actions: Label
var frames: Control
var frame_label: Label


func _ready() -> void:
	layer = 5
	top = _label(16, Color(0.9, 0.9, 0.95))
	top.position = Vector2(14, 10)
	top.text = "Rogue Doll — proto combat v2 · v%s · Start / Tab : menu et réglages · F1 : débogage · F2 : zones de frappe · F4 : modèle" % VERSION
	hint = _label(18, Color(1, 0.95, 0.7))
	hint.position = Vector2(14, 34)
	dbg = _label(15, Color(0.75, 0.9, 1.0))
	dbg.position = Vector2(14, 64)
	dbg.visible = false
	actions = _label(17, Color(0.85, 1.0, 0.85))
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.anchor_left = 1.0
	actions.anchor_top = 1.0
	actions.offset_left = -420
	actions.offset_top = -200
	actions.offset_right = -14
	actions.offset_bottom = -14
	actions.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	frame_label = _label(14, Color(1, 1, 1))
	frame_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	frame_label.anchor_top = 1.0
	frame_label.anchor_bottom = 1.0
	frame_label.offset_top = -70
	frame_label.offset_left = 14
	frame_label.offset_right = 700
	frame_label.offset_bottom = -50


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	add_child(l)
	return l


func _bar(col: Color, w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, 10)
	b.size = Vector2(w, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	add_child(b)
	return b


func _process(_dt: float) -> void:
	if not world:
		return
	var seen := {}
	var vp := get_viewport().get_visible_rect().size
	var pi := 0
	for fi in world.fighters:
		if not is_instance_valid(fi):
			continue
		seen[fi.id] = true
		if not bars.has(fi.id):
			bars[fi.id] = _bar(Color(0.3, 0.9, 0.4) if fi.team == 0 else Color(0.95, 0.35, 0.3), 260 if fi.team == 0 else 70)
		var b: ProgressBar = bars[fi.id]
		b.max_value = fi.hp_max
		b.value = fi.hp
		if fi.team == 0:
			b.position = Vector2(14 + pi * 290, vp.y - 36)
			b.visible = true
			pi += 1
		elif cam and cam.is_inside_tree():
			var wp := fi.global_position + Vector3.UP * 2.15
			b.visible = not cam.is_position_behind(wp) and cam.global_position.distance_to(wp) > 0.5
			b.position = cam.unproject_position(wp) - Vector2(35, 0)
	for id in bars.keys():
		if not seen.has(id):
			bars[id].queue_free()
			bars.erase(id)
	if world.players.size() > 0:
		var h: Fighter = world.players[0]
		_hint(h)
		_actions(h)
		dbg.visible = debug
		if debug:
			var lines := ["image %d · %s" % [world.frame, h.debug_line()]]
			lines.append("vitesse %.1f m/s · au sol %s · figé %d · ralenti %d · jongle %d" % [h.hvel.length(), h.grounded, h.freeze, h.slow, h.juggle])
			for d in world.foes:
				lines.append("sbire %d : %s" % [d.id, d.debug_line()])
			dbg.text = "\n".join(lines)
		_frames(h)


func _hint(h: Fighter) -> void:
	var t := ""
	var b: HeroBrain = h.brain
	if b.riposte_win > 0:
		t = "PARÉ ! X = riposte"
	elif b.pursuit_win > 0:
		t = "A = saut de poursuite"
	elif b.dodge_ok_win > 0:
		t = "coup qui arrive : B = esquive parfaite, L1 = parade"
	else:
		for d in world.foes:
			if d.state == "attack" and d.move_phase() == "startup" and not d.mv.is_empty():
				t = "rouge : bloquable (L1) · orange : esquiver (B) ou parer (L1 au bon moment)"
	hint.text = t


func _actions(h: Fighter) -> void:
	var l := []
	match h.state:
		"idle", "run", "sprint":
			l = ["X jab ▸ direct ▸ coude ▸ retourné (X maintenu : balayette)", "Y coup de pied poussé ▸ gros crochet (Y maintenu : chargé)",
				"après 2 X : Y = uppercut lanceur", "A saut · B roulade · L1 garde / parade · RB chope"]
			if h.state == "sprint":
				l = ["sprint + X : coup de pied glissé", "sprint + Y : gros coup de pied", "A saut · B roulade"]
		"roll": l = ["X direct plongeant", "Y glissade (envoie en l'air)"]
		"air": l = ["X jab ▸ pied latéral ▸ talon", "Y gros genou (maintenu : plongeant)", "A double saut · B dash aérien"]
		"attack":
			var ch: Dictionary = h.mv.get("chain", {})
			for k in ch:
				l.append("%s → %s" % ["X" if k == "attack" else "Y", ch[k]])
			if h.mv.get("jump_cancel", false):
				l.append("A (s'il touche) : saut")
		"hold": l = ["X coups · RB ou Y SLAM · B lâcher"]
		"guard", "parry": l = ["L1 maintenu : garde · relâcher pour sortir", "X après parade : riposte"]
	actions.text = "\n".join(l)


func _frames(h: Fighter) -> void:
	if not debug or h.state != "attack" or h.mv.is_empty():
		frame_label.text = ""
		return
	var m := h.mv
	var s := ""
	var total := Moves.total(m)
	for i in range(1, total + 1):
		var c := "·"
		if i <= int(m.startup):
			c = "a"
		elif i <= int(m.startup) + int(m.active):
			c = "█"
		else:
			c = "r"
		if i == h.f:
			c = "|"
		s += c
	frame_label.text = "%s  %s  (%d / %d / %d)" % [h.move_id, s, m.startup, m.active, m.recovery]

class_name Menu
extends CanvasLayer
## Menu pause (Start / Tab) : réglages du terrain d'essai, entièrement à la manette.
## Haut / bas = choisir ; gauche / droite ou A = changer ; B ou Start = reprendre.

var game: Node
var panel: PanelContainer
var box: VBoxContainer
var rows := []
var sel := 0
var opts := []     # [titre, valeurs (Array), index, callback]
var open := false
var _rep := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	visible = false


func setup(o: Array) -> void:
	opts = o
	for c in box.get_children():
		c.queue_free()
	rows = []
	var t := Label.new()
	t.text = "PAUSE — terrain d'essai"
	t.add_theme_font_size_override("font_size", 30)
	box.add_child(t)
	for i in opts.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 22)
		box.add_child(l)
		rows.append(l)
	var foot := Label.new()
	foot.text = "Haut/bas : choisir   ·   Gauche/droite ou A : changer   ·   B / Start : reprendre"
	foot.add_theme_font_size_override("font_size", 15)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(foot)
	_refresh()


func _refresh() -> void:
	for i in rows.size():
		var o: Array = opts[i]
		var v: Array = o[1]
		var txt: String = o[0]
		if v.size() > 0:
			txt += "  ◂ " + str(v[o[2]]) + " ▸"
		rows[i].text = ("▶ " if i == sel else "   ") + txt
		rows[i].add_theme_color_override("font_color", Color(1, 0.85, 0.4) if i == sel else Color(1, 1, 1, 0.9))
	panel.reset_size()
	panel.position = (panel.get_viewport_rect().size - panel.size) * 0.5


func toggle() -> void:
	open = not open
	visible = open
	game.get_tree().paused = open
	Inputs.pressed_at.clear()
	if open:
		_refresh()


func _change(d: int) -> void:
	var o: Array = opts[sel]
	var v: Array = o[1]
	if v.size() > 0:
		o[2] = posmod(o[2] + d, v.size())
	o[3].call(o[2])
	_refresh()


func _input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not open:
		return
	if e.is_action_pressed("ui_down", true):
		sel = (sel + 1) % opts.size()
		_refresh()
	elif e.is_action_pressed("ui_up", true):
		sel = posmod(sel - 1, opts.size())
		_refresh()
	elif e.is_action_pressed("ui_right", true):
		_change(1)
	elif e.is_action_pressed("ui_left", true):
		_change(-1)
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("jump"):
		_change(1)
	elif e.is_action_pressed("ui_cancel") or e.is_action_pressed("dodge"):
		toggle()
	else:
		return
	get_viewport().set_input_as_handled()

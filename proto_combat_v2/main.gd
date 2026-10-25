extends Node3D
## Point d'entrée : crée la simulation (SimWorld), l'affichage (GameView) et le menu (Panel). Gère les touches du labo
## (F1 débogage, F2 zones de frappe, F3 ralenti, F4 modèle du héros, F5 image par image, Start menu, Select = remise en place)
## et le 2e joueur local (Start sur la 2e manette, ou P au clavier).

var world: SimWorld
var view: GameView
var panel: LabPanel
var spot_i := 0
var mode_i := 0
var count_i := 1
var slow_i := 0
var model_i := 0
var p2 := false
const SPOTS := ["centre", "ligne", "foule", "mur", "vide"]
const MODES := ["passive", "guard", "attack"]
const MODE_NAMES := ["passifs", "en garde", "attaquants"]
const COUNTS := [0, 1, 2, 3, 5]
const SLOWS := [1.0, 0.5, 0.25]
const MODELS := ["male", "female"]


func _ready() -> void:
	world = SimWorld.new()
	add_child(world)
	view = GameView.new()
	add_child(view)
	view.setup(world)
	panel = LabPanel.new()
	panel.main = self
	add_child(panel)
	_load_prefs()
	var h := world.add_player(MODELS[model_i])
	world.load_spot("centre")
	view._sync_puppets()
	view.cam.snap()


func _load_prefs() -> void:
	if FileAccess.file_exists("user://proto.cfg"):
		var j = JSON.parse_string(FileAccess.get_file_as_string("user://proto.cfg"))
		if j is Dictionary:
			model_i = int(j.get("model", 0))
			view.set_ragdoll(bool(j.get("ragdoll", true)))


func _save_prefs() -> void:
	var f := FileAccess.open("user://proto.cfg", FileAccess.WRITE)
	f.store_string(JSON.stringify({"model": model_i, "ragdoll": view.ragdoll_on}))


func _process(_dt: float) -> void:
	Inputs.cam_yaw = view.cam.yaw_rad()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.physical_keycode:
			KEY_F1: view.hud.debug = not view.hud.debug
			KEY_F2: view.show_hitboxes = not view.show_hitboxes
			KEY_F3: slow_i = (slow_i + 1) % SLOWS.size(); world.slowmo = SLOWS[slow_i]
			KEY_F4: _next_model()
			KEY_F5: world.paused = true; world.step_once = true
			KEY_F6: world.paused = false
			KEY_P: _toggle_p2()
			KEY_TAB, KEY_ESCAPE:
				if not panel.open:
					panel.toggle()
			KEY_R: _reset()
	elif e is InputEventJoypadButton and e.pressed:
		if e.button_index == JOY_BUTTON_START and not panel.open:
			var pads := Input.get_connected_joypads()
			if pads.size() > 1 and e.device == pads[1] and not p2:
				_toggle_p2()
			else:
				panel.toggle()
		elif e.button_index == JOY_BUTTON_BACK:
			_reset()


func _reset() -> void:
	world.load_spot(SPOTS[spot_i], -1 if SPOTS[spot_i] != "centre" or count_i == 1 else -1)
	_apply_count()
	view.cam.snap()


func _apply_count() -> void:
	var n: int = COUNTS[count_i]
	if n != world.foes.size():
		world.load_spot(SPOTS[spot_i], n)


func _next_model() -> void:
	model_i = (model_i + 1) % MODELS.size()
	for h in world.players:
		h.model = MODELS[model_i] if h == world.players[0] else MODELS[(model_i + 1) % 2]
		view.rebuild_puppet(h)
	_save_prefs()


func _toggle_p2() -> void:
	if not p2:
		p2 = true
		var h2 := world.add_player(MODELS[(model_i + 1) % 2])
		world.reset_fighter(h2, world.players[0].global_position + Vector3(1.6, 0, 0), Vector3(0, 0, -1))
		view._sync_puppets()
		view.fx.popup(h2.global_position + Vector3.UP * 2.3, "JOUEUR 2", Color(0.7, 0.9, 1.0))
	else:
		p2 = false
		var h2: Fighter = world.players[1]
		world.players.erase(h2)
		world.fighters.erase(h2)
		h2.queue_free()
		view._sync_puppets()


func apply_tuning() -> void:
	view.cam.yaw = Tuning.v("cam_yaw")
	view.cam.pitch = Tuning.v("cam_pitch")
	view.cam.zoom = Tuning.v("cam_zoom")
	for d in world.foes:
		d.hp_max = Tuning.v("foe_hp")
		d.hp = minf(d.hp, d.hp_max)


## Options de la page « Labo » du menu.
func lab_options() -> Array:
	return [
		{"title": "Situation", "kind": "choice", "values": ["centre", "ligne de 3", "foule de 5", "contre le mur", "vide"],
			"read": func(): return spot_i, "write": func(v): spot_i = v; count_i = 1 if v != 0 else count_i; world.load_spot(SPOTS[spot_i]); view.cam.snap()},
		{"title": "Sbires", "kind": "choice", "values": MODE_NAMES, "read": func(): return mode_i, "write": func(v): mode_i = v; world.set_foe_mode(MODES[v])},
		{"title": "Nombre de sbires", "kind": "choice", "values": ["0", "1", "2", "3", "5"], "read": func(): return count_i,
			"write": func(v): count_i = v; world.load_spot(SPOTS[spot_i], COUNTS[v]); view.cam.snap()},
		{"title": "Ralenti du labo", "kind": "choice", "values": ["×1", "×0,5", "×0,25"], "read": func(): return slow_i, "write": func(v): slow_i = v; world.slowmo = SLOWS[v]},
		{"title": "Héros", "kind": "choice", "values": ["homme", "femme"], "read": func(): return model_i, "write": func(v): model_i = v - 1; _next_model()},
		{"title": "Ragdoll visuel", "kind": "choice", "values": ["non", "oui"], "read": func(): return 1 if view.ragdoll_on else 0,
			"write": func(v): view.set_ragdoll(v == 1); _save_prefs()},
		{"title": "Zones de frappe", "kind": "choice", "values": ["cachées", "visibles"], "read": func(): return 1 if view.show_hitboxes else 0, "write": func(v): view.show_hitboxes = v == 1},
		{"title": "Débogage (F1)", "kind": "choice", "values": ["non", "oui"], "read": func(): return 1 if view.hud.debug else 0, "write": func(v): view.hud.debug = v == 1},
		{"title": "Deuxième joueur (manette 2)", "kind": "choice", "values": ["non", "oui"], "read": func(): return 1 if p2 else 0, "write": func(v): if (v == 1) != p2: _toggle_p2()},
		{"title": "Remettre en place (Select)", "kind": "action", "do": func(): _reset()},
	]

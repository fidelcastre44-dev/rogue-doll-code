extends Node3D
## Rogue Doll — proto combat. Une version à part, juste le terrain d'essai, pour trouver un déplacement / combat solide.
## Ce nœud monte tout (lumière, terrain, héros, mannequins, caméra, effets, sons, interface, menu) et sert d'arbitre :
## figé à l'impact, secousses, ralentis, parade, esquive parfaite, jetons d'attaque des ennemis (2 à la fois au plus).

const VERSION := "0.11"
const MAX_ATTACKERS := 2

var arena: Arena
var hero: Hero
var enemies: Array = []
var cam: Cam
var fx: Fx
var sfx: Sfx
var hud: Hud
var menu: Menu
var spot := "centre"
var foe_mode := "passive"
var foe_count := 3
var speed := 1.0
var show_boxes := false
var tokens: Array = []
var _slow_t := 0.0
var _slow_scale := 1.0
var _boxes := []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.4, 0.47)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.36, 0.4, 0.47)
	env.fog_density = 0.006
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 35, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var game_root := Node3D.new()     # tout ce qui se fige quand le menu met en pause
	game_root.name = "World"
	game_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game_root)
	arena = Arena.new()
	game_root.add_child(arena)
	fx = Fx.new()
	game_root.add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	hero = Hero.new()
	hero.game = self
	var c := ConfigFile.new()
	if c.load("user://proto.cfg") == OK:
		hero.look = c.get_value("hero", "look", "male")
		hero.assist = c.get_value("hero", "assist", 0.65)
	game_root.add_child(hero)
	hero.hit_landed.connect(_on_hero_hit)
	cam = Cam.new()
	cam.game = self
	cam.target = hero
	add_child(cam)
	cam.current = true
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	Inputs.pressed.connect(hud.push_input)
	menu = Menu.new()
	menu.game = self
	add_child(menu)
	_menu_setup()
	load_spot(spot)
	cam.snap()


func _menu_setup() -> void:
	menu.setup([
		["Reprendre", [], 0, func(_i): menu.toggle()],
		["Situation", ["centre", "mur", "plateforme", "ligne", "foule"], 0, func(i): load_spot(["centre", "mur", "plateforme", "ligne", "foule"][i])],
		["Mannequins", ["passifs", "en garde", "attaquent"], 0, func(i): set_foe_mode(["passive", "guard", "attack"][i])],
		["Nombre de mannequins", [1, 2, 3, 4, 5, 6], 2, func(i): set_count(i + 1)],
		["Vitesse du jeu", ["×1", "×0,5", "×0,25"], 0, func(i): set_speed([1.0, 0.5, 0.25][i])],
		["Aide à la visée", ["aucune", "légère", "normale", "forte"], 2, func(i): set_assist([0.0, 0.35, 0.65, 1.0][i])],
		["Zoom caméra", ["proche", "normal", "loin"], 1, func(i): cam.zoom = [0.75, 1.0, 1.3][i]],
		["Zones de frappe", ["cachées", "visibles"], 0, func(i): show_boxes = i == 1],
		["Perso", ["homme", "femme"], 0 if hero.look == "male" else 1, func(i): set_look(["male", "female"][i])],
		["Infos des coups (frise)", ["visibles", "cachées"], 0, func(i): hud.show_debug = i == 0],
		["Aide « possible maintenant »", ["visible", "cachée"], 0, func(i): hud.show_actions = i == 0],
		["Ragdoll visuel", ["oui", "non"], 0, func(i): set_ragdoll(i == 0)],
		["Quitter le jeu", [], 0, func(_i): get_tree().quit()],
	])
	# aide à la visée : refléter la valeur sauvegardée
	var a := [0.0, 0.35, 0.65, 1.0]
	var best := 2
	for i in a.size():
		if absf(a[i] - hero.assist) < 0.05:
			best = i
	menu.opts[5][2] = best


func mode_name() -> String:
	return {"passive": "passifs", "guard": "en garde", "attack": "attaquent"}[foe_mode]


func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("hero", "look", hero.look)
	c.set_value("hero", "assist", hero.assist)
	c.save("user://proto.cfg")


func set_look(l: String) -> void:
	hero.set_look(l)
	_save()


func set_assist(a: float) -> void:
	hero.assist = a
	_save()


var ragdoll_on := true
func set_ragdoll(on: bool) -> void:
	ragdoll_on = on
	for e in enemies:
		e.ragdoll_on = on
		if not on:
			e.rag.stop()


func set_speed(s: float) -> void:
	speed = s
	Engine.time_scale = s


func set_count(n: int) -> void:
	foe_count = n
	load_spot(spot)


func set_foe_mode(m: String) -> void:
	foe_mode = m
	for e in enemies:
		e.set_mode(m)


func load_spot(name: String) -> void:
	spot = name
	var s: Dictionary = arena.spots[name]
	for e in enemies:
		e.queue_free()
	enemies = []
	tokens = []
	var foes: Array = s.foes
	var n := foe_count if name != "ligne" and name != "foule" else maxi(foe_count, foes.size())
	for i in mini(n, foes.size() + 3):
		var d := Dummy.new()
		d.game = self
		d.mode = foe_mode
		d.ragdoll_on = ragdoll_on
		var p: Vector3 = foes[i] if i < foes.size() else foes[0] + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		d.position = p + Vector3.UP * 0.05
		get_node("World").add_child(d)
		var to: Vector3 = s.hero - p
		to.y = 0
		d.reset_at(p + Vector3.UP * 0.05, to.normalized())
		enemies.append(d)
	hero.global_position = s.hero + Vector3.UP * 0.05
	hero.velocity = Vector3.ZERO
	hero.hvel = Vector3.ZERO
	hero.facing = s.face
	hero.state = "move"
	hero.f = 0
	hero.hp = 100.0
	if cam:
		cam.snap()


func respawn_hero() -> void:
	load_spot(spot)


func cam_forward() -> Vector3:
	return cam.flat_forward()


func cam_right() -> Vector3:
	return cam.flat_right()


# ------------------------------------------------------------------ boucle

func _process(dt: float) -> void:
	# ralenti temporaire (temps réel)
	if _slow_t > 0.0:
		_slow_t -= dt / maxf(Engine.time_scale, 0.01)
		if _slow_t <= 0.0:
			Engine.time_scale = speed
	if get_tree().paused:
		return
	if Inputs.buffered("reset"):
		load_spot(spot)
	if Inputs.buffered("hitboxes"):
		show_boxes = not show_boxes
	if Inputs.buffered("debug"):
		hud.show_help = not hud.show_help
	if Inputs.buffered("slowmo"):
		set_speed(1.0 if speed < 1.0 else 0.25)
	if Inputs.buffered("look"):
		set_look("female" if hero.look == "male" else "male")
	for b in _boxes:
		b.queue_free()
	_boxes = []


func _physics_process(_dt: float) -> void:
	if get_tree().paused:
		return
	# le héros ne traverse pas les mannequins (sauf en roulade) : poussée douce
	if hero.state != "dodge":
		for e in enemies:
			var d: Vector3 = hero.global_position - e.global_position
			d.y = 0
			var l := d.length()
			var minl := 0.62
			if e.state in ["down", "air", "grabbed", "splat"]:
				continue
			if l < minl and l > 0.001 and absf(hero.global_position.y - e.global_position.y) < 1.4:
				hero.global_position += d / l * (minl - l) * 0.6
				e.global_position -= d / l * (minl - l) * 0.4


# ------------------------------------------------------------------ arbitrage du combat

func shake(a: float) -> void:
	cam.add_trauma(a)


func popup(at: Vector3, text: String, col := Color.WHITE) -> void:
	fx.popup(at, text, col)


func slowmo(dur: float, scale := 0.25) -> void:
	_slow_t = maxf(_slow_t, dur)
	Engine.time_scale = minf(speed, scale * speed)


## Un coup du héros (ou d'un projeté) a touché : étincelles, son, secousse, chiffres.
func hit_fx(target: Node, attacker: Node, m: Dictionary, res: String) -> void:
	var at: Vector3 = target.global_position + Vector3.UP * 1.25
	var dir: Vector3 = (target.global_position - attacker.global_position)
	dir.y = 0.3
	dir = dir.normalized()
	var power := clampf(float(m.get("dmg", 5)) / 14.0, 0.3, 1.6)
	match res:
		"block":
			fx.spark(at, dir, 0.4, Color(0.5, 0.75, 1.0))
			sfx.play("block", at, 0.7)
			cam.add_trauma(0.08)
		"break":
			fx.spark(at, dir, 1.2, Color(1, 0.8, 0.3))
			fx.shockwave(at, 1.4, -dir)
			cam.add_trauma(0.45)
		_:
			var col := Color(1, 0.9, 0.55)
			if m.get("crit", false) or res == "counter":
				col = Color(1, 0.55, 0.25)
			fx.spark(at, dir, power, col)
			sfx.play(m.get("sfx", "light"), at, 0.6 + power * 0.25)
			cam.add_trauma(float(m.get("shake", 0.15)))
			if power > 0.8:
				cam.punch(power * 0.6)
			if power > 1.05:
				fx.shockwave(target.global_position + Vector3.UP * 0.05, 1.2 + power)
			fx.popup(at + Vector3.UP * 0.6, str(int(m.get("dmg", 0))), Color(1, 1, 1) if res == "hit" else col)
			if res == "counter":
				fx.popup(at + Vector3.UP * 1.0, "CONTRE !", Color(1, 0.6, 0.2))
			if m.get("crit", false):
				fx.popup(at + Vector3.UP * 1.0, "CRITIQUE !", Color(1, 0.8, 0.2))
			if m.get("slowmo", 0.0) > 0.0:
				slowmo(float(m.slowmo), 0.3)


func _on_hero_hit(_target, _id, _res) -> void:
	pass


func debug_box(c: Vector3, r: float) -> void:
	if not show_boxes:
		return
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.2, 0.2, 0.35)
	mat.no_depth_test = true
	m.material_override = mat
	add_child(m)
	m.global_position = c
	_boxes.append(m)


## Un coup ennemi va-t-il toucher le héros dans les `win` secondes qui viennent ? (esquive parfaite)
func enemy_threat(h: Node, win: float) -> bool:
	for e in enemies:
		var tf: int = e.threat_frames()
		if tf < 0 or tf > int(win * 60.0):
			continue
		var d: Vector3 = h.global_position - e.global_position
		if Vector2(d.x, d.z).length() < e.threat_reach():
			return true
	return false


func perfect_dodge(h: Node) -> void:
	slowmo(0.45, 0.3)
	fx.popup(h.global_position + Vector3.UP * 2.2, "ESQUIVE PARFAITE", Color(0.5, 0.9, 1.0))
	sfx.play("perfect", h.global_position, 0.6)
	h.rig.flash(0.2, Color(0.5, 0.9, 1.0))


func parry(h: Node, attacker: Node) -> void:
	attacker.parried()
	slowmo(0.35, 0.2)
	cam.add_trauma(0.3)
	cam.punch(0.8)
	var at: Vector3 = (h.global_position + attacker.global_position) * 0.5 + Vector3.UP * 1.3
	fx.spark(at, Vector3.UP, 1.4, Color(0.6, 0.85, 1.0))
	fx.shockwave(at, 1.6, (attacker.global_position - h.global_position).normalized())
	fx.popup(at + Vector3.UP * 0.8, "PARADE !", Color(0.6, 0.9, 1.0))
	sfx.play("parry", at, 0.9, 0.02)
	h.hitstop = 10
	h.rig.freeze(0.16)


func enemy_hit_result(e: Node, res: String, heavy: bool) -> void:
	var at: Vector3 = hero.global_position + Vector3.UP * 1.2
	match res:
		"hit":
			fx.spark(at, (hero.global_position - e.global_position).normalized(), 0.8 if heavy else 0.5, Color(1, 0.35, 0.3))
			sfx.play("heavy" if heavy else "light", at, 0.7)
			cam.add_trauma(0.35 if heavy else 0.2)
		"block":
			fx.spark(at, Vector3.UP, 0.4, Color(0.5, 0.75, 1.0))
			cam.add_trauma(0.1)
		"armor":
			sfx.play("block", at, 0.5)


func take_token(e: Node) -> bool:
	if e in tokens:
		return true
	if tokens.size() >= MAX_ATTACKERS:
		return false
	tokens.append(e)
	return true


func give_token(e: Node) -> void:
	tokens.erase(e)

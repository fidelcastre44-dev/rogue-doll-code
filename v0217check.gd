extends SceneTree
## Auto-test de la v0.217 (bilans de Thibaud du 23/10 au soir) : godot --headless --path . -s v0217check.gd --fixed-fps 120
## Plaqué du super saut (4 poings puis sbire sonné 2 s), tacle glissé non annulable, plus de chope en l'air / au sol (sauf
## grand tour), shoot de foot « boule de bowling », zone de frappe des coups de jambe, grand tour plus vif.

var lab
var p
var fails := []
var m := {}


func _initialize() -> void:
	lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
	_run()


func ok(c: bool, msg: String) -> void:
	print(("  [ok] " if c else "  [ECHEC] ") + msg)
	if not c:
		fails.append(msg)


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func tap(a: String, n := 2) -> void:
	Input.action_press(a)
	await wait(n)
	Input.action_release(a)


func hold(acts: Array) -> void:
	for a in ["up", "down", "left", "right"]:
		Input.action_release(a)
	for a in acts:
		Input.action_press(a)


func release_all() -> void:
	for a in ["light", "heavy", "grab", "jump", "roll", "up", "down", "left", "right", "guard", "special"]:
		Input.action_release(a)


func go(id: String, var_i := 0) -> void:
	release_all()
	for i in LaboCatalog.MOVES.size():
		if LaboCatalog.MOVES[i].id == id:
			var mv: Dictionary = LaboCatalog.MOVES[i]
			if mv.has("variants"):
				lab.variant[id] = mv.variants[1][var_i][0]
			lab.select(i)
	lab.set_menu(false)
	await wait(30)


func _run() -> void:
	await wait(5)
	p = lab.player

	print("Super saut : 4 poings au plus, puis le sbire reste sonné")
	await go("mseed52")
	Input.action_press("jump")
	await wait(70)
	Input.action_release("jump")
	await tap("grab")
	m = {"pin": false, "victim": null, "freed": -1}
	for i in 400:
		await physics_frame
		if p.attack in ["sj_pin", "pin_punch"]:
			if not m.pin:
				m.pin = true
				m.victim = p.pin_victim
			if i % 6 == 0:
				Input.action_press("light")
			else:
				Input.action_release("light")
		elif m.pin and m.freed < 0:
			m.freed = i
			m.t = m.victim.timer if m.victim else 0.0
			m.st = m.victim.state if m.victim else ""
	Input.action_release("light")
	ok(m.pin, "chope plongeante : plaqué au sol")
	ok(p.pin_hits <= p.PIN_MAX and p.pin_hits >= 3, "poings limités (%d sur %d au plus)" % [p.pin_hits, p.PIN_MAX])
	ok(m.freed > 0, "puis le héros se libère")
	ok(m.get("st", "") in ["down", "dead"] and m.get("t", 0.0) >= 1.5, "le sbire reste sonné au sol (%s, %.1f s)" % [m.get("st", ""), m.get("t", 0.0)])

	print("Tacle glissé : rien ne le coupe")
	await go("mseed04", 0)
	var e = lab.main.enemies[0]
	hold(["up"])
	await wait(2)
	p.sprinting = true
	await wait(20)
	await tap("light")
	await wait(12)
	await tap("jump")
	await tap("heavy")
	await wait(4)
	ok(p.roll >= 0.0 and p.roll_kind == "slide", "saut / coup pendant le tacle : il continue (%s, %.2f s)" % [p.roll_kind, p.roll])
	hold([])

	print("Chopes : plus en l'air ni sur un sbire couché (sauf grand tour)")
	await go("mseed09", 0)
	p.throw_move = "slam"
	await wait(60)
	await tap("grab")
	await wait(20)
	ok(p.attack != "collar", "sbire couché, chope de base : il ne l'attrape plus (%s)" % p.attack)
	await go("mseed09", 0)
	await wait(60)
	Input.action_press("grab")
	await wait(30)
	ok(p.attack == "swing", "avec le grand tour, il l'attrape par les pieds (%s)" % p.attack)
	Input.action_release("grab")
	await wait(80)
	await go("mseed02", 0)
	await wait(50)
	await tap("grab")
	await wait(20)
	ok(p.attack != "collar", "sbire en l'air, depuis le sol : pas de chope (%s)" % p.attack)

	print("Shoot de foot : boule de bowling")
	await go("mseed29")
	await wait(80)
	e = lab.main.enemies[0]
	var b0: int = e.bowl_lands
	var start_p: Vector3 = e.parts.pelvis.global_position
	await tap("heavy")
	await wait(150)
	var dist: float = ((e.parts.pelvis.global_position - start_p) * Vector3(1, 0, 1)).length()
	ok(e.bowl_lands > b0, "il retombe lourdement (réception de boule de bowling)")
	ok(dist < 7.0, "projeté moins loin (%.1f m)" % dist)

	print("Coups de jambe : toute la jambe frappe")
	await go("pantin")
	e = lab.main.enemies[0]
	var hp0: float = e.hp
	var dummy_c: Vector3 = e.parts.chest.global_position
	p.global_position = Vector3(dummy_c.x, 0, dummy_c.z) + Vector3(0.55, 0, 0.55)
	p.rotation.y = atan2(-(dummy_c - p.global_position).x, -(dummy_c - p.global_position).z)
	await wait(2)
	m = {"hit": false}
	await tap("heavy")
	for i in 60:
		await physics_frame
		if p.connected:
			m.hit = true
	ok(m.hit, "chassé collé au pantin : la jambe le touche quand même")

	print("Grand tour plus vif")
	ok(p.SWING_BASE >= 9.0 and p.SWING_TURN >= 15.0, "rotation plus rapide")

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

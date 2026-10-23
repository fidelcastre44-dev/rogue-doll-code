extends SceneTree
## Auto-test des correctifs de la version 0.11 (retours de Paul du 22/10) : godot --headless --path . -s correctcheck.gd --fixed-fps 120
## Coups supprimés (rafale, moulinet, poing marteau), drop kick et superman punitifs (rien ne les annule), plaquage couché sur le sbire,
## projection de hanche par-dessus, prise de catch à l'horizontale, combo aérien = combo du sol, coup lourd chargé, esquives aériennes,
## contre tournant x3, triple balayage mobile, super saut -> chope plongeante, course au mur horizontale, micro-animations au repos.

var lab
var p
var fails := []
var trace := []        # coups successifs du héros (chaque changement)
var dashes := 0        # esquives aériennes commencées
var m := {}            # mesures prises pendant une attente (les lambdas ne modifient pas les variables locales)
var _was_dash := false
var _prev_roll := -1.0
var _last := ""


func _initialize() -> void:
	lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
	physics_frame.connect(_on_frame)
	_run()


func _on_frame() -> void:
	if p == null:
		return
	if p.attack != _last:
		_last = p.attack
		if p.attack != "":
			trace.append(p.attack)
	var d: bool = p.roll >= 0 and p.roll_kind == "dash" and not p.is_on_floor()
	if d and (not _was_dash or p.roll < _prev_roll):
		dashes += 1   # une nouvelle esquive (même enchaînée sans temps mort)
	_was_dash = d
	_prev_roll = p.roll


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


func go(id: String, vars := {}) -> void:
	for a in ["light", "heavy", "grab", "jump", "roll", "up", "down", "left", "right", "guard"]:
		Input.action_release(a)
	for i in LaboCatalog.MOVES.size():
		if LaboCatalog.MOVES[i].id == id:
			lab.select(i)
	for k in vars:
		lab.variant[id] = vars[k]
		p.set(k, vars[k])
	lab.set_menu(false)
	await wait(30)


## Attend en notant les coups vus, jusqu'à n images.
func watch(n: int, seen: Dictionary, f := Callable()) -> void:
	for i in n:
		await physics_frame
		if p.attack != "":
			seen[p.attack] = seen.get(p.attack, 0) + 1
		if f.is_valid():
			f.call()


func _run() -> void:
	await wait(5)
	p = lab.player
	var e
	var seen := {}

	print("Coups supprimés")
	await go("mseed00")
	seen = {}
	for i in 6:
		Input.action_press("light")
		await wait(3)
		Input.action_release("light")
		await wait(3)
	await watch(60, seen)
	ok(not seen.has("rush") and not seen.has("rush_end"), "X martelé : plus de rafale de poings (%s)" % str(seen.keys()))
	await go("mseed29")
	seen = {}
	for i in 5:
		await tap("heavy", 3)
		await wait(4)
	await watch(60, seen)
	ok(not seen.has("leg_mill"), "Y martelé : plus de moulinet de jambes")
	await go("mseed29")
	await wait(60)
	seen = {}
	await tap("light")
	await watch(60, seen)
	ok(not seen.has("hammer_fist") and seen.has("jab"), "X devant un sbire couché : un jab, plus de poing marteau (%s)" % str(seen.keys()))
	for id in ["mseed17", "mseed20", "mseed31"]:
		ok(LaboCatalog.find(id).is_empty(), "%s n'est plus dans le labo" % id)

	print("Drop kick : il reste au sol, rien ne l'annule")
	await go("mseed24")
	Input.action_press("up")
	await wait(2)
	p.sprinting = true
	await wait(10)
	await tap("heavy")
	await wait(28)
	Input.action_release("up")
	var landed := -1
	var lie := 0
	for i in 400:
		await physics_frame
		if p.attack == "drop_land":
			if landed < 0:
				landed = i
			lie += 1
			if i % 9 == 0:
				for a in ["roll", "jump", "light", "heavy", "grab", "guard"]:
					Input.action_press(a)
			else:
				for a in ["roll", "jump", "light", "heavy", "grab", "guard"]:
					Input.action_release(a)
		elif landed >= 0:
			break
	for a in ["roll", "jump", "light", "heavy", "grab", "guard"]:
		Input.action_release(a)
	ok(landed >= 0, "il retombe sur le dos")
	ok(lie / 120.0 >= 1.4, "au sol %.2f s malgré les boutons martelés (1,4 s au moins)" % (lie / 120.0))

	print("Superman punch : à plat ventre après le coup")
	await go("mseed58")
	seen = {}
	Input.action_press("light")
	Input.action_press("heavy")
	await wait(2)
	Input.action_release("light")
	Input.action_release("heavy")
	m = {"prone": false}
	await watch(200, seen, func():
		if p.attack == "sm_land" and p.t > 0.2 and p.j.spine.global_basis.y.y < 0.3:
			m.prone = true)
	ok(seen.has("superman") and seen.has("sm_land"), "superman puis réception (%s)" % str(seen.keys()))
	ok(m.prone, "il est couché à plat ventre")

	print("Plaquage : le héros plonge et reste couché sur le sbire")
	await go("mseed32")
	Input.action_press("up")
	await wait(2)
	p.sprinting = true
	await wait(78)
	await tap("grab")
	m = {"flat": false, "near": 9.0}
	await watch(150, seen, func():
		if p.attack == "tackle_slam" and p.t > 0.2 and p.t < 0.45:
			if p.j.spine.global_basis.y.y < 0.4 and p.j.head.global_position.y < 0.6:
				m.flat = true
			var ee = lab.main.enemies[0]
			m.near = minf(m.near, (ee.parts.chest.global_position - p.j.spine.global_position).length()))
	Input.action_release("up")
	ok(m.flat, "le héros est couché au sol (pas debout)")
	ok(m.near < 0.85, "sur le sbire (%.2f m)" % m.near)

	print("Projection de hanche : par-dessus le héros")
	await go("mseed39")
	e = lab.main.enemies[0]
	var start_side: float = (e.parts.chest.global_position - p.global_position).dot(-p.global_basis.z)
	var f0: Vector3 = -p.global_basis.z
	var o0: Vector3 = p.global_position
	m = {"top": 0.0}
	await tap("grab")
	await watch(70, seen, func():
		if p.attack == "hip_throw" and not p.hit_done:
			m.top = maxf(m.top, e.parts.pelvis.global_position.y))
	var end_side: float = (e.parts.pelvis.global_position - o0).dot(f0)
	ok(start_side > 0.3 and end_side < -0.3, "il passe de l'autre côté (%.2f -> %.2f m)" % [start_side, end_side])
	ok(m.top > 1.7, "en passant au-dessus du héros (bassin à %.2f m)" % m.top)

	print("Prise de catch : tous deux à l'horizontale, dans les deux sens")
	await go("mseed53")
	e = lab.main.enemies[0]
	await wait(10)
	await tap("jump")
	m = {"both": false}
	await watch(160, seen, func():
		if p.attack == "piledriver" and p.t > 0.62 and e.state == "held":
			var hero_axis: Vector3 = p.j.spine.global_basis.y
			var foe_axis: Vector3 = (e.parts.head.global_position - e.parts.pelvis.global_position).normalized()
			if absf(hero_axis.y) < 0.45 and absf(foe_axis.y) < 0.45 and hero_axis.dot(foe_axis) < -0.5:
				m.both = true)
	ok(m.both, "héros et sbire couchés en l'air, têtes à l'opposé")
	ok(seen.has("pd_land"), "puis écrasés au sol")

	print("Combo aérien = combo du sol")
	await go("mseed02", {"light_move": "hook"})
	await wait(40)
	seen = {}
	trace.clear()
	await tap("jump")
	for i in 5:
		await wait(10)
		await tap("light")
	await wait(60)
	var order := trace.filter(func(x): return x in ["air", "air_cross", "air_hook", "air_upper", "air_knee"])
	ok(order == ["air", "air_cross", "air_hook"], "jab, direct, crochet en l'air (%s)" % str(order))

	print("Coup lourd chargé : la version chargée du coup lourd en place")
	await go("mseed07", {"charge_move": "power"})
	p.heavy_move = "hikick"
	seen = {}
	m = {"mult": 0.0}
	Input.action_press("heavy")
	await watch(150, seen, func():
		if p.attack == "hikick":
			m.mult = maxf(m.mult, p.hit_mult))
	Input.action_release("heavy")
	await watch(30, seen)
	ok(seen.has("hikick") and not seen.has("kick"), "Y maintenu avec le high kick : high kick chargé (%s)" % str(seen.keys()))
	ok(m.mult > 1.9, "chargé au max : ×%.2f" % m.mult)

	print("Esquives aériennes : 1, puis 3 avec l'amélioration")
	for n in [1, 3]:
		await go("mseed46", {"air_dodges": n})
		await tap("jump")
		dashes = 0
		for i in 4:
			await wait(16)
			await tap("roll")
		await wait(60)
		ok(dashes == n, "%d esquive(s) en l'air permise(s) (vu %d)" % [n, dashes])

	print("Contre tournant : 3 tours avec l'amélioration")
	await go("mseed16", {"counter_triple": true})
	await tap("roll")
	await wait(64)
	await tap("light")
	m = {"turned": 0.0, "yaw": p.rotation.y}
	await watch(120, seen, func():
		if p.attack == "spin_counter3":
			m.turned += absf(angle_difference(m.yaw, p.rotation.y))
		m.yaw = p.rotation.y)
	ok(m.turned > TAU * 2.7, "il fait 3 tours (%.1f tours)" % (m.turned / TAU))

	print("Triple balayage : on se déplace pendant qu'il tourne")
	await go("mseed03", {"sweep_triple": true})
	var p0: Vector3 = p.global_position
	Input.action_press("light")
	await wait(30)
	Input.action_press("right")
	await wait(70)
	Input.action_release("right")
	Input.action_release("light")
	var moved: float = (p.global_position - p0).length()
	ok(moved > 2.0, "il avance au stick pendant les 3 tours (%.2f m)" % moved)

	print("Super saut puis R1 : chope plongeante sur le sbire")
	await go("mseed52")
	seen = {}
	Input.action_press("jump")
	await wait(60)
	Input.action_release("jump")
	await tap("grab")
	await watch(150, seen)
	ok(seen.has("sj_grab"), "il plonge depuis le super saut (%s)" % str(seen.keys()))
	ok(seen.has("air_slam") or seen.has("airslam_land"), "il attrape un sbire et le plaque au sol")

	print("Course au mur horizontale")
	lab.variant["mseed27"] = "wall_side"   # une seule carte depuis la v0.212 : situation « le long du mur »
	await go("mseed27")
	seen = {}
	m = {"hy": 0.0}
	Input.action_press("up")
	await wait(3)
	await tap("heavy")
	await watch(100, seen, func():
		if p.attack == "wall_run_h" and p.t < 0.5:
			m.hy = maxf(m.hy, p.global_position.y))
	Input.action_release("up")
	ok(seen.has("wall_run_h"), "elle part (stick le long du mur + Y)")
	ok(m.hy > 0.5, "il court sur le mur, au-dessus du sol (%.2f m)" % m.hy)
	ok(lab.main.enemies[0].state != "stand" or lab.main.enemies[0].hp < lab.main.enemies[0].MAX_HP, "il fauche le sbire sur sa route")

	print("Micro-animations au repos")
	await go("mseed12")
	var a: Quaternion = p.j.spine.quaternion
	var h: float = p.j.hips.position.y
	var moved_q := 0.0
	var moved_h := 0.0
	for i in 120:
		await physics_frame
		moved_q = maxf(moved_q, a.angle_to(p.j.spine.quaternion))
		moved_h = maxf(moved_h, absf(p.j.hips.position.y - h))
	ok(moved_q > deg_to_rad(2.0) and moved_h > 0.01, "immobile, il respire et sautille (buste %.1f°, bassin %.3f m)" % [rad_to_deg(moved_q), moved_h])

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

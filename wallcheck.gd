extends SceneTree
## Auto-test de la course au mur (v0.23) : godot --headless --path . -s wallcheck.gd --fixed-fps 120
## Couloir (sauter à côté d'un mur = course horizontale, A = saut vers l'autre mur, recourir dessus), zigzag jusqu'à
## l'arrivée, course vers le haut (se hisser en haut du mur de 4 m, salto arrière sur la tour), attaque de sortie (X / Y),
## coups aériens retrouvés sur le mur, Y à côté d'un mur ne lance plus de coup, la run classique n'a pas de course au mur.

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


func release_all() -> void:
	for a in ["light", "heavy", "grab", "jump", "roll", "up", "down", "left", "right", "guard", "sprint"]:
		Input.action_release(a)


func go(id: String) -> void:
	release_all()
	for i in LaboCatalog.MOVES.size():
		if LaboCatalog.MOVES[i].id == id:
			lab.select(i)
	lab.set_menu(false)
	p.lc.stats.clear()
	await wait(40)


func hold(dirs: Array) -> void:
	for a in ["up", "down", "left", "right"]:
		if a in dirs:
			Input.action_press(a)
		else:
			Input.action_release(a)


## Attend que le héros soit dans cet état de déplacement (au plus n images). Vrai s'il y est.
func until_state(st: String, n := 150) -> bool:
	for i in n:
		if p.lc.state == st:
			return true
		await physics_frame
	return p.lc.state == st


func watch(n: int, f: Callable) -> void:
	for i in n:
		await physics_frame
		f.call()


func _run() -> void:
	await wait(10)
	p = lab.player
	var map: TestMap = lab.map
	var diag := TestMap.DIAG

	print("Couloir : sauter à côté du mur = course horizontale")
	await go("mseed27")
	var o0: Vector3 = p.global_position
	hold(["up"])
	await wait(4)
	await tap("jump")
	await until_state("wallrun")
	m = {"run": false, "hy": 0.0, "far": 0.0, "states": {}}
	await watch(72, func():
		m.states[p.lc.state] = true
		if p.lc.state == "wallrun":
			m.run = true
			m.hy = maxf(m.hy, p.global_position.y)
			m.far = maxf(m.far, (p.global_position - o0).dot(diag)))
	ok(m.run, "il court sur le mur (états vus : %s)" % str(m.states.keys()))
	ok(m.hy > 1.0, "au-dessus du sol (%.2f m)" % m.hy)
	ok(p.lc.state == "wallrun" and m.far > 4.0, "toujours sur le mur après 0,6 s, %.1f m parcourus" % m.far)
	var feet: Vector3 = (p.j.foot_l.global_position + p.j.foot_r.global_position) * 0.5
	var head: Vector3 = p.j.head.global_position
	ok((feet - head).dot(-p.lc.wall_n) > 0.4, "couché sur le côté : les pieds vers le mur, la tête vers la salle (%.2f)" % (feet - head).dot(-p.lc.wall_n))
	ok(p.air_hits == 0 and not p.air_heavy_used and p.air_jumps == 0, "sur le mur, ses coups aériens et son double saut sont remis à zéro")
	var n0: Vector3 = p.lc.wall_n
	await tap("jump")
	m = {"other": false, "air": false}
	await watch(110, func():
		if p.lc.state == "" and not p.is_on_floor():
			m.air = true
		if p.lc.state == "wallrun" and p.lc.wall_n.dot(n0) < -0.8:
			m.other = true)
	ok(p.lc.stats.get("wall_jump", 0) >= 1 and m.air, "A : il saute du mur")
	ok(m.other, "et recourt sur l'autre mur du couloir")
	await go("mseed27")
	hold(["up"])
	await wait(4)
	await tap("jump")
	await until_state("wallrun")
	await wait(20)
	await tap("jump")
	await until_state("wallrun")
	await wait(10)
	await tap("jump")
	await wait(20)
	ok(p.lc.stats.get("wall_jump", 0) >= 2, "et peut ressauter (%d sauts de mur)" % p.lc.stats.get("wall_jump", 0))
	hold([])
	await wait(480)
	ok(p.lc.state == "" and p.is_on_floor(), "il finit par retomber au sol")

	print("Couloir : B = lâcher")
	await go("mseed27")
	hold(["up"])
	await wait(4)
	await tap("jump")
	await until_state("wallrun")
	await wait(10)
	var was: String = p.lc.state
	await tap("roll")
	await wait(3)
	ok(was == "wallrun" and p.lc.state == "", "B sur le mur : il lâche (%s -> %s)" % [was, p.lc.state])
	hold([])

	print("Couloir : la course est longue mais finie")
	await go("mseed27")
	hold(["up"])
	await wait(4)
	await tap("jump")
	m = {"t": 0}
	await watch(500, func():
		if p.lc.state == "wallrun":
			m.t += 1)
	hold([])
	ok(m.t > 80, "il court un bon moment (%.2f s)" % (m.t / 120.0))
	ok(p.lc.state != "wallrun", "puis il s'arrête (bout du mur ou durée max)")

	print("Zigzag : d'un mur à l'autre jusqu'à l'arrivée")
	await go("mv_wallzig")
	hold(["up"])
	await wait(4)
	await tap("jump")
	m = {"walls": {}, "low": 9.0, "zig": false}
	await until_state("wallrun")
	for step in 6:
		await watch(30, func():
			if p.lc.state == "wallrun":
				m.walls[str(snappedf(p.lc.edge.dot(diag), 4.0))] = true
				m.zig = true
			if m.zig and p.lc.state != "climb" and p.lc.state != "mantle":
				m.low = minf(m.low, p.global_position.y))
		if p.lc.state == "wallrun":
			await tap("jump")
	await wait(150)
	hold([])
	var o2 := Vector3(29, 0, 8)
	var ap: float = (p.global_position - o2).dot(diag)
	print("    murs touchés : %s, plus bas : %.2f m, arrivée : %.2f m (a = %.1f)" % [str(m.walls.keys()), m.low, p.global_position.y, ap])
	ok(p.lc.stats.get("wallrun", 0) >= 3, "trois courses au mur enchaînées (%d)" % p.lc.stats.get("wallrun", 0))
	ok(absf(p.global_position.y - 2.0) < 0.2 and ap > 11.5, "il arrive sur la plateforme (%.2f m)" % p.global_position.y)

	print("Mur de 4 m : face au mur = il court vers le haut et se hisse")
	await go("mv_wallclimb")
	hold(["up"])
	await wait(10)
	await tap("jump")
	m = {"climb": false, "hy": 0.0}
	await watch(160, func():
		if p.lc.state == "wallclimb":
			m.climb = true
			m.hy = maxf(m.hy, p.global_position.y))
	hold([])
	await wait(40)
	ok(m.climb, "il court vers le haut")
	ok(p.lc.stats.get("wall_top", 0) >= 1 and absf(p.global_position.y - 4.0) < 0.2 and p.lc.state == "", "arrivé au bord, il se hisse en haut (%.2f m)" % p.global_position.y)

	print("Tour de 8 m : A sur le mur = salto arrière, puis coup aérien")
	await go("mv_walltower")
	hold(["up"])
	await wait(10)
	await tap("jump")
	await until_state("wallclimb")
	await wait(20)
	hold([])
	was = p.lc.state
	var hy: float = p.global_position.y
	await tap("jump")
	m = {"flip": false, "hy": 0.0}
	await watch(12, func():
		if p.attack == "flip_jump":
			m.flip = true
		m.hy = maxf(m.hy, p.global_position.y))
	ok(was == "wallclimb", "il court sur la tour (%s, %.2f m)" % [was, hy])
	ok(p.lc.stats.get("wall_flip", 0) == 1 and m.flip, "A : salto arrière")
	var fw: Vector3 = -p.global_basis.z
	ok(fw.dot(-diag) > 0.7, "il se retourne vers la salle")
	await tap("light")
	m = {"air": false}
	await watch(30, func():
		if p.attack == "air":
			m.air = true)
	ok(m.air, "X juste après le salto : coup aérien")
	await wait(200)

	print("Tour de 8 m : sans salto, il glisse et lâche")
	await go("mv_walltower")
	hold(["up"])
	await wait(10)
	await tap("jump")
	await wait(20)
	hold([])
	m = {"climb": 0}
	await watch(260, func():
		if p.lc.state == "wallclimb":
			m.climb += 1)
	ok(m.climb > 0 and p.lc.stats.get("wall_top", 0) == 0 and p.global_position.y < 0.3, "pas assez haut pour le bord : il retombe (%.2f m)" % p.global_position.y)

	print("Attaque de sortie : X sur le mur = bondit sur le sbire le plus proche")
	await go("mv_wallattack")
	var e0 = lab.main.enemies[0]
	hold(["up"])
	await wait(4)
	await tap("jump")
	await until_state("wallrun")
	await wait(4)
	hold([])
	ok(p.lc.state == "wallrun", "il court sur le mur")
	await tap("light")
	m = {"leap": false, "air": false, "tgt": null, "hit": false}
	await watch(80, func():
		if p.lc.state == "wall_leap":
			m.leap = true
			m.tgt = p.lc.wa_target
		if p.attack == "air":
			m.air = true
			m.hit = m.hit or p.connected)
	ok(m.leap and m.tgt == e0, "il bondit vers le sbire le plus proche")
	ok(m.air, "et lance le poing aérien en arrivant")
	ok(m.hit, "le poing touche le sbire")
	await wait(150)

	print("Attaque de sortie : Y = gros genou")
	await go("mv_wallattack")
	hold(["up"])
	await wait(4)
	await tap("jump")
	await until_state("wallrun")
	await wait(4)
	hold([])
	await tap("heavy")
	m = {"knee": false}
	await watch(80, func():
		if p.attack == "air_bigknee":
			m.knee = true)
	ok(m.knee and p.lc.stats.get("wall_attack", 0) == 1, "Y sur le mur : il bondit et donne le gros genou")
	await wait(150)

	print("Y à côté d'un mur : plus de coup « course au mur »")
	await go("mseed27")
	hold(["up", "left"])
	await wait(20)
	hold(["up"])
	await tap("heavy")
	m = {"wr": false}
	await watch(60, func():
		if p.attack in ["wall_run", "wall_run_h"]:
			m.wr = true)
	hold([])
	ok(not m.wr, "Y ne lance plus la course au mur (c'est un déplacement, sur A)")

	print("Bloc de 3 m : on s'y agrippe toujours (pas assez haut pour courir dessus)")
	await go("mv_hang")
	hold(["up", "left"])
	await wait(26)
	await tap("jump")
	m = {"hang": false, "wc": false}
	await watch(70, func():
		if p.lc.state == "hang":
			m.hang = true
		if p.lc.state in ["wallclimb", "wallrun"]:
			m.wc = true)
	hold([])
	ok(m.hang and not m.wc, "il s'agrippe au rebord")

	print("Run classique : pas de course au mur")
	p.terrain = false
	ok(not p.lc.try_wall(diag), "hors du Terrain d'essai, try_wall ne fait rien")
	p.terrain = true

	release_all()
	print("RESULTAT: " + ("OK" if fails.is_empty() else "ECHEC (%d) : %s" % [fails.size(), str(fails)]))
	quit()

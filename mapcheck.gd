extends SceneTree
## Auto-test de la carte de test et des déplacements (v0.212) : godot --headless --path . -s mapcheck.gd --fixed-fps 120
## Glissade (escalier, rampe), marche automatique, enjambée (muret, rambarde), se hisser, rebord, glissade sous la barrière,
## réception roulée / atterrissage lourd, bonus de chute, rebond mural, sbire poussé du bord (dégâts de chute), sbires sur l'escalier.

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


## Directions au stick (la caméra regarde en diagonale) : haut = nord-est, droite = sud-est, bas = sud-ouest, gauche = nord-ouest.
func hold(dirs: Array) -> void:
	for a in ["up", "down", "left", "right"]:
		if a in dirs:
			Input.action_press(a)
		else:
			Input.action_release(a)


func watch(n: int, f: Callable) -> void:
	for i in n:
		await physics_frame
		f.call()


func _run() -> void:
	await wait(10)
	p = lab.player
	var map: TestMap = lab.map
	print("Carte")
	for k in ["stairs_top", "ramp_top", "ledge", "muret", "rambarde", "low_bar", "block1", "block2", "step04", "wall_front", "wall_side", "corner", "table", "pillars"]:
		ok(map.anchors.has(k), "point « %s »" % k)
	ok(map.breakables.size() >= 2, "tables cassables (%d)" % map.breakables.size())
	ok(map.props.size() >= 6, "objets à ramasser (%d)" % map.props.size())

	print("Glissade dans l'escalier")
	await go("mv_glide")
	var e0 = lab.main.enemies[0]
	ok(absf(p.global_position.y - 2.0) < 0.15, "en haut de l'escalier (%.2f m)" % p.global_position.y)
	hold(["down", "right"])
	await wait(24)
	Input.action_press("roll")
	m = {"glide": false, "miny": 9.0}
	await watch(150, func():
		if p.lc.state == "glide":
			m.glide = true
		m.miny = minf(m.miny, p.global_position.y))
	Input.action_release("roll")
	hold([])
	ok(m.glide, "B maintenu en descendant : glissade")
	ok(m.miny < 0.3, "il descend jusqu'en bas (%.2f m)" % m.miny)
	ok(e0.state != "stand", "le sbire sur sa route est fauché (%s)" % e0.state)
	await wait(30)
	ok(p.lc.state == "", "B relâché : il se relève")

	print("Glissade prolongée (rampe)")
	await go("mv_slope")
	var z0: float = p.global_position.z
	hold(["down", "right"])
	await wait(6)
	p.sprinting = true
	await wait(10)
	Input.action_press("roll")
	m = {"long": false}
	await watch(200, func():
		if p.lc.state == "glide" and p.lc.glide_long:
			m.long = true)
	Input.action_release("roll")
	hold([])
	ok(m.long, "sprint + B : glissade prolongée")
	ok(p.global_position.z - z0 > 9.0, "jusqu'au pied de la rampe et au-delà (%.1f m)" % (p.global_position.z - z0))

	print("Marche automatique")
	await go("mv_step")
	hold(["up", "left"])
	await wait(90)
	hold([])
	ok(p.global_position.y > 0.35, "monté sur le bloc de 0,4 m sans sauter (%.2f m)" % p.global_position.y)
	ok(p.lc.stats.get("step", 0) >= 1, "marche franchie")

	print("Enjamber")
	await go("mv_vault")
	var f0: Vector3 = lab.map.anchors.muret.f
	var o0: Vector3 = lab.map.anchors.muret.at
	hold(["up"])
	await wait(8)
	p.sprinting = true
	m = {"v": false}
	await watch(110, func():
		if p.lc.state == "vault":
			m.v = true)
	hold([])
	ok(m.v, "en sprint contre le muret : il l'enjambe tout seul")
	ok((p.global_position - o0).dot(f0) > 3.6, "il est passé de l'autre côté (%.1f m)" % (p.global_position - o0).dot(f0))
	await go("mv_rail")
	f0 = lab.map.anchors.rambarde.f
	o0 = lab.map.anchors.rambarde.at
	hold(["up"])
	await wait(44)
	hold([])
	await wait(4)
	await tap("jump")
	await wait(70)
	ok(p.lc.stats.get("vault", 0) >= 1, "A tout près de la rambarde : il l'enjambe (%.2f m de la rambarde)" % (3.0 - (p.global_position - o0).dot(f0)))
	ok((p.global_position - o0).dot(f0) > 3.4, "de l'autre côté")

	print("Se hisser")
	await go("mv_mantle")
	hold(["up", "left"])
	await wait(60)
	hold([])
	await tap("jump")
	await wait(70)
	ok(p.lc.stats.get("mantle", 0) >= 1 and absf(p.global_position.y - 1.0) < 0.15, "bloc de 1 m : A = il se hisse dessus (%.2f m)" % p.global_position.y)

	print("Rebord (bloc de 2 m)")
	await go("mv_hang")
	hold(["up"])
	await wait(26)
	await tap("jump")
	m = {"hang": false}
	await watch(70, func():
		if p.lc.state == "hang":
			m.hang = true)
	await wait(30)
	ok(p.lc.state == "hang", "stick toujours poussé vers le mur : il reste suspendu (il faut le relâcher puis repousser, ou A)")
	hold([])
	ok(m.hang and p.lc.state == "hang", "sauté contre le bloc : il s'agrippe au rebord (%s)" % p.lc.state)
	await wait(30)
	ok(p.lc.state == "hang", "il reste suspendu")
	await tap("jump")
	await wait(90)
	ok(p.lc.state == "" and absf(p.global_position.y - 2.0) < 0.15, "A : il se hisse sur le bloc (%.2f m)" % p.global_position.y)

	print("Glisser sous la barrière")
	await go("mv_skid")
	f0 = lab.map.anchors.low_bar.f
	o0 = lab.map.anchors.low_bar.at
	hold(["up"])
	await wait(10)
	p.sprinting = true
	await wait(20)
	await tap("roll")
	m = {"skid": false}
	await watch(120, func():
		if p.lc.state == "skid":
			m.skid = true)
	hold([])
	ok(m.skid, "sprint + B devant la barrière : glissade basse")
	ok((p.global_position - o0).dot(f0) > 5.0, "il est passé dessous (%.1f m)" % (p.global_position - o0).dot(f0))
	await wait(40)
	ok(p.lc.state == "", "puis il se relève")

	print("Grande chute")
	await go("mv_landroll")
	hold(["down", "right"])
	await wait(20)
	await tap("jump")
	m = {"rolled": false}
	for i in 120:
		await physics_frame
		if p.velocity.y < -6.0 and not m.get("b", false):
			var g: float = lab.map.ground_y(p.global_position)
			if p.global_position.y - g < 1.0:
				m.b = true
				Input.action_press("roll")
		if p.lc.stats.get("land_roll", 0) > 0:
			m.rolled = true
	Input.action_release("roll")
	hold([])
	ok(m.rolled, "B juste avant de toucher le sol : réception roulée")
	await go("mv_landroll")
	hold(["down", "right"])
	await wait(20)
	await tap("jump")
	m = {"heavy": false}
	await watch(120, func():
		if p.lc.state == "heavy_land":
			m.heavy = true)
	hold([])
	ok(m.heavy, "sans B : atterrissage lourd")
	await wait(60)
	ok(p.lc.state == "", "puis il reprend la main")

	print("Bonus de chute")
	await go("mv_fallhit")
	hold(["down", "right"])
	await wait(30)
	await tap("jump")
	m = {"fb": 1.0}
	await watch(130, func(): m.fb = maxf(m.fb, p.lc.fall_bonus()))
	hold([])
	ok(m.fb > 1.4, "en tombant de la plateforme, ses coups aériens frappent plus fort (×%.2f)" % m.fb)

	print("Rebond mural")
	await go("mseed47")
	var fw: Vector3 = lab.map.anchors.wall_front.f
	hold(["up"])
	await wait(2)
	await tap("roll")
	await wait(30)
	hold([])
	ok(p.lc.stats.get("wall_bounce", 0) >= 1, "esquive contre le mur : il rebondit (%s, %s, %s)" % [p.lc.stats, p.lc.bounced, p.global_position])
	ok(p.roll_dir.dot(fw) < -0.3 or p.velocity.dot(fw) < 0.0, "et repart dans l'autre sens")

	print("Sbires et décor")
	await go("mv_push")
	var e = lab.main.enemies[0]
	var hp0: float = e.hp
	await tap("heavy")
	m = {"miny": 9.0}
	await watch(240, func():
		if e.parts.has("pelvis"):
			m.miny = minf(m.miny, e.parts.pelvis.global_position.y))
	ok(m.miny < 0.6, "poussé du bord : il tombe de la plateforme (%.2f m)" % m.miny)
	ok(e.fall_hurt_last > 0.0, "et prend des dégâts de chute (%.1f)" % e.fall_hurt_last)
	await go("mv_climbers")
	lab.main.enemies[0].ai_on = true
	m = {"close": false}
	await watch(900, func():
		for x in lab.main.enemies:
			if x.state == "stand" and x.root.origin.y < 0.3 and (x.root.origin - p.global_position).length() < 2.6:
				m.close = true)
	ok(m.close, "les sbires du haut descendent l'escalier jusqu'au héros")
	var st = lab.main.enemies[0]
	st.ai_on = false
	await go("mv_mantle")
	var en = lab.main.enemies[0]
	en.root.origin = Vector3(7, 0, -13.2)
	en.target = p
	for i in 60:
		en._walk(Vector3(0, 0, -0.05))
		await physics_frame
	ok(en.root.origin.z > -16.05, "un sbire ne traverse pas un bloc de 1 m (%.2f)" % en.root.origin.z)
	ok(absf(en.root.origin.x - 7.0) > 0.4 or en.detour != 0.0, "il le contourne")

	print("Plaquage selon ce qu'on percute")
	await go("mv_tackle_table")
	var tb: int = lab.map.breakables.filter(func(b): return is_instance_valid(b)).size()
	e = lab.main.enemies[0]
	hp0 = e.hp
	hold(["up"])
	await wait(4)
	p.sprinting = true
	await wait(6)
	await tap("grab")
	await wait(150)
	hold([])
	ok(lab.map.breakables.filter(func(b): return is_instance_valid(b) and not b.get_meta("broken", false)).size() < tb, "plaqué sur la table : elle vole en éclats")
	ok(p.last_tackle_dmg > 30.0, "gros dégâts (%.0f)" % p.last_tackle_dmg)
	p.last_tackle_dmg = 0.0
	await go("mv_tackle_wall")
	e = lab.main.enemies[0]
	hp0 = e.hp
	hold(["up"])
	await wait(4)
	p.sprinting = true
	await wait(6)
	await tap("grab")
	m = {"wall": false}
	await watch(150, func():
		if p.tackle_into == "wall":
			m.wall = true)
	hold([])
	ok(m.wall, "emporté dans le mur : écrasé contre lui")
	ok(p.last_tackle_dmg > 30.0, "le dos casse : gros dégâts (%.0f)" % p.last_tackle_dmg)

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

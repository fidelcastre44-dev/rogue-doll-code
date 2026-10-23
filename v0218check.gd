extends SceneTree
## Auto-test de la v0.218 (bilans de Thibaud du 23/10, nuit) : godot --headless --path . -s v0218check.gd --fixed-fps 120
## Sbire coincé dans le décor (plus de plantage), relevé vulnérable, uppercut qui fait tomber, combo Y en 3 coups, chocs du
## sbire lancé, rebord (cheville puis se hisser, repousser sans faire tomber), objets lourds, réaction au coup, recovery, genou aérien.

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


func place(e, at: Vector3) -> void:
	var d: Vector3 = at - e.parts.pelvis.global_position
	for b in e.parts.values():
		b.global_position += d


func _run() -> void:
	await wait(5)
	p = lab.player

	print("1. Sbire coincé dans un bloc, un mur, une table : il se relève à côté (plus de positions infinies)")
	await go("mv_tackle_wall")
	var e = lab.main.enemies[0]
	e.ai_on = false
	for spot in [Vector3(14, 1.0, -12), Vector3(17, 1.0, 0) - TestMap.SIDE * 6.0, lab.map.breakables[0].global_position + Vector3.UP * 0.5]:
		e.toss(Vector3.ZERO, 0.0)
		place(e, spot)
		m = {"bad": false, "stood": false}
		for i in 700:
			await physics_frame
			if not e.root.origin.is_finite() or not e.parts.pelvis.global_position.is_finite():
				m.bad = true
				break
			if e.state == "stand":
				m.stood = true
				break
		ok(not m.bad and m.stood, "coincé en %s : relevé à côté (%s, %s)" % [str(spot), e.state, str(e.root.origin)])

	print("2. Relevé : plus d'immunité")
	await go("mseed05", 0)
	e = lab.main.enemies[0]
	e.ai_on = false
	e.toss(Vector3.UP * 2.0, 0.0)
	m = {"rise": false}
	for i in 600:
		await physics_frame
		if e.state in ["rise", "getup"]:
			m.rise = true
			break
	var hp0: float = e.hp
	e.hit(e.parts.chest, Vector3(0, 0, -60), e.parts.chest.global_position, 5.0, 0.5)
	ok(m.rise and e.hp < hp0, "touché pendant qu'il se relève : le coup compte (%.0f -> %.0f, %s)" % [hp0, e.hp, e.state])

	print("3. Uppercut de fin de combo : il tombe (ne retombe plus sur ses pieds)")
	await go("mseed05", 0)
	e = lab.main.enemies[0]
	e.ai_on = false
	m = {"landed": false, "down": false}
	for k in 4:
		await tap("light")
		await wait(26)
	for i in 300:
		await physics_frame
		if e.ai == "landed" or (e.state == "getup" and e.blend_kind == "land"):
			m.landed = true
		if e.state == "down" and e.height_above(e.parts.pelvis.global_position) < 0.4:
			m.down = true
	ok(m.down and not m.landed, "après l'uppercut : couché au sol (au sol : %s, sur ses pieds : %s)" % [m.down, m.landed])
	ok(is_equal_approx(p.FINISH_RECOVER, 0.17), "récupération de fin de combo un peu plus courte (%.2f s)" % p.FINISH_RECOVER)

	print("4. Combo Y : chassé, chassé de l'autre jambe, retourné qui projette")
	await go("mseed05", 0)
	e = lab.main.enemies[0]
	e.ai_on = false
	var seen := []
	m = {"launched": false}
	for k in 3:
		await tap("heavy")
		for i in 50:
			await physics_frame
			if p.attack != "" and not p.attack in seen:
				seen.append(p.attack)
			if p.attack == "kick3" and e.state in ["launch", "down"]:
				m.launched = true
	ok(seen == ["kick", "kick2", "kick3"], "Y, Y, Y : %s" % str(seen))
	ok(p.ATK.kick2.tip == "foot_l", "le 2e coup part de l'autre jambe")
	ok(m.launched, "le 3e coup le projette (%s)" % e.state)

	print("5. Sbire lancé par une chope : il se fait mal en percutant mur, objet, sbire")
	await go("mv_tackle_wall")
	e = lab.main.enemies[0]
	e.ai_on = false
	e.toss(Vector3.ZERO, 0.0)
	await wait(2)
	place(e, Vector3(17, 1.2, 0) - TestMap.SIDE * 6.0 - TestMap.DIAG * 3.0)
	hp0 = e.hp
	e.throw_body(TestMap.DIAG * 14.0 + Vector3.UP * 2.0, 0.0)
	await wait(90)
	ok(e.impact_count >= 1, "contre le mur : choc (%d)" % e.impact_count)
	await go("pantin")
	lab.set_extra(2, "stand")
	await wait(30)
	var es: Array = lab.main.enemies
	var a = es[0]
	var b = es[1]
	for x in es:
		x.ai_on = false
	a.toss(Vector3.ZERO, 0.0)
	await wait(2)
	var to: Vector3 = (b.root.origin - a.root.origin) * Vector3(1, 0, 1)
	place(a, b.root.origin - to.normalized() * 2.5 + Vector3.UP * 1.0)
	a.swing_release(Vector3.ZERO, Vector3.ZERO, 0.0)
	for bb in a.parts.values():
		bb.linear_velocity = to.normalized() * 12.0 + Vector3.UP * 1.0
	await wait(60)
	ok(b.react_t >= 0.0 or b.state != "stand", "contre un autre sbire : il le percute (%s)" % b.state)
	ok(a.impact_count >= 1, "et prend le choc lui aussi (%d)" % a.impact_count)

	print("6. Rebord : cheville tirée puis il se hisse ; X repousse sans faire tomber")
	await go("mv_hang")
	hold(["up", "left"])
	await wait(26)
	await tap("jump")
	await wait(70)
	hold([])
	await wait(20)
	var foe = lab.main.enemies[0]
	await tap("grab")
	await wait(160)
	ok(p.lc.stats.get("yank_climb", 0) >= 1 and absf(p.global_position.y - 3.0) < 0.2, "il fait tomber le sbire et se hisse dans la foulée (%.2f m)" % p.global_position.y)
	ok(foe.parts.pelvis.global_position.y < 2.2, "le sbire est tombé (%.2f m)" % foe.parts.pelvis.global_position.y)
	await go("mv_hang")
	hold(["up", "left"])
	await wait(26)
	await tap("jump")
	await wait(70)
	hold([])
	await wait(20)
	foe = lab.main.enemies[0]
	await tap("light")
	m = {"fell": false}
	for i in 100:
		await physics_frame
		if foe.state != "stand":
			m.fell = true
	ok(p.lc.stats.get("climb_push", 0) >= 1 and not m.fell, "X : le sbire est repoussé mais reste debout (%s)" % foe.state)

	print("7. Objets lourds, corps plus lourds, réaction au coup")
	await go("mv_tackle_table")
	var t: RigidBody3D = lab.map.breakables[0]
	ok(t.mass >= 80.0 and t.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM and t.center_of_mass.y < 0.3, "table : %.0f kg, centre de gravité bas" % t.mass)
	await go("mseed05", 0)
	e = lab.main.enemies[0]
	e.ai_on = false
	var c0: Basis = e.parts.chest.global_basis
	e.hit(e.parts.chest, Vector3(0, 0, -30).rotated(Vector3.UP, e.root.basis.get_euler().y), e.parts.chest.global_position, 1.0, 0.1)
	await wait(8)
	ok(e.state == "stand" and e.react_t > 0.0 and e.parts.chest.global_basis.z.angle_to(c0.z) > deg_to_rad(6), "touché debout : il réagit (buste %.0f°)" % rad_to_deg(e.parts.chest.global_basis.z.angle_to(c0.z)))
	e.toss(Vector3.UP, 0.0)
	ok(is_equal_approx(e.parts.chest.gravity_scale, e.RAG_GRAV) and e.parts.chest.angular_damp > 0.5, "ragdoll plus lourd (gravité ×%.1f)" % e.parts.chest.gravity_scale)

	print("8. Genou aérien : zone vers le haut, moins d'élan")
	ok(is_equal_approx(p.ATK.air_bigknee.lunge, 1.0), "élan à l'impact réduit (%.1f)" % p.ATK.air_bigknee.lunge)
	await go("mseed06", 0)
	await wait(40)
	m = {"hit": false}
	Input.action_press("jump")
	await wait(10)
	Input.action_release("jump")
	await wait(14)
	await tap("heavy")
	for i in 60:
		await physics_frame
		if p.attack == "air_bigknee" and p.connected:
			m.hit = true
	ok(m.hit, "il touche le sbire en l'air")

	release_all()
	print("RESULTAT: " + ("OK" if fails.is_empty() else "ECHEC (%d)" % fails.size()))
	quit()

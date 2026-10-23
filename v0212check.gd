extends SceneTree
## Auto-test de la v0.212 (hors carte) : godot --headless --path . -s v0212check.gd --fixed-fps 120
## Vanilla sans formes, règle « pas de forme concurrente », améliorations de bouton (impact, triple, renvoi, défense, Tazer, zone),
## état Électrifié, projectiles (parade, renvoi), désarmer, la vague, toile d'araignée, pas de côté, tomoe nage, pluie d'objets,
## objet-bouclier retiré.

const Upgrades = preload("res://upgrades.gd")

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


func watch(n: int, f: Callable) -> void:
	for i in n:
		await physics_frame
		f.call()


## Attend qu'un projectile arrive à moins de d m du héros (ou la fin du temps).
func wait_proj(d: float, n := 400) -> Node3D:
	for i in n:
		await physics_frame
		for pr in get_nodes_in_group("projectiles"):
			if pr.visible and not pr.from_hero and pr.global_position.distance_to(p.global_position + Vector3.UP * 1.1) < d:
				return pr
	return null


func _run() -> void:
	await wait(5)
	p = lab.player

	print("Vanilla et formes")
	await go("build_vanilla")
	ok(not p.form_dropkick and not p.form_counter and not p.double_jump and not p.dive and p.air_heavy == "knee", "Vanilla : aucune forme, ni double saut ni plongeon")
	ok(p.terrain and p.sidestep, "les déplacements de la carte et le pas de côté sont là")
	lab.main.enemies[0].global_position = Vector3(30, 0, 30)
	lab.main.enemies[0].build()
	Input.action_press("up")
	await wait(4)
	p.sprinting = true
	await wait(10)
	await tap("heavy")
	await wait(4)
	Input.action_release("up")
	ok(p.attack != "drop_kick", "Vanilla : Y en sprint n'est pas un drop kick (%s)" % p.attack)
	await go("build_t1")
	ok(p.form_dropkick and p.double_jump and p.light_move == "knee" and p.btn_ups.get("impact", []) == ["X"], "Palier 1 : drop kick, double saut, genou volant, impact sur X")
	var h = load("res://player.gd").new()
	Upgrades.reset(h)
	ok(not h.web and h.form_dropkick and h.btn_ups.is_empty(), "run classique : départ inchangé (formes déjà là)")
	Upgrades.apply(h, Upgrades.find("hikick"))
	ok(not Upgrades.available(h, Upgrades.find("spinkick")) and not Upgrades.available(h, Upgrades.find("axe")), "forme choisie : plus de forme concurrente proposée pour ce coup")
	ok(Upgrades.available(h, Upgrades.find("shoryu")), "les autres boutons restent proposés")
	var b1 := Upgrades.apply(h, Upgrades.find("impact"))
	ok(b1 in ["X", "Y"] and h.btn_ups.impact.size() == 1, "un loot d'amélioration de bouton n'en améliore qu'un (%s)" % b1)
	ok(Upgrades.available(h, Upgrades.find("impact")), "l'autre bouton reste à prendre")
	Upgrades.apply(h, Upgrades.find("impact"))
	ok(not Upgrades.available(h, Upgrades.find("impact")), "les deux pris : plus proposé")
	ok(not Upgrades.available(h, Upgrades.find("zone")), "électrification de zone : demande le Tazer")
	Upgrades.apply(h, Upgrades.find("tazer"))
	ok(Upgrades.available(h, Upgrades.find("zone")), "avec le Tazer, elle est proposée")
	ok(Upgrades.find("sweep_triple").is_empty() and Upgrades.find("counter_triple").is_empty() and not Upgrades.find("triple").is_empty(), "Triple Tour remplace les anciens « 3 tours »")
	Upgrades.apply(h, Upgrades.find("triple"))
	ok(h.sweep_triple and h.counter_triple, "Triple Tour sur X : balayage et contre tournant à 3 tours")
	h.free()

	print("Augmentation d'impact")
	await go("m_mvkrbq6hzzt8p", 0)
	await tap("light")
	await wait(3)
	ok(absf(p.ups.radius_mult() - 1.35) < 0.01 and p.ups.dmg_mult() > 1.2, "sur X : zone ×1,35, dégâts ×1,3 pendant le jab")
	await go("m_mvkrbq6hzzt8p", 1)
	await tap("light")
	await wait(3)
	ok(absf(p.ups.radius_mult() - 1.0) < 0.01, "sur Y : le jab n'est pas amélioré")

	print("Tazer et électrification")
	await go("m_mvkrtc8p0ifde", 0)
	var e = lab.main.enemies[0]
	await tap("light")
	m = {"elec": false, "down": false}
	await watch(60, func():
		if e.has_status("elec"):
			m.elec = true
		if e.state == "down":
			m.down = true)
	ok(m.elec and m.down, "Tazer sur X : le jab électrifie, il convulse et tombe")
	await wait(320)
	ok(not e.has_status("elec"), "puis l'effet s'arrête")
	await go("m_mvkrwm3a2kdow")
	m = {"n": 0}
	await tap("light")
	await watch(120, func():
		var n := 0
		for x in lab.main.enemies:
			if x.has_status("elec"):
				n += 1
		m.n = maxi(m.n, n))
	ok(m.n >= 2, "électrification de zone : les sbires autour sont électrifiés aussi (%d)" % m.n)

	print("Projectiles")
	await go("mseed43")
	var pr = await wait_proj(1.9)
	ok(pr != null, "le tireur lance une boule")
	Input.action_press("guard")
	await wait(30)
	Input.action_release("guard")
	ok(pr and pr.result in ["reflect", "enemy"], "parade pile au bon moment : renvoyée (%s)" % (pr.result if pr else "?"))
	await wait(40)
	ok(lab.main.enemies[0].state != "stand", "elle frappe le tireur")
	await go("mseed43")
	Input.action_press("guard")
	pr = await wait_proj(0.9)
	await wait(10)
	Input.action_release("guard")
	ok(pr and pr.result == "absorb", "garde levée trop tôt : seulement parée (%s)" % (pr.result if pr else "?"))
	await go("m_mvks4dck4m8yq", 0)
	Input.action_press("guard")
	pr = await wait_proj(0.9)
	await wait(10)
	Input.action_release("guard")
	ok(pr and pr.result in ["reflect", "enemy"], "Renvoi sur L1 : garde maintenue, renvoyée quand même (%s)" % (pr.result if pr else "?"))
	await go("m_mvks4dck4m8yq", 1)
	pr = await wait_proj(2.6)
	await tap("light")
	await wait(20)
	ok(pr and pr.result in ["reflect", "enemy"], "Renvoi sur X : le jab renvoie la boule (%s)" % (pr.result if pr else "?"))
	await go("m_mvks7ttlxxy7y")
	ok(p.attack == "collar", "Défense : sbire tenu par le col")
	ok(p.collar_limit >= 5.9, "bouclier humain : la chope tient 2× plus longtemps (%.1f s)" % p.collar_limit)
	m = {"abs": 0}
	for i in 3:
		p.collar_held = 0.0
		pr = await wait_proj(0.9, 300)
		await wait(4)
		if pr and pr.result == "absorb":
			m.abs += 1
	ok(m.abs == 3, "le sbire tenu encaisse les tirs (%d/3)" % m.abs)
	ok(p.attack != "collar", "au 3e, le bouclier humain cède")
	await go("m_defense_prop")
	ok(p.attack == "prop_hold", "Défense : caisse tenue")
	m = {"abs": 0}
	for i in 3:
		p.prop_t = 0.2
		pr = await wait_proj(0.9, 300)
		await wait(4)
		if pr and pr.result == "absorb":
			m.abs += 1
	ok(m.abs == 3 and p.held_prop == null, "la caisse encaisse 3 tirs puis casse (%d)" % m.abs)

	print("Coups à tester")
	await go("mseed45")
	e = lab.main.enemies[0]
	ok(e.weapon != null, "sbire armé d'un bâton")
	e.ai_on = false
	e.stun(1.5)
	p.guard_t = 0.1
	await tap("light")
	await wait(40)
	ok(e.weapon == null and p.held_prop != null and p.attack == "prop_hold", "juste après une parade, X : il lui arrache son bâton et le tient (%s)" % p.attack)
	await go("m_mvkqgf3gh3hrj")
	Input.action_press("guard")
	await wait(6)
	await tap("light")
	await wait(4)
	Input.action_release("guard")
	ok(p.attack == "wave", "L1 + X : la vague")
	await wait(70)
	m = {"n": 0}
	for x in lab.main.enemies:
		if x.ai == "stunned":
			m.n += 1
	ok(m.n >= 2, "les sbires autour sont étourdis (%d)" % m.n)
	await go("m_mvkqkuvl0el5d")
	e = lab.main.enemies[0]
	var d0: float = e.parts.chest.global_position.distance_to(p.global_position)
	var to: Vector3 = (e.root.origin - p.global_position).normalized()
	p.rotation.y = atan2(-to.x, -to.z)
	Input.action_press("grab")
	await wait(80)
	ok(p.ups.stats.get("web_enemy", 0) == 1, "R1 sans personne à portée : le fil accroche le sbire")
	var d1: float = e.parts.chest.global_position.distance_to(p.global_position)
	ok(d1 < d0 - 3.0, "R1 maintenu : l'élastique le ramène (%.1f m -> %.1f m)" % [d0, d1])
	Input.action_release("grab")
	await wait(6)
	ok(p.attack in ["web_throw", ""], "R1 relâché : il le lâche")
	await go("mseed48")
	e = lab.main.enemies[0]
	e.ai_on = false
	lab.modes[e] = "stand"
	await tap("roll")
	await wait(2)
	ok(p.roll_kind == "step" and p.is_invulnerable(), "B sans stick : pas de côté, invulnérable")
	p.on_evade(e)
	await wait(30)
	ok(p.ups.evade_t > 0.0, "son coup le manque : contre critique en attente")
	await tap("light")
	await wait(2)
	ok(p.hit_crit, "le coup suivant est critique")
	await go("mseed49", 0)
	ok(p.collar_b == "tomoe" and p.attack == "collar", "Tomoe nage : sbire tenu par le col")
	e = lab.main.enemies[0]
	await wait(20)
	await tap("roll")
	await wait(4)
	ok(p.attack == "tomoe", "chope + B : tomoe nage")
	await wait(90)
	var back: float = (e.parts.pelvis.global_position - p.global_position).dot(-p.global_basis.z)
	ok(back < -0.5 and e.state != "stand", "projeté par-dessus lui, derrière (%.1f m)" % back)
	await go("mseed56")
	await wait(10)
	await tap("special")
	await wait(4)
	ok(p.attack == "rain", "R2 : pluie d'objets")
	await wait(120)
	ok(p.ups.stats.get("rain_props", 0) >= 4, "les objets s'envolent (%d)" % p.ups.stats.get("rain_props", 0))
	m = {"n": 0}
	for x in lab.main.enemies:
		if x.state != "stand":
			m.n += 1
	ok(m.n >= 1, "ils percutent les sbires (%d au sol)" % m.n)

	print("Objet-bouclier retiré")
	await go("mseed19")
	await wait(20)
	Input.action_press("grab")
	await wait(80)
	ok(p.attack != "prop_shield", "R1 maintenu avec un objet : plus de bouclier (%s)" % p.attack)
	Input.action_release("grab")

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

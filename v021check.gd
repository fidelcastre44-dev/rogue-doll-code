extends SceneTree

const Upgrades = preload("res://upgrades.gd")
## Auto-test des correctifs de la version 0.21 (bilans de Thibaud du 22/10) : godot --headless --path . -s v021check.gd --fixed-fps 120
## Boule d'énergie retirée quand on est touché, roulade non spammable, piqué jamais bloqué, sbire qui se relève à côté d'un objet,
## sprint moins rapide, jab sans élan qui bloque le sbire sur place (aimantation proche seulement), uppercut de base,
## coups aériens qui suivent le saut et rebondissent, plaquage en amélioration et plus court, objet porté (X lance, Y fracasse,
## jambes qui marchent), pantin d'entraînement, caméra dynamique.

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


func watch(n: int, f: Callable) -> void:
	for i in n:
		await physics_frame
		f.call()


func _run() -> void:
	await wait(5)
	p = lab.player
	var e

	print("Bugs")
	await go("mseed07", {"charge_move": "hadoken"})
	Input.action_press("heavy")
	await wait(50)
	ok(p.orb != null, "boule d'énergie en charge")
	p.take_hit(Vector3.BACK, 5.0)
	Input.action_release("heavy")
	await wait(5)
	ok(p.orb == null, "touché pendant la charge : la boule disparaît")

	await go("pantin")
	m = {"starts": 0, "prev": -1.0}
	await tap("roll")
	for i in 6:
		await wait(5)
		await tap("roll")
	await watch(20, func():
		if p.roll >= 0 and (m.prev < 0 or p.roll < m.prev):
			m.starts += 1
		m.prev = p.roll)
	m.starts = 0
	m.prev = -1.0
	await go("pantin")
	await watch(1, func(): pass)
	Input.action_press("roll")
	await wait(2)
	Input.action_release("roll")
	var count := 1
	var prev: float = p.roll
	for i in 50:   # on martèle B pendant ~0,4 s : une seule roulade tant que la première n'est pas finie
		if i % 6 == 0:
			Input.action_press("roll")
		elif i % 6 == 2:
			Input.action_release("roll")
		await physics_frame
		if p.roll >= 0 and p.roll < prev - 0.01:
			count += 1
		prev = p.roll
	Input.action_release("roll")
	ok(count == 1, "roulade non spammable : une seule pendant l'animation (%d)" % count)

	await go("mseed11")   # sbire en garde devant (il ne frappe pas)
	e = lab.main.enemies[0]
	e.ai_on = false
	lab.modes[e] = "guard"
	await wait(10)
	await tap("jump")
	await wait(8)
	Input.action_press("heavy")
	await wait(40)
	Input.action_release("heavy")
	await wait(240)
	ok(p.attack == "" and p.is_on_floor(), "piqué dans un sbire en garde : jamais figé (%s)" % p.attack)
	Input.action_press("left")
	var p0: Vector3 = p.global_position
	await wait(30)
	Input.action_release("left")
	ok(p.global_position.distance_to(p0) > 0.5, "et il peut se déplacer ensuite")

	await go("pantin")
	e = lab.main.enemies[0]
	lab.modes[e] = "none"
	var box = lab._prop(Vector3(3, 0, -3))
	await wait(30)
	e.trip(Vector3.FORWARD, 0.0, 1.0)
	for part in e.parts.values():
		part.global_position = part.global_position - e.parts.pelvis.global_position * Vector3(1, 0, 1) + Vector3(3, 0.9, -3) * Vector3(1, 0, 1) + Vector3.UP * 0.6
		part.linear_velocity = Vector3.ZERO
	m = {"stood": false}
	await watch(900, func():
		if e.state == "stand":
			m.stood = true)
	ok(m.stood, "sbire tombé sur une caisse : il finit par se relever (%s)" % e.state)
	var off: float = ((e.root.origin - box.global_position) * Vector3(1, 0, 1)).length()
	ok(off > 0.6, "à côté de l'objet, pas dedans (%.2f m)" % off)

	print("Réglages")
	await go("pantin")
	lab.main.enemies[0].global_position = Vector3(30, 0, 30)
	lab.main.enemies[0].build()
	await wait(3)
	Input.action_press("up")
	await wait(10)
	p.sprinting = true
	m = {"v": 0.0}
	await watch(60, func(): m.v = maxf(m.v, Vector2(p.velocity.x, p.velocity.z).length()))
	Input.action_release("up")
	ok(m.v < p.speed * 1.45 and m.v > p.speed * 1.2, "sprint moins rapide (%.1f m/s, marche %.1f)" % [m.v, p.speed])

	await go("pantin")
	lab.main.enemies[0].global_position = Vector3(30, 0, 30)
	lab.main.enemies[0].build()
	await wait(3)
	p0 = p.global_position
	Input.action_press("up")
	for i in 8:
		await tap("light")
		await wait(8)
	Input.action_release("up")
	await wait(20)
	var walked: float = p.global_position.distance_to(p0)
	await go("pantin")
	lab.main.enemies[0].global_position = Vector3(30, 0, 30)
	lab.main.enemies[0].build()
	await wait(3)
	p0 = p.global_position
	Input.action_press("up")
	await wait(16 * 8 + 20)
	Input.action_release("up")
	await wait(20)
	var walk_only: float = p.global_position.distance_to(p0)
	ok(walked < walk_only * 0.75, "jabs martelés en marchant : on n'avance pas plus vite qu'en marchant, au contraire (%.1f m contre %.1f)" % [walked, walk_only])

	await go("pantin")
	e = lab.main.enemies[0]
	var e0: Vector3 = e.parts.chest.global_position
	await tap("light")
	await wait(30)
	await tap("light")
	await wait(30)
	ok(e.state == "stand" and e.parts.chest.global_position.distance_to(e0) < 0.6, "jab, direct : le sbire reste sur place (%s, %.2f m)" % [e.state, e.parts.chest.global_position.distance_to(e0)])
	ok(p._combo() == ["jab", "cross", "jab2", "upper"], "uppercut en dernier coup de base (3 jabs + uppercut, v0.216)")

	# Aimantation du jab : sbire proche droit devant -> il se tourne ; sur le côté (45°) -> rien.
	await go("pantin")
	e = lab.main.enemies[0]
	var f0: Vector3 = Vector3(1, 0, -1).normalized()
	e.global_position = p.global_position + f0.rotated(Vector3.UP, deg_to_rad(18)) * 1.2
	e.build()
	await wait(5)
	var yaw0: float = p.rotation.y
	await tap("light")
	await wait(3)
	ok(absf(angle_difference(yaw0, p.rotation.y)) > deg_to_rad(10), "jab : petite aimantation vers un sbire tout proche, presque devant")

	print("Aérien")
	await go("pantin")
	lab.main.enemies[0].global_position = Vector3(30, 0, 30)
	lab.main.enemies[0].build()
	await wait(3)
	await tap("jump")
	await wait(12)
	var vy0: float = p.velocity.y
	await tap("light")
	await wait(3)
	ok(vy0 > 3.0 and p.attack == "air", "on peut frapper en montant (vitesse %.1f, %s)" % [vy0, p.attack])
	m = {"minvy": 99.0}
	await watch(50, func(): m.minvy = minf(m.minvy, p.velocity.y))
	ok(m.minvy < -2.0, "le coup suit la courbe du saut : il retombe pendant le coup (%.1f m/s)" % m.minvy)
	await go("mseed02")
	await wait(30)
	m = {"bounce": false, "con": false}
	await tap("jump")
	for i in 3:
		await wait(10)
		await tap("light")
		await watch(12, func():
			if p.connected and p.attack in ["air", "air_cross", "air_upper"] and p.velocity.y > 3.5:
				m.bounce = true)
	ok(m.bounce, "un coup aérien qui touche fait rebondir le héros vers le haut")

	print("Plaquage")
	await go("mseed32", {"tackle_up": false})
	Input.action_press("up")
	await wait(2)
	p.sprinting = true
	await wait(20)
	m = {"seen": false}
	await tap("grab")
	await watch(40, func():
		if p.attack == "tackle":
			m.seen = true)
	Input.action_release("up")
	ok(not m.seen, "sans l'amélioration, R1 en sprint ne plaque pas")
	await go("mseed32")
	ok(p.tackle_up, "dans le labo, le plaquage est actif (amélioration)")
	ok(p.TACKLE_TIME < 0.4, "il emporte moins loin (%.2f s)" % p.TACKLE_TIME)

	print("Objet porté")
	await go("mseed19")
	await wait(20)
	ok(p.attack == "prop_hold", "objet en main (%s)" % p.attack)
	Input.action_press("up")
	await wait(30)
	var hip: Quaternion = p.j.hip_l.quaternion
	var swing := {"max": 0.0}
	await watch(40, func(): swing.max = maxf(swing.max, hip.angle_to(p.j.hip_l.quaternion)))
	ok(swing.max > deg_to_rad(8), "il marche en le portant (les jambes bougent de %.0f°)" % rad_to_deg(swing.max))
	Input.action_release("up")
	await tap("heavy")
	await wait(4)
	ok(p.attack == "prop_bash", "Y : il le fracasse devant lui")
	await wait(80)
	await tap("light")
	await wait(4)
	ok(p.attack == "prop_toss", "X : il le lance droit devant (%s)" % p.attack)

	print("Pantin et caméra")
	await go("pantin")
	ok(lab.main.enemies.size() == 1 and not lab.main.enemies[0].ai_on, "pantin : un sbire qui ne riposte pas")
	var mn = lab.main
	for e2 in mn.enemies:
		e2.global_position = Vector3(40, 0, 40)
	await wait(240)
	var alone: float = mn.cam_zoom
	await go("pantin", {})
	lab.set_extra(4, "stand")
	await wait(240)
	var crowd: float = mn.cam_zoom
	ok(alone < crowd, "caméra : plus près sans sbire (%.2f), plus loin quand ils sont autour (%.2f)" % [alone, crowd])
	ok(crowd <= mn.CAM_ZOOM_MAX, "avec une limite")
	lab.set_extra(0, "stand")

	print("Salle des builds")
	var prev_n := -1
	for i in BuildTiers.TIERS.size():
		var n := 0
		for k2 in i + 1:
			n += BuildTiers.TIERS[k2].ups.size()
		ok(n > prev_n, "%s : %d améliorations (plus que le palier d'avant)" % [BuildTiers.TIERS[i].name, n])
		prev_n = n
		for id in BuildTiers.TIERS[i].ups:
			ok(Upgrades.find(id.split(":")[0]).size() > 0, "%s : « %s » existe dans upgrades.gd" % [BuildTiers.TIERS[i].name, id])
	await go("build_vanilla")
	ok(p.light_move == "base" and p.charge_move == "none" and not p.double_jump, "Vanilla : le héros de départ")
	ok(lab.main.enemies.size() == 3, "trois sbires dans la salle")
	await wait(20)
	ok(lab.main.enemies.all(func(x): return x.ai_on), "ils attaquent (IA allumée)")
	await go("build_t3")
	ok(p.light_move == "knee" and p.double_jump and p.air_dodges == 3 and p.heavy_move == "axe" and p.tackle_up, "Palier 3 : tout ce qui vient des paliers 1, 2 et 3")
	ok(lab.what_lbl.text.contains("Déjà là"), "la fiche liste les coups du build")

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

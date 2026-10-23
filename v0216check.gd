extends SceneTree
## Auto-test de la v0.216 (retours de Thibaud et Paul du 23/10) : godot --headless --path . -s v0216check.gd --fixed-fps 120
## Attack rolls qui ne coupent plus la roulade, balayage sur un sbire couché, attack roll après un rebond mural, chute de 2 m
## sans atterrissage lourd, agrippé (X / R1), enjamber un objet, combo 3 jabs + uppercut et récupération, X / Y en sprint,
## gros genou aérien, super saut moins haut + plaqué au sol, plaquage contre le mur, râpe à fromage (chope + Y), toile
## (enchaînement, en l'air), couleurs du labo.

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


func watch(n: int, f: Callable) -> void:
	for i in n:
		await physics_frame
		f.call()


func seen_moves(n: int) -> Array:
	var s := []
	for i in n:
		await physics_frame
		if p.attack != "" and (s.is_empty() or s.back() != p.attack):
			s.append(p.attack)
	return s


func _run() -> void:
	await wait(5)
	p = lab.player

	print("1. Attack roll : X pendant la roulade ne la coupe plus")
	await go("mseed16")
	await tap("roll")
	await wait(30)   # 0,25 s : passé le moment où une action coupait la roulade
	await tap("light")
	await wait(10)
	ok(p.roll >= 0.0 and p.attack == "", "la roulade continue (%.2f s), le coup attend" % p.roll)
	m = {"spin": false, "roll_at": -1.0}
	await watch(80, func():
		if p.attack == "spin_counter" and not m.spin:
			m.spin = true)
	ok(m.spin, "le contre tournant part à la fin de la roulade")
	await go("mseed25")
	await tap("roll")
	await wait(30)
	await tap("heavy")
	await wait(10)
	ok(p.roll >= 0.0 and p.attack == "", "Y : la roulade continue aussi")
	m = {"cap": false}
	await watch(80, func():
		if p.attack == "capoeira":
			m.cap = true)
	ok(m.cap, "puis le retourné capoeira part")

	print("2. Balayage sur un sbire couché")
	await go("mseed09")
	await wait(60)
	var e = lab.main.enemies[0]
	var gk0: int = e.ground_kicks
	p.rotation.y = atan2(-(e.parts.pelvis.global_position - p.global_position).x, -(e.parts.pelvis.global_position - p.global_position).z)
	Input.action_press("light")
	await wait(40)
	Input.action_release("light")
	await wait(40)
	ok(e.ground_kicks > gk0, "le balayage touche le sbire couché (coup au sol : dégâts, il décolle)")

	print("3. Rebond mural puis attack roll")
	await go("mseed47")
	hold(["up"])
	await wait(2)
	await tap("roll")
	await wait(12)
	hold([])
	m = {"bounce": 0, "spin": false}
	var b0: int = p.lc.stats.get("wall_bounce", 0)
	for i in 120:
		await physics_frame
		if p.lc.stats.get("wall_bounce", 0) > b0 and not m.get("x", false):
			m.x = true
			Input.action_press("light")
		elif m.get("x", false):
			Input.action_release("light")
		if p.attack == "spin_counter":
			m.spin = true
	ok(p.lc.stats.get("wall_bounce", 0) > b0, "il rebondit sur le mur")
	ok(m.spin, "X pendant le rebond : l'attack roll part à la fin")

	print("4. Chute de la plateforme (2 m) : pas d'atterrissage lourd")
	await go("mv_fallhit")
	hold(["down", "right"])
	await wait(30)
	await tap("jump")
	m = {"heavy": false}
	await watch(160, func():
		if p.lc.state == "heavy_land":
			m.heavy = true)
	hold([])
	ok(not m.heavy, "2 m de chute : il retombe normalement (le figé ne vient qu'à partir de 3 m)")

	print("5. Agrippé au bloc de 3 m : X et R1")
	await go("mv_hang")
	hold(["up", "left"])
	await wait(26)
	await tap("jump")
	await watch(70, func(): pass)
	hold([])
	await wait(20)
	ok(p.lc.state == "hang", "il s'agrippe au bloc de 3 m (%s)" % p.lc.state)
	await tap("light")
	await wait(100)
	ok(p.lc.stats.get("climb_attack", 0) >= 1 and p.lc.stats.get("climb_push", 0) >= 1, "X : il se hisse en repoussant le sbire en haut")
	ok(absf(p.global_position.y - 3.0) < 0.2, "il est monté (%.2f m)" % p.global_position.y)
	await go("mv_hang")
	hold(["up", "left"])
	await wait(26)
	await tap("jump")
	await watch(70, func(): pass)
	hold([])
	await wait(20)
	var foe = lab.main.enemies[0]
	await tap("grab")
	await wait(150)
	ok(p.lc.stats.get("yank", 0) >= 1, "R1 : il attrape la cheville du sbire au bord")
	ok(foe.parts.pelvis.global_position.y < 2.2, "le sbire est tombé dans le vide (bassin à %.2f m)" % foe.parts.pelvis.global_position.y)

	print("6. Enjamber un objet")
	await go("mv_propvault")
	hold(["up"])
	await wait(8)
	hold([])
	await tap("jump")
	await wait(80)
	ok(p.lc.stats.get("vault", 0) >= 1, "A tout près de la table : il l'enjambe")

	print("7. Combo : 3 jabs + uppercut, puis récupération")
	await go("mseed00")
	var s := []
	for i in 6:
		await tap("light")
		var got: Array = await seen_moves(22)
		for g in got:
			if s.is_empty() or s.back() != g:
				s.append(g)
	ok(s.slice(0, 4) == ["jab", "cross", "jab2", "upper"], "jab, direct, jab, uppercut (%s)" % str(s.slice(0, 4)))
	await go("mseed00")
	for k in 4:
		await tap("light")
		await wait(20)
	m = {"rec": false, "early": false}
	for i in 140:
		await physics_frame
		if p.recover_t > 0.0:
			m.rec = true
			if p.attack != "":
				m.early = true
			Input.action_press("light")
		else:
			Input.action_release("light")
	Input.action_release("light")
	ok(m.rec and not m.early, "après l'uppercut : petit temps de récupération, aucune attaque ne part")

	print("8. X en sprint : coup de pied glissé")
	await go("mseed04", 0)
	ok(p.sprint_attack == "slide", "tacle glissé de base")
	e = lab.main.enemies[0]
	hold(["up"])
	await wait(2)
	p.sprinting = true
	for i in 120:
		await physics_frame
		if ((e.root.origin - p.global_position) * Vector3(1, 0, 1)).length() < 3.0:
			break
	await tap("light")
	m = {"slide": false, "down": false}
	await watch(70, func():
		if p.roll >= 0.0 and p.roll_kind == "slide":
			m.slide = true
		if e.state in ["down", "dead"]:
			m.down = true)
	hold([])
	ok(m.slide, "X en sprint : glissade (pas un jab)")
	ok(m.down, "le sbire touché tombe")

	print("9. Y en sprint : gros coup de pied sans saut")
	await go("mseed24")
	hold(["up"])
	await wait(2)
	p.sprinting = true
	await wait(40)
	await tap("heavy")
	var sm: Array = await seen_moves(120)
	hold([])
	ok("run_kick" in sm and not "drop_kick" in sm and not "drop_land" in sm, "coup de pied en course, plus de drop kick (%s)" % str(sm))
	await wait(30)
	ok(p.attack == "", "il n'est pas figé au sol")

	print("10. Y en l'air : gros genou qui garde l'élan")
	await go("mseed06")
	hold(["up"])
	await wait(10)
	await tap("jump")
	await wait(16)
	var hv0: float = Vector2(p.velocity.x, p.velocity.z).length()
	await tap("heavy")
	await wait(3)
	ok(p.attack == "air_bigknee", "Y en l'air : gros genou (%s)" % p.attack)
	ok(Vector2(p.velocity.x, p.velocity.z).length() > hv0 * 0.6, "il garde son élan (%.1f -> %.1f m/s)" % [hv0, Vector2(p.velocity.x, p.velocity.z).length()])
	hold([])

	print("11. Super saut : moins haut, plaqué au sol")
	await go("mseed52")
	var y0: float = p.global_position.y
	Input.action_press("jump")
	m = {"peak": 0.0, "sj": false}
	await watch(70, func():
		m.peak = maxf(m.peak, p.global_position.y - y0)
		if p.attack == "super_jump":
			m.sj = true)
	ok(m.sj, "A maintenu : super saut")
	ok(m.peak < 3.0, "moins haut qu'avant (%.2f m, ~3,9 m en v0.215)" % m.peak)
	Input.action_release("jump")
	await tap("grab")
	m = {"pin": false, "punch": false, "down": true, "victim": null}
	for i in 200:
		await physics_frame
		if p.attack == "sj_pin":
			if not m.pin:
				m.pin = true
				m.victim = p.pin_victim
			Input.action_press("light")
		elif p.attack == "pin_punch":
			m.punch = true
			Input.action_release("light")
		if m.pin and m.victim and p.attack in ["sj_pin", "pin_punch"] and not m.victim.state in ["down", "dead"]:
			m.down = false
	Input.action_release("light")
	ok(m.pin, "chope plongeante : il reste sur le sbire plaqué")
	ok(m.punch, "X : coup de poing au sol")
	ok(m.down, "le sbire reste au sol tant qu'il est dessus")

	print("12. Plaquage contre le mur")
	await go("mv_tackle_wall")
	hold(["up"])
	await wait(4)
	p.sprinting = true
	await wait(6)
	await tap("grab")
	sm = await seen_moves(150)
	hold([])
	ok("tackle_wall" in sm and p.last_tackle_dmg > 30.0, "plaqué debout, dos contre le mur (%s, %.0f)" % [str(sm), p.last_tackle_dmg])

	print("13. Râpe à fromage : chope + Y près d'un mur")
	await go("mseed36")
	await wait(10)
	await tap("heavy")
	sm = await seen_moves(140)
	ok(sm.has("cheese_grater") or sm.has("cheese_grater_r"), "chope + Y près du mur : râpe à fromage (%s)" % str(sm))
	await go("mseed36")
	await wait(10)
	await tap("grab")
	sm = await seen_moves(60)
	ok(not sm.has("cheese_grater") and not sm.has("cheese_grater_r"), "chope + R1 près du mur : plus la râpe (%s)" % str(sm))
	await go("mseed08")
	await tap("grab")
	await wait(30)
	await tap("heavy")
	sm = await seen_moves(40)
	ok(sm.has("headbutt"), "loin d'un mur, Y reste le coup de tête")

	print("14. Toile : enchaînement et tir en l'air")
	await go("m_mvkqkuvl0el5d")
	Input.action_press("grab")
	m = {"follow": false}
	for i in 160:
		await physics_frame
		if p.attack == "web" and p.ups.web_kind == "enemy" and is_instance_valid(p.ups.web_target):
			if p.ups.web_target.parts.chest.global_position.distance_to(p.global_position + Vector3.UP) < 2.6 and not m.get("x", false):
				m.x = true
				Input.action_press("light")
		elif m.get("x", false):
			Input.action_release("light")
		if p.ups.stats.get("web_follow", 0) > 0:
			m.follow = true
	Input.action_release("grab")
	Input.action_release("light")
	ok(m.follow, "le sbire ramené arrive : X lâche le fil et enchaîne")
	await go("m_mvkqkuvl0el5d")
	for en in lab.main.enemies:
		en.global_position += Vector3(40, 0, 0)
		en.build()
	await tap("jump")
	await wait(14)
	await tap("grab")
	await wait(12)
	ok(p.attack == "web" or p.ups.stats.get("web_wall", 0) + p.ups.stats.get("web_prop", 0) > 0, "en l'air : le fil part (%s)" % p.attack)
	ok(LaboCatalog.find("m_mvkqkuvl0el5d").what.contains("élastique"), "fiche du labo à jour")

	print("16. Labo : coups colorés par bouton")
	ok(lab.btn_color("X").b > 0.8 and lab.btn_color("Y").r > 0.9 and lab.btn_color("B").r > 0.9 and lab.btn_color("A").g > 0.8, "X bleu, Y jaune, B rouge, A vert")
	var firsts := []
	for k in lab.pick.item_count:
		var mv: Dictionary = LaboCatalog.MOVES[lab.pick.get_item_id(k)]
		var fb: String = lab.first_button(mv.button)
		if fb != "—" and (firsts.is_empty() or firsts.back() != fb):
			firsts.append(fb)
	ok(firsts.slice(0, 4) == ["X", "Y", "B", "A"], "la liste est rangée par couleur (%s)" % str(firsts.slice(0, 4)))
	lab.select(5)
	ok(lab.pick.get_item_id(lab.pick.selected) == 5, "choisir un coup sélectionne la bonne ligne")

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

extends SceneTree
## Auto-test verrouillage : godot --headless --path . -s lockcheck.gd --fixed-fps 120
## 1. Ennemi à 2,3 m, pas en face : un jab sans diriger se tourne vers lui, comble la distance et touche.
## 2. Uppercut, saut, puis on martèle le poing sans jamais diriger : les coups aériens touchent (jongle), on reste collé à lui.
## 3. Placé en plein dans son corps pendant qu'il est en l'air : on n'est pas éjecté.

var main: Node3D
var f := 0
var fails := []
var phase := "start"
var pt := 0
var max_speed := 0.0
var max_gap := 0.0
var start_pos := Vector3.ZERO
var raised := false
var smashed := false


func _initialize() -> void:
	seed(5)
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false
	main.get_node("Player").air_move = "hammer"   # amélioration testée ici
	main.get_node("Player").lock_on = true   # ce test vérifie aussi l'aimantation (désactivée en jeu, code gardé)
	root.add_child(main)


func _tap(action: String) -> void:
	Input.action_press(action)
	var n := Engine.get_physics_frames()
	while Engine.get_physics_frames() < n + 2:
		await process_frame
	Input.action_release(action)


func _go(next: String) -> void:
	phase = next
	pt = f


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	var k := f - pt
	var pel: Vector3 = e.parts.pelvis.global_position
	match phase:
		"start":
			if f == 20:
				p.global_position = Vector3(pel.x + 0.7, 0, pel.z + 1.3)   # 1,5 m, un peu de côté
				p.rotation.y = 0   # il regarde vers -Z : l'ennemi est à ~30° sur le côté
				p.velocity = Vector3.ZERO
				_tap("light")
				_go("jab")
		"jab":
			if k == 60:
				_check(e.hp < e.MAX_HP, "jab sans diriger, ennemi à 1,5 m un peu de côté : il se tourne, s'approche et touche (vie %.0f)" % e.hp)
				e.build()
				_go("far")
		"far":   # aimantation restreinte : un ennemi à 3,5 m n'attire plus le coup
			if k == 20:
				p.global_position = Vector3(pel.x, 0, pel.z + 3.5)
				p.rotation.y = 0
				p.velocity = Vector3.ZERO
				start_pos = p.global_position
				_tap("light")
			if k == 60:
				var moved: float = ((p.global_position - start_pos) * Vector3(1, 0, 1)).length()
				_check(moved < 0.8 and e.hp == e.MAX_HP, "ennemi à 3,5 m : pas aspiré vers lui (déplacé de %.2f m)" % moved)
				_go("juggle_setup")
		"juggle_setup":
			if k == 20:
				p.global_position = Vector3(pel.x + 0.5, 0, pel.z + 1.2)   # un peu de travers, un peu loin
				p.rotation.y = 0.5
				p.velocity = Vector3.ZERO
				p.start("upper")
				_go("juggle")
		"juggle":
			if p.connected and p.attack == "upper" and k < 40:
				_tap("jump")
			if not p.is_on_floor() and k % 14 == 0:
				_tap("light")   # on martèle, sans jamais diriger
			if p.attack == "hammer":
				var hands: float = (p.j.fist_l.global_position.y + p.j.fist_r.global_position.y) * 0.5
				if hands > p.j.head.global_position.y + 0.15 and p.t < p.ATK.hammer.active and p.j.el_l.quaternion.get_angle() < deg_to_rad(10) and p.j.spine.global_basis.y.dot(p.global_basis.z) > 0.3:
					raised = true   # bras tendus au-dessus/derrière la tête, buste renversé en arrière
				if raised and p.t >= p.ATK.hammer.active and hands < p.j.head.global_position.y and p.j.fist_l.global_position.distance_to(p.j.fist_r.global_position) < 0.3:
					smashed = true
			if not p.is_on_floor():
				max_speed = maxf(max_speed, Vector2(p.velocity.x, p.velocity.z).length())
				if e.juggles >= 1 and e.state in ["down", "crisp"] and pel.y > 0.8:
					max_gap = maxf(max_gap, ((pel - p.global_position) * Vector3(1, 0, 1)).length())
			if k == 160:
				_check(e.juggles >= 1, "en martelant sans diriger, le marteau touche (%d)" % e.juggles)
				_check(raised and smashed, "coup aérien = marteau : corps en arc bras tendus au-dessus de la tête, puis replié, poings abattus devant (%s, %s)" % [raised, smashed])
				_check(max_speed < 12.0, "jamais éjecté pendant le jongle (vitesse max %.1f m/s)" % max_speed)
				_check(max_gap < 1.6, "après le premier coup, on reste collé à lui en l'air (écart max %.2f m)" % max_gap)
				e.build()
				_go("overlap")
		"overlap":
			if k == 20:
				e.hit(e.parts.chest, Vector3(0, 1.2, -0.3).normalized() * 50.0, e.parts.chest.global_position, 14.0, 1.0)
			if k == 40:
				start_pos = Vector3(pel.x, 0, pel.z)
				p.global_position = start_pos   # en plein sous / dans son corps
				p.velocity = Vector3.ZERO
			if k > 40 and k < 160:
				max_speed = 0.0 if k == 41 else maxf(max_speed, Vector2(p.velocity.x, p.velocity.z).length())
			if k == 160:
				var moved: float = ((p.global_position - start_pos) * Vector3(1, 0, 1)).length()
				_check(moved < 0.6 and max_speed < 1.0, "dans son corps pendant qu'il retombe : pas éjecté (déplacé de %.2f m, vitesse max %.1f m/s)" % [moved, max_speed])
				print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
				quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

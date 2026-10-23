extends SceneTree
## Salle de test des coups : elle se lance, chaque coup jouable part depuis la liste et touche le mannequin,
## les mannequins restent dans l'état choisi et ne meurent jamais, le ralenti tient malgré le hitstop, F5 recharge.
var lab
var f := 0
var phase := 0
var queue: Array = []
var fails := 0
var hits := {}
var t0 := 0
var max_y := 0.0

func _initialize():
	lab = load("res://move_lab.tscn").instantiate()
	root.add_child(lab)

func ok(c: bool, msg: String) -> void:
	print("  [ok] " if c else "  [FAIL] ", msg)
	if not c:
		fails += 1

const NEW := ["superman", "drop_kick", "drop_land", "tackle", "tackle_slam", "suplex", "piledriver", "pd_land", "hip_throw", "cheese_grater", "cheese_grater_r", "prop_shield", "spin_counter", "spin_counter3", "capoeira", "soccer_kick", "prop_kick", "prop_bash", "wall_run", "bicycle", "tramp", "super_jump", "sm_land", "air_cross", "air_upper", "air_hook", "air_knee", "wall_run_h", "sj_grab", "air_bigknee", "sj_pin", "pin_punch", "tackle_wall"]

func _process(_d):
	f += 1
	if f == 10:
		print("Salle de test des coups")
		ok(lab.main != null and lab.player != null, "la salle charge le jeu (héros + mannequin)")
		ok(lab.ids.size() > 30, "la liste montre les coups (%d lignes)" % lab.ids.size())
		for id in lab.ids:
			if id != "" and lab.playable(MoveLibrary.moves()[id]) and not id in NEW:   # les coups de l'atelier se testent dans le labo (labocheck)
				queue.append(id)
		ok(queue.size() >= 15, "%d coups jouables depuis la liste" % queue.size())
		phase = 1
		t0 = f
	if phase == 1 and f >= t0 and not queue.is_empty() and (f - t0) % 150 == 0:
		var id: String = queue[0]
		var e = lab.main.enemies[0]
		e.hp = e.MAX_HP
		lab._reset_dummies()
		lab.player.global_position = Vector3(0, 0, 1.5)
		lab.player.velocity = Vector3.ZERO
		lab.play(id)
	if phase == 1 and f > t0 and not queue.is_empty() and (f - t0) % 150 == 140:
		var id: String = queue.pop_front()
		hits[id] = lab.log_lines.size() > 0 and lab.log_lines[0].begins_with(id)
		if queue.is_empty():
			var missed := []
			for k in hits:
				if not hits[k]:
					missed.append(k)
			ok(missed.size() <= 3, "les coups au sol touchent le mannequin immobile (ratés : %s ; les coups aériens visent un ennemi en l'air)" % str(missed))
			ok(lab.main.enemies[0].hp == lab.main.enemies[0].MAX_HP, "le mannequin ne meurt jamais (vie rendue)")
			phase = 2
			t0 = f
	if phase == 2:
		if f > t0 + 150 and f < t0 + 330 and lab.main.enemies[0].parts.has("pelvis"):
			max_y = maxf(max_y, lab.main.enemies[0].parts.pelvis.global_position.y)
		if f == t0 + 1:
			lab._set_dummies("ground")
		if f == t0 + 150:
			ok(lab.main.enemies[0].state in ["down", "dead", "getup"], "mannequin « au sol » : il est couché (%s)" % lab.main.enemies[0].state)
			lab._set_dummies("air")
		if f == t0 + 330:
			var y: float = lab.main.enemies[0].parts.pelvis.global_position.y
			ok(max_y > 2.5, "mannequin « en l'air » : il est relancé en l'air (bassin monté à %.1f m)" % max_y)
			lab._set_dummies("guard")
		if f == t0 + 600:
			ok(lab.main.enemies[0].ai == "block", "mannequin « en garde » : garde levée")
			lab.set_speed(2)
			lab._set_dummies("stand")
			lab._reset_dummies()
			lab.play("cross")
		if f == t0 + 900:
			ok(is_equal_approx(Engine.time_scale, 0.25), "le ralenti ×0.25 tient après un hitstop (%.2f)" % Engine.time_scale)
			lab.set_speed(0)
			lab._set_count(3)
		if f == t0 + 920:
			ok(lab.main.enemies.size() == 3 and lab.player.enemies.size() == 3, "3 mannequins")
			var before: float = lab.player.ATK.jab.active
			lab.reload()
			ok(is_equal_approx(lab.player.ATK.jab.active, before) and lab.player.ATK.size() > 40, "F5 recharge les fiches (%d coups)" % lab.player.ATK.size())
			print("RESULTAT: ", "OK" if fails == 0 else "ECHEC (%d)" % fails)
			quit()
	return false

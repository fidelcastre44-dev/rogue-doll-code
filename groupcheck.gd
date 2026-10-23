extends SceneTree
## Auto-test en groupe (5 sbires) : godot --headless --path . -s groupcheck.gd --fixed-fps 120
## 1. IA : jamais plus de 2 attaquants à la fois, ils s'écartent les uns des autres, ils attaquent quand même souvent.
## 2. Balayage : il fauche plusieurs sbires d'un coup.
## 3. Visée : le stick vers un sbire = le jab va sur lui.
## 4. Un sbire mort réapparaît plus tard, au bord de l'arène.

var main: Node3D
var f := 0
var fails := []
var phase := "ai"
var pt := 0
var max_att := 0
var min_gap := INF
var strikes := 0
var prev := {}
var dead_one: Node3D


func _initialize() -> void:
	seed(9)
	main = load("res://main.tscn").instantiate()
	main.force_extras = 4
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
	var es: Array = main.enemies
	var k := f - pt
	match phase:
		"ai":
			if f == 2:
				_check(es.size() == 5, "5 sbires dans l'arène (%d)" % es.size())
			p.hp = 1000.0   # il encaisse, on observe
			var att := 0
			for e in es:
				if e.state == "stand" and (e.ai in ["windup", "strike"] or (e.ai == "recover" and e.chain_left > 0)):
					att += 1
				if e.ai == "strike" and prev.get(e, "") != "strike":
					strikes += 1
				prev[e] = e.ai
			max_att = maxi(max_att, att)
			if f > 240:
				for a in es:
					for b in es:
						if a != b and a.state == "stand" and b.state == "stand" and a.ai == "circle" and b.ai == "circle":
							min_gap = minf(min_gap, ((a.root.origin - b.root.origin) * Vector3(1, 0, 1)).length())
			if f == 120 * 12:
				_check(max_att <= 2, "jamais plus de 2 sbires qui attaquent en même temps (max %d)" % max_att)
				_check(min_gap > 0.8, "ils s'écartent les uns des autres (distance min %.2f m)" % min_gap)
				_check(strikes >= 8 and strikes <= 24, "ils attaquent souvent, sans t'écraser (%d coups en 12 s)" % strikes)
				for e in es:
					e.ai_on = false
					e.build()
				_go("sweep")
		"sweep":
			if k == 10:
				p.global_position = Vector3(0, 0, 0)
				p.velocity = Vector3.ZERO
				p.hp = 100.0
				p.hurt = 0.0
				p.attack = ""
				for i in 3:   # 3 sbires serrés autour de lui
					var a := TAU * i / 3.0
					es[i].global_position = Vector3(cos(a), 0, sin(a)) * 0.95
					es[i].build()
				for i in range(3, 5):
					es[i].global_position = Vector3(20 + i * 3, 0, 20)
					es[i].build()
			if k == 20:
				Input.action_press("light")   # X maintenu = balayage retourné   # X + bas : balayage retourné
			if k == 60:
				Input.action_release("light")
			if k == 110:
				var down := 0
				for i in 3:
					if es[i].state != "stand":
						down += 1
				_check(down >= 2, "un balayage fauche plusieurs sbires d'un coup (%d sur 3)" % down)
				_go("aim")
		"aim":
			if k == 10:
				for i in 5:
					es[i].global_position = Vector3(20 + i * 3, 0, -20)
					es[i].build()
				es[0].global_position = Vector3(-1.3, 0, 0)   # à gauche
				es[0].build()
				es[1].global_position = Vector3(1.3, 0, 0)    # à droite
				es[1].build()
				p.global_position = Vector3.ZERO
				p.velocity = Vector3.ZERO
				p.rotation.y = 0
			if k == 30:
				Input.action_press("right")   # stick vers la droite (repère caméra) puis jab
			if k == 33:
				_tap("light")
			if k == 40:
				Input.action_release("right")
			if k == 100:
				var cam_right: Vector3 = main.cam.global_basis.x * Vector3(1, 0, 1)
				var hit_one: Node3D = es[0] if es[0].hp < es[0].MAX_HP else (es[1] if es[1].hp < es[1].MAX_HP else null)
				var expected: Node3D = es[1] if (es[1].global_position - es[0].global_position).dot(cam_right) > 0 else es[0]
				_check(hit_one == expected, "le stick choisit la cible : le jab va sur le sbire indiqué")
				# Tenu par la chope, puis touché par un autre sbire : celui qu'on tenait est lâché (il ne reste pas figé).
				p.global_position = es[0].root.origin + es[0].root.basis.z * 0.9
				p.rotation.y = atan2(es[0].root.basis.z.x, es[0].root.basis.z.z)
				p.attack = ""
				p.hurt = 0.0
				p.enemy = es[0]
				p.start("grab")
				_go("grabhit")
		"grabhit":
			if k == 40:
				_check(es[0].state == "held" and p.attack == "collar", "sbire attrapé (%s, %s)" % [es[0].state, p.attack])
				p.take_hit(Vector3.BACK, 5.0)   # un autre sbire le frappe
			if k == 100:
				_check(es[0].state != "held", "touché pendant la chope : le sbire tenu est lâché, il ne reste pas figé (%s)" % es[0].state)
				var es2: Array = main.enemies
				dead_one = es2[2]
				dead_one.global_position = Vector3(2, 0, 2)
				dead_one.build()
				dead_one.hp = 1.0
				dead_one.hit(dead_one.parts.chest, Vector3(0, 0.3, 1).normalized() * 40.0, dead_one.parts.chest.global_position, 5.0, 1.0)
				p.hp = 1000.0
				_go("respawn")
		"respawn":
			if k == 30:
				_check(dead_one.state == "dead", "un sbire tué (%s)" % dead_one.state)
			if k == 120 * 7:
				var d: float = (dead_one.root.origin - p.global_position).length()
				_check(dead_one.state == "stand" and dead_one.hp == dead_one.MAX_HP and d > 5.0, "réapparu au bord de l'arène (%s, à %.1f m du joueur)" % [dead_one.state, d])
				print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
				quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

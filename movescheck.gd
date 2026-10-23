extends SceneTree
## Auto-test des nouveaux coups : godot --headless --path . -s movescheck.gd --fixed-fps 120
## 1. Uppercut sur un ennemi en l'air : vrai nouveau décollage.
## 2. High kick au sol : l'ennemi part sur le côté.
## 3. Chassé sauté : le perso passe à l'horizontale, touche, rebondit.
## 4. Chope au sol par le col : relevé, 3 droites, puis il repart en l'air (saut d'annulation possible).
## 5. Chope au col puis chope : fracassé au sol, il rebondit.

var main: Node3D
var f := 0
var fails := []
var phase := "up_setup"
var downed_try := -1
var v_corpse := Vector3.ZERO
var pt := 0
var peak := 0.0
var flat := false
var hp0 := 0.0
var start := Vector3.ZERO
var max_gap := 0.0
var lifted := 0.0
var turned := 0.0
var prev_yaw := 0.0
var flat_seen := false
var released := false
var before_swing_gap := 0.0
var e2: Node3D
var spinning := false
var swing_walk := 0.0
var spin_ang := 0.0
var hp_rel := 0.0
var land_ok := false
var air_caught := false
var slam_seen := false
var shin_top := 0.0
var leg_swing := 0.0
var leg0 := Quaternion()
var foot_y := -1.0
var head_y := 0.0


func _initialize() -> void:
	seed(11)
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false

	main.get_node("Player").lock_on = true   # ce test vérifie aussi l'aimantation (désactivée en jeu, code gardé)
	root.add_child(main)


func _tap(action: String) -> void:
	Input.action_press(action)
	var n := Engine.get_physics_frames()
	while Engine.get_physics_frames() < n + 2:
		await process_frame
	Input.action_release(action)


## Stick dans une direction (angle), pour faire des cercles pendant le grand tour.
func _stick(a: float) -> void:
	for act in ["left", "right", "up", "down"]:
		Input.action_release(act)
	if cos(a) > 0.05: Input.action_press("right", cos(a))
	if cos(a) < -0.05: Input.action_press("left", -cos(a))
	if sin(a) > 0.05: Input.action_press("down", sin(a))
	if sin(a) < -0.05: Input.action_press("up", -sin(a))


func _stick_off() -> void:
	for act in ["left", "right", "up", "down"]:
		Input.action_release(act)


func _go(next: String) -> void:
	phase = next
	pt = f


func _place(p, e, d: float) -> void:   # joueur à d mètres devant le bassin, tourné vers lui
	var pel: Vector3 = e.parts.pelvis.global_position
	p.global_position = Vector3(pel.x, 0, pel.z + d)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0
	p.attack = ""
	p.hurt = 0.0


func _fresh(e) -> void:
	e.global_position = Vector3(0, 0, -1.5)
	e.build()
	e.block_chance = 0.0


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	var k := f - pt
	var pel: Vector3 = e.parts.pelvis.global_position
	if e.state in ["held", "down", "crisp", "getup", "swung"]:
		for d in e.BODY:
			if d[1] != "":
				max_gap = maxf(max_gap, e.parts[d[1]].to_global(d[4] - e.rest_center[d[1]]).distance_to(e.parts[d[0]].to_global(d[4] - d[3])))
	match phase:
		"up_setup":
			if f == 20:
				_fresh(e)
			if f == 22:
				e.toss(Vector3.UP * 5.0, 0.0)   # en l'air, bas
				_go("up_wait")
		"up_wait":
			if pel.y > 1.0 and e.parts.pelvis.linear_velocity.y < 0:   # il redescend : uppercut
				_place(p, e, 0.8)
				p.start("upper")
				peak = 0.0
				_go("up_fly")
			if k > 200:
				_check(false, "ennemi en l'air pour l'uppercut")
				_go("end")
		"up_fly":
			peak = maxf(peak, pel.y)
			if k == 90:
				_check(peak > 2.0, "uppercut sur un ennemi en l'air : vrai nouveau décollage (bassin monté à %.2f m)" % peak)
				_fresh(e)
				_go("hk")
		"hk":
			if k == 20:
				p.heavy_move = "hikick"   # high kick : amélioration
				_place(p, e, 1.0)
				start = pel
				Input.action_press("heavy")
			if k == 22:
				Input.action_release("heavy")
			if p.attack == "hikick" and p.hit_done and foot_y < 0:
				foot_y = p.j.foot_r.global_position.y
				head_y = p.j.head.global_position.y
			if k == 60:
				_check(foot_y > 1.25, "high kick haut (pied à %.2f m à l'impact)" % foot_y)   # v0.213 : capture CMU 135_07
				_check(head_y < 1.6, "le buste penche à l'opposé de la jambe (ta tête à %.2f m)" % head_y)
			if k == 26:
				_check(p.attack == "hikick", "triangle au sol = high kick (%s)" % p.attack)
			if k == 110:
				var off: Vector3 = (pel - start) * Vector3(1, 0, 1)
				# le joueur regarde vers -Z ; sa gauche = -X
				_check(e.state in ["down", "dead"] or e.state == "getup", "le high kick le fait tomber (%s)" % e.state)
				_check(-off.x > 1.0 and -off.x > absf(off.z), "il part sur le côté (%.2f m de côté, %.2f m vers l'avant)" % [-off.x, -off.z])
				p.heavy_move = "spinkick"
				_fresh(e)
				foot_y = -1.0
				_go("sk")
		"sk":
			if k == 20:
				_place(p, e, 1.0)
				start = pel
				_tap("heavy")
			if k == 28:
				_check(p.attack == "spinkick", "triangle au sol = coup de pied retourné (%s)" % p.attack)
			if p.attack == "spinkick" and p.hit_done and foot_y < 0:
				foot_y = p.j.foot_r.global_position.y
				head_y = absf(angle_difference(p.j.hips.global_rotation.y, p.global_rotation.y))
			if k == 110:
				_check(foot_y > 1.3, "talon à hauteur du visage à l'impact (pied à %.2f m)" % foot_y)
				_check(head_y > deg_to_rad(140), "dos tourné à l'ennemi au moment du coup (bassin tourné de %.0f°)" % rad_to_deg(head_y))
				var back: float = -(pel - start).z
				_check(e.state in ["down", "dead"] and back > 1.5, "il est envoyé en arrière (%s, %.2f m)" % [e.state, back])
				_fresh(e)
				_go("sweep")
		"sweep":
			if k == 20:
				_place(p, e, 0.9)
				e.ai = "block"   # même en garde
				e.block_t = 5.0
				hp0 = e.hp
				Input.action_press("light")   # X maintenu = balayage retourné (de base)
				p.x_held = p.HOLD_X   # (on saute l'attente du maintien : même rythme que le reste du test)
			if k == 60:
				Input.action_release("light")
			if k == 26:
				_check(p.roll >= 0 and p.roll_kind == "sweep" and p.is_invulnerable(), "X maintenu = balayage retourné, invulnérable (%.2f)" % p.roll)
				lifted = 0.0
			if p.roll >= 0:
				lifted = minf(lifted, p.j.hips.global_position.y - 0.9)
			if e.state == "down":
				shin_top = maxf(shin_top, (e.parts.shin_l.global_position.y + e.parts.shin_r.global_position.y) * 0.5 - e.parts.head.global_position.y)
			if k == 100:
				_check(lifted < -0.3, "accroupi bas pendant le balayage (bassin descendu de %.2f m)" % -lifted)
				_check(e.state in ["down", "launch"] and e.hp < hp0, "le balayage le fauche, même en garde (%s, vie %.0f)" % [e.state, e.hp])
				_check(shin_top > 0.0, "ses jambes sont ramassées : à un moment ses tibias passent au-dessus de sa tête (%+.2f m)" % shin_top)
				lifted = 0.0
				_fresh(e)
				_go("dk")
		"dk":
			if k == 20:
				p.air_heavy = "dropkick"   # v0.216 : le gros genou est le Y aérien de base ; le chassé sauté reste en variante
				_place(p, e, 2.0)
				hp0 = e.hp
				_tap("jump")
			if k == 34:
				_tap("heavy")
			if p.attack == "air_kick" and absf(p.j.hips.global_basis.y.y) < 0.35:
				flat = true
			if k == 30 + 30 and phase == "dk":
				_check(p.attack == "air_kick" or flat, "triangle en l'air = chassé sauté (%s)" % p.attack)
			if k == 130:
				_check(flat, "le perso se met à l'horizontale, pieds en avant")
				_check(e.hp < hp0, "le chassé sauté touche (vie %.0f -> %.0f)" % [hp0, e.hp])
				_fresh(e)
				_go("collar_setup")
		"collar_setup":   # v0.217 : un sbire couché ne se chope plus par le col ; la chope par le col se teste sur un sbire debout
			if k == 20:
				e.toss(Vector3(0, 1, -1), 0.0)   # on le couche
				downed_try = -1
			if k > 30 and downed_try < 0 and pel.y < 0.5 and e.state == "down" and e.parts.pelvis.linear_velocity.length() < 0.5:
				_place(p, e, 0.8)
				p.grab_cd = 0.0
				_tap("grab")
				downed_try = k
			if downed_try > 0 and k == downed_try + 40:
				_check(p.attack != "collar", "couché : plus de chope par le col (%s)" % p.attack)
				_fresh(e)
			if downed_try > 0 and k == downed_try + 90:
				_place(p, e, 0.8)
				p.grab_cd = 0.0
				hp0 = e.hp
				_tap("grab")
				_go("collar")
			if k > 400:
				_check(false, "ennemi couché pour la chope au sol (%s, bassin %.2f)" % [e.state, pel.y])
				_go("end")
		"collar":
			if e.state == "held":
				lifted = maxf(lifted, pel.y)
			if k == 40:
				_check(e.state == "held" and p.attack == "collar", "chope au sol : attrapé par le col (%s, %s)" % [e.state, p.attack])
				_check(lifted > 0.8, "et relevé jusqu'à ta main (bassin à %.2f m)" % lifted)
			if k == 41:
				start = p.global_position
				leg0 = p.j.hip_l.quaternion
				Input.action_press("up")   # on marche en le tenant
			if k > 45 and k < 81:
				leg_swing = maxf(leg_swing, p.j.hip_l.quaternion.angle_to(leg0))
			if k == 81:
				Input.action_release("up")
				var walked: float = ((p.global_position - start) * Vector3(1, 0, 1)).length()
				var near: float = ((e.parts.chest.global_position - p.global_position) * Vector3(1, 0, 1)).length()
				_check(walked > 0.5 and e.state == "held" and near < 1.0, "on marche en le tenant par le col (%.2f m, il suit à %.2f m)" % [walked, near])
				_check(leg_swing > deg_to_rad(10), "avec l'animation de marche (cuisse qui balance de %.0f°)" % rad_to_deg(leg_swing))
			if k in [85, 115, 145]:
				_tap("light")
			if k == 200:
				_check(absf(e.hp - (hp0 - 21.0)) < 0.1, "3 droites pendant qu'il est tenu (vie %.0f -> %.0f)" % [hp0, e.hp])
				_check(e.state == "down" and pel.y > 1.0, "puis il repart en l'air (%s, bassin à %.2f m)" % [e.state, pel.y])
				_go("collar2_setup")
		"collar2_setup":
			if k == 30:
				_fresh(e)
			if k == 80:
				_place(p, e, 0.8)
				p.grab_cd = 0.0
				_tap("grab")
				_go("collar2")
			if k > 500:
				_check(false, "ennemi recouché pour la 2e chope au sol (%s)" % e.state)
				_go("end")
		"collar2":
			if k == 40:
				_check(p.attack == "collar", "rechopé par le col (%s)" % p.attack)
				_tap("grab")
				peak = 0.0
			if k == 50:
				_check(p.attack == "slam", "chope pendant qu'on le tient = fracas à deux mains (%s)" % p.attack)
			if k > 50:
				peak = maxf(peak, pel.y)
			if k == 170:
				_check(peak > 1.5, "fracassé au sol, il rebondit (bassin monté à %.2f m)" % peak)
				_fresh(e)
				_go("corpse")
		"corpse":
			if k == 20:
				e.hp = 5.0
				_place(p, e, 0.9)
				p.start("jab")   # le tue
			if k == 120:
				_check(e.state == "dead", "il est mort (%s)" % e.state)
			if k == 120 * 4:   # 4 s après sa mort : le corps est encore là, l'uppercut le relance
				_check(e.state == "dead", "4 s après sa mort, son corps est toujours là (%s)" % e.state)
				_place(p, e, 0.8)
				v_corpse = pel
				p.start("soccer_kick")   # v0.217 : plus de chope sur un corps couché ; on le shoote
				peak = 0.0
			if k > 120 * 4:
				peak = maxf(peak, ((pel - v_corpse) * Vector3(1, 0, 1)).length())
			if k == 120 * 5 + 20:
				_check(peak > 0.5, "on peut encore taper le corps : le shoot l'envoie plus loin (%.2f m)" % peak)
				_check(e.state == "dead", "chaque coup lui laisse un moment de plus avant de disparaître (%s)" % e.state)
			if k == 120 * 8:
				_check(e.state == "stand" and e.hp == e.MAX_HP, "puis un nouvel ennemi apparaît (%s)" % e.state)
				e.global_position = Vector3(30, 0, 30)
				e.build()
				_go("roll")
		"roll":
			if k == 20:
				p.global_position = Vector3.ZERO
				p.velocity = Vector3.ZERO
				p.attack = ""
				p.hurt = 0.0
				p.start("jab")
			if k > 20 and p.attack == "jab" and p.t >= p.ATK.jab.active + 0.06 and p.roll < 0 and k < 60:
				Input.action_press("roll")
			if p.roll >= 0 and Input.is_action_pressed("roll") and k < 60:
				Input.action_release("roll")
				_check(p.t < p.ATK.jab.end, "roulade juste après l'impact d'un coup, sans attendre sa fin (coup à %.2f / %.2f s)" % [p.t, p.ATK.jab.end])
			if k == 120:
				p.take_hit(Vector3.BACK, 0.0)
			if k == 120 + 30:   # 0,25 s après avoir été touché
				_tap("roll")
			if k == 120 + 36:
				_check(p.roll >= 0, "roulade possible peu après avoir été touché (%.2f)" % p.roll)
			if k == 260:
				_tap("roll")
			if k > 262 and p.roll >= 0.38 and p.roll < 0.45 and not Input.is_action_pressed("light"):
				Input.action_press("light")
			if k > 262 and Input.is_action_pressed("light") and p.roll < 0 and p.attack != "":   # v0.216 : l'attack roll part à la fin de la roulade
				Input.action_release("light")
				_check(p.attack in ["jab", "spin_counter"], "fin de roulade coupée par un coup (%s : X à la sortie = contre tournant)" % p.attack)
				_fresh(e)
				_go("swing")
			if k > 400:
				_check(false, "fin de roulade coupée par un coup (roulade %.2f, %s)" % [p.roll, p.attack])
				_go("end")
		"swing":
			if k == 20:
				p.throw_move = "swing"   # amélioration
				_place(p, e, 0.9)
				_tap("grab")   # debout : chope normale
			if k == 45:
				_check(p.attack == "collar", "avec l'amélioration, la chope debout reste normale (%s)" % p.attack)
				_tap("grab")
			if k == 52:
				_check(p.attack == "slam", "et son rappui reste le fracas (%s)" % p.attack)
			if k == 200:
				e.toss(Vector3(0, 1, -1), 0.0)
			if k == 199:
				before_swing_gap = max_gap
			if k > 210 and k < 600 and not released and p.attack == "" and pel.y < 0.5 and e.state == "down" and e.parts.pelvis.linear_velocity.length() < 0.5:
				var feet: Vector3 = (e.parts.shin_l.global_position + e.parts.shin_r.global_position) * 0.5
				p.global_position = Vector3(feet.x, 0, feet.z) + Vector3(0, 0, 0.8)
				p.velocity = Vector3.ZERO
				p.rotation.y = 0
				Input.action_press("grab")   # au sol : par les pieds ; R1 maintenu, on fait tourner au stick
				spinning = true
				spin_ang = 0.0
				released = true
				# Un 2e sbire planté à portée du grand tour : il doit se faire faucher.
				e2 = Node3D.new()
				e2.set_script(load("res://enemy.gd"))
				e2.ai_on = false
				e2.position = p.global_position + Vector3(1.7, 0, 0.3)
				main.add_child(e2)
				prev_yaw = p.rotation.y
				turned = 0.0
				max_gap = 0.0
				foot_y = 0.0
				shin_top = 0.0
			if spinning:
				spin_ang -= 0.075   # cercles au stick (~9 rad/s)
				_stick(spin_ang)
				if turned > TAU * 2.1 or k > 800:
					spinning = false
					_stick_off()
					Input.action_release("grab")   # R1 relâché : il part
			if p.attack == "swing":
				turned += absf(angle_difference(prev_yaw, p.rotation.y))
				swing_walk += Vector2(p.velocity.x, p.velocity.z).length() / 120.0
				var ankle: Vector3 = e.parts.shin_l.global_transform * Vector3(0, -0.225, 0)
				var hand: Vector3 = p.j.fist_r.global_position if p.swap_feet else p.j.fist_l.global_position
				foot_y = maxf(foot_y, ankle.distance_to(hand)) if p.t > 0.45 else foot_y   # v0.217 : prise possible de plus loin (le temps que les chevilles arrivent)
				shin_top = maxf(shin_top, e.parts.pelvis.linear_velocity.length())
				var axis: Vector3 = e.parts.head.global_position - e.parts.pelvis.global_position
				if absf(axis.normalized().y) < 0.35 and ((pel - p.global_position) * Vector3(1, 0, 1)).length() > 0.8:
					flat_seen = true
			prev_yaw = p.rotation.y
			if released and p.attack == "swing_finish" and not air_caught:
				air_caught = true
				_check(e.state != "swung", "lâché")
				hp_rel = e.hp
				_check(turned > TAU * 1.8, "au sol : attrapé par les pieds, c'est le stick qui fait tourner (%.1f tours)" % (turned / TAU))
				_check(swing_walk > 0.5, "on se déplace en le tenant (%.1f m parcourus)" % swing_walk)
				_check(foot_y < 0.25, "ses chevilles restent collées à tes mains (écart max %.2f m)" % foot_y)
				_check(e.parts.pelvis.freeze == false and shin_top > 3.0, "son corps est en ragdoll et suit le mouvement (bassin jusqu'à %.1f m/s)" % shin_top)
				_check(flat_seen, "il s'envole jusqu'à l'horizontale")
				_check(e2.state != "stand" and e2.hp < e2.MAX_HP, "son corps percute et fauche un autre ennemi au passage (%s, vie %.0f)" % [e2.state, e2.hp])
				e2.queue_free()
				start = p.global_position
				peak = 0.0
			if air_caught:
				peak = maxf(peak, ((pel - start) * Vector3(1, 0, 1)).length())
				if not land_ok and e.hp < hp_rel:
					land_ok = true
					var low := INF
					for b in e.parts.values():
						low = minf(low, b.global_position.y)
					_check(low < 0.25, "il prend le coup (dégâts, flash) en touchant le sol, pas au lâcher (corps à %.2f m du sol)" % low)
			if k == 900:
				_check(peak > 3.0, "puis il est lâché et part au loin (%.1f m)" % peak)
				_check(land_ok, "dégâts du grand tour bien reçus à l'atterrissage")
				_check(max_gap < 0.2, "articulations tenues pendant le grand tour, malgré la force centrifuge (écart max %.3f m, tolérance 0,2)" % max_gap)
				max_gap = 0.0
				_fresh(e)
				peak = 0.0
				air_caught = false
				released = false
				_go("swinghold")   # (le grand tour en l'air n'existe plus : en l'air, R1 = chope plongeante)
		"airswing":
			if k == 19:
				before_swing_gap = maxf(before_swing_gap, max_gap)
				max_gap = 0.0
			if k == 20:
				_place(p, e, 1.0)
				e.toss(Vector3.UP * 7.0, 0.0)   # en l'air, en ragdoll
				_tap("jump")
			if k > 25 and not released and not spinning and not p.is_on_floor() and p.attack == "" and pel.y > 1.2:
				Input.action_press("grab")
				spinning = true
				spin_ang = 0.0
				pt = f - 30
			if spinning:
				spin_ang -= 0.075
				_stick(spin_ang)
				if k > 30 + 80:
					spinning = false
					_stick_off()
					Input.action_release("grab")
			if p.attack == "swing" and not released:
				released = true
				_check(e.state == "swung" and pel.y > 0.8, "en l'air aussi : attrapé par les pieds en plein vol (bassin à %.2f m)" % pel.y)
			if k == 400:
				_check(released and e.state != "swung", "grand tour en l'air puis lâché (%s)" % e.state)
				_check(max_gap < 0.12, "articulations tenues pendant le grand tour en l'air (écart max %.3f m, tolérance 0,12)" % max_gap)
				max_gap = 0.0
				p.throw_move = "slam"
				_fresh(e)
				released = false
				_go("swinghold")
		"swinghold":
			if k == 10:
				p.throw_move = "swing"
				_fresh(e)
				before_swing_gap = maxf(before_swing_gap, max_gap)
				max_gap = 0.0
			if k == 20:
				e.toss(Vector3(0, 1, -1), 0.0)
			if k > 30 and not spinning and not released and pel.y < 0.5 and e.state == "down" and e.parts.pelvis.linear_velocity.length() < 0.5:
				var feet: Vector3 = (e.parts.shin_l.global_position + e.parts.shin_r.global_position) * 0.5
				p.global_position = Vector3(feet.x, 0, feet.z) + Vector3(0, 0, 0.8)
				p.velocity = Vector3.ZERO
				p.rotation.y = 0
				p.attack = ""
				Input.action_press("grab")   # R1 maintenu sans jamais le relâcher
				spinning = true
				pt = f - 1000
			if spinning and k == 1000 + 2 + int(2.7 * 120):
				_check(e.state == "swung", "tenu par les pieds pendant presque 3 s (%s)" % e.state)
			if spinning and k == 1000 + 2 + int(3.3 * 120):
				_check(e.state != "swung" and p.attack != "swing", "au bout de 3 s il est lâché tout seul, même R1 maintenu (%s)" % e.state)
				Input.action_release("grab")
				spinning = false
				_check(max_gap < 0.16, "articulations tenues pendant les 3 s de prise (écart max %.3f m, tolérance 0,16 : pic d'une image)" % max_gap)
				max_gap = 0.0
				p.throw_move = "slam"
				_fresh(e)
				released = false
				_go("airgrab")
			if k > 900 and k < 1000:
				_check(false, "ennemi couché pour le test des 3 s (%s)" % e.state)
				_go("end")
		"airgrab":   # sans l'amélioration : pas de chope en l'air
			if k == 20:
				p.air_slam = false
				_place(p, e, 1.0)
				e.toss(Vector3.UP * 7.0, 0.0)   # en l'air
				_tap("jump")
			if k > 25 and k < 120 and not p.is_on_floor() and p.attack == "" and pel.y > 1.2 and not air_caught:
				air_caught = true
				_tap("grab")
			if k == 120:
				_check(e.state != "held" and p.attack != "collar", "sans amélioration : pas de chope en l'air (%s, %s)" % [e.state, p.attack])
				_fresh(e)
				air_caught = false
				peak = 0.0
				_go("airgrab2")
		"airgrab2":   # chope plongeante : attrapé en l'air, emporté en piqué et plaqué au sol
			if k == 20:
				p.air_slam = true
				_place(p, e, 1.0)
				e.toss(Vector3.UP * 7.0, 0.0)
				_tap("jump")
				hp0 = e.hp
			if k > 25 and not air_caught and not p.is_on_floor() and p.attack == "" and pel.y > 1.2:
				_tap("grab")
			if p.attack == "air_slam" and not air_caught:
				air_caught = true
				_check(e.state == "held" and not p.is_on_floor(), "chope plongeante : attrapé en plein vol (perso à %.2f m du sol)" % p.global_position.y)
			if air_caught and p.attack == "airslam_land":
				slam_seen = true
			if slam_seen and e.state == "down":
				peak = maxf(peak, pel.y)
			if k == 260:
				_check(slam_seen and e.hp < hp0, "il pique avec lui et le plaque au sol (vie %.0f -> %.0f)" % [hp0, e.hp])
				_check(peak > 1.0, "plaqué, il rebondit (bassin monté à %.2f m)" % peak)
				p.air_slam = false
				_go("end")
		"end":
			_check(maxf(max_gap, before_swing_gap) < 0.09, "aucune articulation ne lâche (écart max %.3f m, hors grand tour, tolérance 0,09 : rebonds exagérés)" % maxf(max_gap, before_swing_gap))
			print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
			quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

extends SceneTree
## Auto-test garde + chope : godot --headless --path . -s guardcheck.gd --fixed-fps 120
## 1. Garde : il lève la garde quand tu frappes devant lui ; le combo entier ne lui enlève ni vie ni équilibre, l'uppercut ne le lance pas ;
##    tu rebondis sur sa garde ; puis il contre-attaque. Un coup de dos passe la garde.
## 2. Chope ratée (trop loin) : rien ne se passe, tu restes bloqué dans l'animation.
## 3. Chope sur sa garde : il est soulevé, fracassé au sol, rebondit haut ; saut d'annulation + coup aérien = jongle ;
##    il s'écrase, se relève en roulade, et aucune articulation ne lâche.

var main: Node3D
var f := 0
var fails := []
var phase := "start"
var pt := 0          # image de début de la phase
var blocked_seen := false
var peak := 0.0
var max_gap := 0.0
var held_top := 0.0
var regrab := false
var recoil := 0.0
var crisp_seen := 0
var spun := 0.0
var hit_y := -1.0
var after_y := 0.0
var low_y := INF


func _initialize() -> void:
	seed(3)
	main = load("res://main.tscn").instantiate()
	main.get_node("Player").air_move = "hammer"   # le jongle se termine par le marteau qui écrase (amélioration)
	main.get_node("Player").light_move = "two"   # jab + direct (le 3e coup des améliorations brise la garde : testé à part)
	root.add_child(main)


func _face(p, e, d: float) -> void:   # place le joueur à d mètres devant lui, tourné vers lui
	var fwd: Vector3 = e.root.basis.z
	p.global_position = e.root.origin + fwd * d
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(fwd.x, fwd.z)


func _tap(action: String) -> void:
	Input.action_press(action)
	var n := Engine.get_physics_frames()
	while Engine.get_physics_frames() < n + 2:   # tenu jusqu'à ce que la physique l'ait vu (même pendant un hitstop)
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
	if e.state in ["held", "down", "getup", "launch", "crisp"]:
		for d in e.BODY:
			if d[1] != "":
				max_gap = maxf(max_gap, e.parts[d[1]].to_global(d[4] - e.rest_center[d[1]]).distance_to(e.parts[d[0]].to_global(d[4] - d[3])))
	match phase:
		"start":
			if f == 20:
				e.block_chance = 1.0
				e.cooldown = 99.0
				_face(p, e, 0.95)
				_tap("light")
				_go("combo")
		"combo":
			if e.ai == "block":
				blocked_seen = true
			if k in [12, 24]:
				_tap("light")
			if k == 6:
				_check(e.ai == "block", "il lève la garde quand tu frappes devant lui (%s)" % e.ai)
			if k < 30:
				recoil = maxf(recoil, p.velocity.dot(p.global_basis.z))
			if k == 30:
				_check(recoil > 0.5, "tu rebondis sur sa garde (recul jusqu'à %.1f m/s)" % recoil)
			if k == 70:
				_check(e.hp == e.MAX_HP and e.poise == 1.0, "le combo dans sa garde : ni vie ni équilibre perdus (vie %.0f, équilibre %.2f)" % [e.hp, e.poise])
				_check(e.state == "stand", "il ne tombe pas à travers sa garde (%s)" % e.state)
			if k > 70 and e.ai == "windup":
				_check(k < 140, "puis il contre-attaque dès que tu arrêtes (%.2f s après)" % (k / 120.0))
				_go("wait_counter")
			if k > 200:
				_check(false, "il contre-attaque après sa garde (%s)" % e.ai)
				_go("wait_counter")
		"wait_counter":
			if e.ai == "circle" and k > 30:
				e.ai = "block"
				e.block_t = 0.3
				var hp0: float = e.hp
				e.hit(e.parts.chest, e.root.basis.z * 30.0, e.parts.chest.global_position, 8.0, 0.1)   # coup venant de derrière
				_check(e.hp == hp0 - 8.0, "un coup de dos passe sa garde (vie %.0f -> %.0f)" % [hp0, e.hp])
				_go("whiff")
		"whiff":
			if k == 60:
				e.cooldown = 99.0
				_face(p, e, 3.0)
				_tap("grab")
			if k == 60 + 40:
				_check(e.state == "stand" and p.attack == "grab", "chope ratée de loin : rien ne se passe, tu restes ouvert (%s, %s)" % [e.state, p.attack])
			if k == 60 + 70:
				_check(p.attack == "", "puis tu récupères (%s)" % p.attack)
				e.hp = e.MAX_HP
				e.cooldown = 99.0
				e.chain_left = 0
				e.timer = 0.0
				e.ai = "circle"
				p.hurt = 0.0   # il a pu te toucher pendant ta chope ratée
				_face(p, e, 0.95)
				_tap("light")   # il lève la garde...
				_go("grab")
		"grab":
			if k == 15:
				_check(e.ai == "block", "il est en garde (%s)" % e.ai)
				p.grab_cd = 0.0   # (le délai entre deux chopes n'est pas ce qu'on teste ici)
				_tap("grab")   # ... et la chope passe
			if e.state == "held":
				held_top = maxf(held_top, e.parts.chest.global_position.y)
			if p.attack == "hip_throw":
				regrab = true   # chope sur un ennemi en garde : projection de hanche (atelier des coups)
			if e.state == "down" and phase == "grab":
				_check(regrab, "chope sur un ennemi en garde : projection de hanche")
				_check(held_top > 1.3, "il passe par-dessus ta hanche (buste monté à %.2f m)" % held_top)
				_check(e.hp == e.MAX_HP - 18.0, "la projection fait mal (vie %.0f)" % e.hp)
				_check(e.parts.pelvis.global_position.y < 0.6, "il retombe au sol (bassin à %.2f m à l'impact)" % e.parts.pelvis.global_position.y)
				_tap("jump")   # saut d'annulation juste après l'impact
				_go("juggle")
			if k > 200 and phase == "grab":
				_check(false, "la chope finit par le fracasser au sol (%s)" % e.state)
				_go("end")
		"juggle":
			peak = maxf(peak, e.parts.pelvis.global_position.y)
			if k == 10:   # secousse d'un coup en l'air : le corps plie (membres à des vitesses différentes) sans changer de trajectoire
				var before := {}
				for n in e.parts:
					before[n] = e.parts[n].linear_velocity
				var com0: Vector3 = _spread(e)[0]
				e._jolt(e.parts.chest, Vector3(0, 0.3, -1).normalized() * 30.0, e.parts.chest.global_position + Vector3(0, 0, 0.1))
				var com1: Vector3 = _spread(e)[0]
				var bend := 0.0
				for n in e.parts:
					bend = maxf(bend, (e.parts[n].linear_velocity - before[n] - (com1 - com0)).length())
				_check(com1.distance_to(com0) < 0.05, "la secousse ne change pas sa trajectoire (écart %.3f m/s)" % com1.distance_to(com0))
				_check(bend > 2.0, "mais son corps encaisse : le buste part sous le coup (%.1f m/s de plus que le reste du corps)" % bend)
			if not p.is_on_floor() and p.velocity.y < 3.5 and p.air_hits == 0 and k < 80:
				_tap("light")   # coup aérien en montant
			if e.state == "crisp" and hit_y < 0:
				hit_y = e.parts.pelvis.global_position.y
			if hit_y > 0:
				after_y = maxf(after_y, e.parts.pelvis.global_position.y)
				low_y = minf(low_y, e.parts.pelvis.global_position.y)
			if e.state == "crisp":
				crisp_seen += 1
			elif crisp_seen > 0 and spun == 0.0 and e.state == "down":
				spun = e.parts.pelvis.angular_velocity.length()
			if k == 90:
				_check(crisp_seen > 3, "touché en l'air, il se crispe un instant (%d images figé)" % crisp_seen)
				_check(spun > 6.0, "puis repart en tournoyant (%.1f rad/s)" % spun)
				_check(peak > 1.6, "il rebondit haut (bassin monté à %.2f m)" % peak)
				_check(e.juggles >= 1, "saut + coup aérien : tu le jongles après la chope (%d coup(s) en l'air)" % e.juggles)
			if k == 140:
				_check(after_y - hit_y < 0.3 and low_y < 0.45, "le marteau l'écrase au sol sans le faire remonter (+%.2f m au plus, bassin jusqu'à %.2f m)" % [after_y - hit_y, low_y])
			if e.state == "stand" and k > 90:
				_check(true, "il s'écrase puis se relève (%.1f s après le fracas)" % (k / 120.0))
				_go("end")
			if k > 120 * 6:
				_check(false, "il se relève après le jongle (%s)" % e.state)
				_go("end")
		"end":
			_check(max_gap < 0.08, "aucune articulation ne lâche pendant la chope et le jongle (écart max %.3f m)" % max_gap)
			print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
			quit(1 if fails.size() else 0)
	return false


## [vitesse du centre de masse, écart max d'un membre par rapport à elle]
func _spread(e) -> Array:
	var v := Vector3.ZERO
	var m := 0.0
	for b in e.parts.values():
		v += b.linear_velocity * b.mass
		m += b.mass
	v /= m
	var d := 0.0
	for b in e.parts.values():
		d = maxf(d, b.linear_velocity.distance_to(v))
	return [v, d]


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

extends SceneTree
## Auto-test des nouvelles formes : godot --headless --path . -s newcheck.gd --fixed-fps 120
## Tacle glissé (fauche tout le monde sur sa ligne), strafe éclair (au sol et en l'air), double saut, plongeon (onde de choc),
## coup chargé, axe kick (écrase au sol), genou volant (décolle + enchaîne en l'air), parade (sonne), riposte critique,
## jauge de spécial (coups, garde), coup de tête dans la chope (lâché, il rebondit au sol).

var main: Node3D
var e2: Node3D
var f := 0
var fails := []
var phase := "start"
var pt := 0
var v := {}   # mesures


func _initialize() -> void:
	seed(7)
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false
	main.get_node("Player").lock_on = true   # ce test vérifie aussi l'aimantation (désactivée en jeu, code gardé)
	root.add_child(main)


func _tap(action: String, frames := 2) -> void:
	Input.action_press(action)
	var n := Engine.get_physics_frames()
	while Engine.get_physics_frames() < n + frames:
		await process_frame
	Input.action_release(action)


func _go(next: String) -> void:
	phase = next
	pt = f
	v.clear()


func _place(e, pos: Vector3, face_to: Vector3) -> void:
	e.global_position = pos
	e.build()
	var to: Vector3 = face_to - pos
	e.root.basis = Basis(Vector3.UP, atan2(to.x, to.z))
	e.block_chance = 0.0
	e.cooldown = 99.0


func _reset_p(p, pos: Vector3, look: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var to := look - pos
	p.rotation.y = atan2(-to.x, -to.z)
	p.attack = ""
	p.roll = -1.0
	p.hurt = 0.0


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	var k := f - pt
	match phase:
		"start":
			if f == 20:
				e2 = Node3D.new()
				e2.set_script(load("res://enemy.gd"))
				e2.ai_on = false
				e2.position = Vector3(0, 0, -4.2)
				main.add_child(e2)
				e2.target = p
				main.enemies.append(e2)
				_go("slide")
		"slide":   # sprint (double tap), puis X : tacle glissé qui fauche les deux sbires sur sa ligne
			if k == 10:
				p.sprint_attack = "slide"
				v.u = Vector3(0, 0, -1).rotated(Vector3.UP, main.cam.global_rotation.y)   # « haut » du stick, vu de la caméra
				_place(e, v.u * 2.6, Vector3(0, 0, 0))
				_place(e2, v.u * 4.2 + Vector3(0.1, 0, 0), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), v.u * 5.0)
			if k == 22:
				Input.action_press("up")   # double tap vers le haut = sprint
			if k == 25:
				Input.action_release("up")
			if k == 28:
				Input.action_press("up")
			if k == 30:
				v.spr = p.sprinting
				v.p0 = p.global_position
				_tap("light")   # X en sprint = tacle glissé
			if k == 31:
				Input.action_release("up")
			if k > 30 and k < 110:
				v.inv = v.get("inv", false) or p.is_invulnerable()
			if k == 110:
				var d: Vector3 = p.global_position - v.p0
				_check(v.spr, "double tap du stick : sprint")
				_check(e.state != "stand" and e2.state != "stand", "X en sprint : tacle glissé, les deux sbires sur sa ligne sont fauchés (%s, %s)" % [e.state, e2.state])
				_check(v.inv, "tacle : invulnérable au départ")
				_check(d.dot(v.u) > 2.5, "tacle : il glisse loin en ligne droite (%.2f m)" % d.dot(v.u))
				_check((d - v.u * d.dot(v.u)).length() < 0.3, "pas de courbe (écart latéral %.2f m)" % (d - v.u * d.dot(v.u)).length())
				_go("flop")
		"flop":   # sprint, puis X : plongeon pantin qui fauche les sbires
			if k == 10:
				p.sprint_attack = "flop"
				v.u = Vector3(0, 0, -1).rotated(Vector3.UP, main.cam.global_rotation.y)
				_place(e, v.u * 2.8, Vector3(0, 0, 0))
				_place(e2, v.u * 3.6 + v.u.cross(Vector3.UP) * 0.4, Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), v.u * 5.0)
			if k == 22:
				Input.action_press("up")
			if k == 25:
				Input.action_release("up")
			if k == 28:
				Input.action_press("up")
			if k == 34:
				_tap("light")
			if k == 35:
				Input.action_release("up")
			if p.attack == "flop_prep":
				v.prep = true
				v.vmax = maxf(v.get("vmax", 0.0), Vector2(p.velocity.x, p.velocity.z).length()) if p.t > 0.03 else 0.0
			if p.ragdoll_t >= 0.0:
				v.fl = true
				if e.state != "stand":
					v.h1 = true
				if e2.state != "stand":
					v.h2 = true
				v.py = maxf(v.get("py", 0.0), p.rag.hips.global_position.y)
			if p.attack == "flop_land":
				v.land = true
			if k == 450:
				_check(v.has("prep") and v.get("vmax", 9.0) < 0.5, "X en sprint : temps d'arrêt, il plie les jambes")
				_check(v.has("fl") and v.get("py", 0.0) > 0.85, "puis il se jette en avant, corps en vrai ragdoll (bassin à %.2f m)" % v.get("py", 0.0))
				_check(v.has("h1") and v.has("h2"), "son corps fauche les sbires qu'il croise (%s, %s)" % [v.has("h1"), v.has("h2")])
				_check(v.has("land") and p.attack == "", "il retombe à plat ventre puis se relève (%s)" % p.attack)
				p.sprint_attack = "none"
				_go("dash")
		"dash":
			if k == 1:
				p.dodge_move = "dash"
				_place(e, Vector3(5, 0, 5), Vector3(0, 0, 0))
				_place(e2, Vector3(-5, 0, 5), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 60:
				v.rot = p.rotation.y
				Input.action_press("right")
				_tap("roll")
			if k > 60 and k < 100:
				v.inv = v.get("inv", false) or p.is_invulnerable()
				if p.roll >= 0:
					v.turn = maxf(v.get("turn", 0.0), absf(angle_difference(p.rotation.y, v.rot)))
			if k == 100:
				Input.action_release("right")
				_check(p.global_position.x > 1.5, "strafe éclair : déplacement ultra rapide sur le côté (%.2f m en 1/3 s)" % p.global_position.x)
				_check(v.get("turn", 9.0) < 0.2, "il garde son orientation pendant le strafe (%.2f rad)" % v.get("turn", 9.0))
				_check(v.inv, "strafe : invulnérable")
				_tap("jump")
			if k == 150:
				v.x0 = p.global_position.x
				v.y0 = p.global_position.y
				Input.action_press("left")
				_tap("roll")
			if k == 175:
				Input.action_release("left")
				_check(v.y0 > 0.3 and v.x0 - p.global_position.x > 1.0, "strafe aussi en l'air (%.2f m, à %.2f m du sol)" % [v.x0 - p.global_position.x, v.y0])
			if k == 260:
				_go("djump")
		"djump":
			if k == 1:
				p.dodge_move = "roll"
				p.double_jump = true
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 10:
				_tap("jump")
			if k > 10 and k < 60:
				v.h1 = maxf(v.get("h1", 0.0), p.global_position.y)
			if k == 50:
				_tap("jump")
			if k > 50 and k < 200:
				v.h2 = maxf(v.get("h2", 0.0), p.global_position.y)
			if k == 200:
				_check(v.h2 > v.h1 + 0.4, "double saut : il remonte en l'air (%.2f m puis %.2f m)" % [v.h1, v.h2])
				p.double_jump = false
				_go("dive")
		"dive":
			if k == 1:
				p.dive = true
				_place(e, Vector3(1.4, 0, -0.5), Vector3(0, 0, 0))
				_place(e2, Vector3(-1.2, 0, 0.8), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				p.special = 0.0
			if k == 30:
				_tap("jump")
			if k == 70:
				_tap("jump")   # A en l'air : plongeon
			if k > 70 and k < 110 and p.attack == "dive":
				v.vy = minf(v.get("vy", 0.0), p.velocity.y)
			if k == 160:
				_check(v.get("vy", 0.0) < -12.0, "plongeon : piqué vers le sol (%.1f m/s)" % v.get("vy", 0.0))
				_check(e.state != "stand" and e2.state != "stand" and e.hp < e.MAX_HP, "onde de choc à l'atterrissage : les sbires autour décollent (%s, %s)" % [e.state, e2.state])
				_check(p.special > 0, "la jauge de spécial se remplit (%.0f)" % p.special)
				p.dive = false
				_go("charged")
		"charged":
			if k == 1:
				p.heavy_move = "kick"
				p.charge_move = "power"
				_place(e2, Vector3(5, 0, 5), Vector3(0, 0, 0))
				_place(e, Vector3(0, 0, -1.2), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 30:
				Input.action_press("heavy")
				Input.action_press("up")   # (pousser le stick pendant la charge ne le fait pas bouger)
			if k == 32:
				Input.action_release("up")
			if k > 60 and k < 150:
				if p.attack == "charge":
					v.mv = maxf(v.get("mv", 0.0), Vector2(p.velocity.x, p.velocity.z).length())
				else:
					v.ch = false
			if k == 31:
				v.hp0 = e.hp
			if p.attack == "kick" and not v.has("auto"):
				v.auto = Input.is_action_pressed("heavy")   # chargé au max : il part tout seul
				Input.action_release("heavy")
			if k == 260:
				_place(e, Vector3(0, 0, -1.2), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				_tap("heavy")
			if k == 266:
				_check(p.attack == "kick", "appui court sur Y : le coup lourd normal, toujours là (%s)" % p.attack)
			if k == 200:
				_check(v.get("ch", true) and v.mv < 0.5, "chassé chargé : Y maintenu, il charge sur place (vitesse max %.2f)" % v.mv)
				_check(v.get("auto", false), "chargé au max, il part tout seul (Y encore enfoncé)")
				_check(v.hp0 - e.hp > 22.0 * 1.8 and e.state != "stand", "chassé 2× plus fort, il passe la garde et met au sol (%.0f dégâts, %s)" % [v.hp0 - e.hp, e.state])
			if k == 300:
				_go("axe")
		"axe":
			if k == 1:
				p.heavy_move = "axe"
				_place(e, Vector3(0, 0, -1.4), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 20:
				_tap("heavy")
			if p.attack == "axe":
				v.top = maxf(v.get("top", 0.0), p.j.foot_r.global_position.y)
			if k > 30 and e.state != "stand":
				v.low = minf(v.get("low", 9.0), e.parts.pelvis.global_position.y)
			if k == 90:
				_check(v.get("top", 0.0) > 1.6, "axe kick : la jambe monte au-dessus de la tête (pied à %.2f m)" % v.get("top", 0.0))
				_check(e.state != "stand" and v.get("low", 9.0) < 0.5 and e.hp < e.MAX_HP, "debout, il est écrasé au sol (%s, bassin jusqu'à %.2f m)" % [e.state, v.get("low", 9.0)])
				_go("knee")
		"knee":
			if k == 1:
				p.light_move = "knee"
				_place(e, Vector3(0, 0, -1.2), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k in [30, 42, 54]:
				_tap("light")   # jab, direct, genou volant
			if p.attack == "knee":
				v.kn = true
			if k > 30:
				v.py = maxf(v.get("py", 0.0), p.global_position.y)
				v.ey = maxf(v.get("ey", 0.0), e.parts.pelvis.global_position.y)
			if p.attack == "" and k > 60 and k < 140 and not p.is_on_floor() and not v.has("air"):
				v.air = true
				_tap("light")
			if k == 160:
				_check(v.has("kn"), "genou volant en 3e coup du combo de poings")
				_check(v.py > 0.5, "genou volant : il décolle (%.2f m)" % v.py)
				p.light_move = "base"
				_check(v.ey > 1.3, "et l'ennemi part en l'air avec lui (bassin à %.2f m)" % v.ey)
				_check(e.juggles >= 1, "enchaîné en aérien après le genou (%d coup(s) en l'air)" % e.juggles)
				_go("shoryu")
		"shoryu":
			if k == 1:
				p.heavy_move = "kick"
				p.charge_move = "shoryu"
				_place(e, Vector3(0, 0, -1.1), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 30:
				Input.action_press("heavy")   # Y maintenu : il se ramasse
			if p.attack == "shoryu" and not v.has("rel"):
				v.rel = k   # chargé au max : il part tout seul, sans relâcher
				v.still = Input.is_action_pressed("heavy")
			if v.has("rel") and k == v.rel + 4:
				v.inv = p.is_invulnerable()
				Input.action_release("heavy")
			if k > 30:
				v.py = maxf(v.get("py", 0.0), p.global_position.y)
				v.ey = maxf(v.get("ey", 0.0), e.parts.pelvis.global_position.y)
			if p.sho_hold:
				v.held = v.get("held", 0) + 1
				if v.held > 18:   # passé le court raccord du début (il est ramené jusqu'au poing)
					v.gap = maxf(v.get("gap", 0.0), p.j.fist_r.global_position.distance_to(e.parts.head.global_position))
			if v.get("held", 0) > 0 and not p.sho_hold and not v.has("air") and not p.is_on_floor():
				v.air = true
				_tap("light")   # enchaînement aérien dès qu'il est lâché
			if k == 290:
				_check(v.get("held", 0) > 10 and v.get("gap", 9.0) < 0.6, "l'ennemi monte collé au poing (%d images, poing-tête au plus %.2f m)" % [v.get("held", 0), v.get("gap", 9.0)])
				_check(e.juggles >= 1, "lâché en ragdoll au sommet : on enchaîne en aérien (%d coup(s) en l'air)" % e.juggles)
				_check(v.get("still", false), "chargé au max, le shoryuken part tout seul (Y encore enfoncé)")
				_check(v.inv, "shoryuken : invulnérable au départ")
				_check(v.py > 1.0, "il jaillit vers le haut (%.2f m)" % v.py)
				_check(v.ey > 2.0 and e.hp < e.MAX_HP, "et l'ennemi part très haut (bassin à %.2f m)" % v.ey)
				_go("hadoken")
		"hadoken":
			if k == 1:
				p.charge_move = "hadoken"
				_place(e, Vector3(0, 0, -5.0), Vector3(0, 0, 0))
				_place(e2, Vector3(0.4, 0, -3.0), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 30:
				Input.action_press("heavy")   # la boule se charge dans ses mains
			if k == 100:
				_check(p.orb != null and p.orb.scale.x < 1.0, "la boule grossit dans ses mains pendant la charge")
				Input.action_release("heavy")   # relâché tôt : une petite boule
			if k == 116:
				var small = null
				for c in main.get_children():
					if c.get_script() and str(c.get_script().resource_path).ends_with("energy_ball.gd"):
						small = c
				_check(small != null and small.scale_base < 0.8, "relâchée tôt : une boule plus petite et plus faible (taille %.2f)" % (small.scale_base if small else 0.0))
			if k == 200:
				_place(e, Vector3(0, 0, -5.0), Vector3(0, 0, 0))
				_place(e2, Vector3(0.4, 0, -3.0), Vector3(0, 0, 0))
				Input.action_press("heavy")   # gardé enfoncé : au max, elle part toute seule
			if k == 200 + int((0.18 + 1.05) * 120):
				Input.action_release("heavy")
			if k == 380:
				var balls := 0
				for c in main.get_children():
					if c.get_script() and str(c.get_script().resource_path).ends_with("energy_ball.gd"):
						balls += 1
				_check(balls == 1, "boule d'énergie lancée (%d)" % balls)
			if k == 470:
				_check(e.hp < e.MAX_HP and e.state != "stand" and e2.hp < e2.MAX_HP and e2.state != "stand", "chargée au max : elle balaie les deux sbires sur sa ligne, à 3 et 5 m (%s, %s)" % [e2.state, e.state])
				p.charge_move = "none"
				_go("quake")
		"quake":
			if k == 1:
				p.heavy_move = "quake"
				_place(e, Vector3(1.3, 0, -0.8), Vector3(0, 0, 0))
				_place(e2, Vector3(-1.2, 0, 0.9), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 30:
				_tap("heavy")
			if k > 30:
				v.py = maxf(v.get("py", 0.0), p.global_position.y)
			if k == 120:
				_check(v.py < 0.05, "frappe au sol : il ne saute pas (%.2f m)" % v.py)
				_check(e.state != "stand" and e2.state != "stand" and e.hp < e.MAX_HP, "le poing dans le sol fait décoller les sbires autour (%s, %s)" % [e.state, e2.state])
				p.heavy_move = "kick"
				_go("rollcancel")
		"rollcancel":   # roulade vers l'avant, puis tout de suite un coup vers l'arrière (stick tiré) : il se retourne et touche
			if k == 1:
				p.dodge_move = "roll"
				_place(e2, Vector3(8, 0, 8), Vector3(0, 0, 0))
				_place(e, Vector3(0, 0, 0.9), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 20:
				Input.action_press("up")
				_tap("roll")
			if k == 28:
				Input.action_release("up")
				Input.action_press("down")
				_tap("light")
			if p.attack != "" and not v.has("at"):
				v.at = k
			if k == 90:
				Input.action_release("down")
				_check(v.has("at") and v.at - 20 < 30, "roulade coupée tôt par un coup (%.2f s après le départ)" % ((v.get("at", 999) - 20) / 120.0))
				_check(e.hp < e.MAX_HP, "le coup part derrière, là où pousse le stick, et touche (vie %.0f)" % e.hp)
				_go("parry")
		"parry":
			if k == 1:
				p.parry = true
				p.riposte = true
				p.guard_gauge = true
				p.special = 0.0
				_place(e, Vector3(0, 0, -1.1), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				e.ai_on = true
				e.cooldown = 0.0
			if e.ai == "strike" and not v.has("g") and e.ai_t >= 0.0:
				v.g = true
				Input.action_press("guard")   # garde levée pile au dernier moment
			if e.ai == "stunned":
				v.st = true
				Input.action_release("guard")
				if not v.has("rip"):
					v.rip = true
					v.hp0 = e.hp
					_tap("heavy")
			if k == 240:
				Input.action_release("guard")
				_check(v.has("st"), "parade au dernier moment : l'ennemi est sonné")
				_check(p.hp == 100.0, "parade : aucun dégât (vie %.0f)" % p.hp)
				_check(v.has("hp0") and v.hp0 - e.hp >= 40.0, "riposte juste après : coup critique (%.0f dégâts)" % (v.hp0 - e.hp if v.has("hp0") else 0.0))
				_check(p.special > 15.0, "parade et coups remplissent la jauge (%.0f)" % p.special)
				_go("block")
		"block":
			if k == 1:
				p.parry = false
				p.special = 0.0
				p.hp = 100.0
				_place(e, Vector3(0, 0, -1.1), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				e.ai_on = false
				Input.action_press("guard")
			if k == 30:
				p.take_hit(Vector3(0, 0, 1), 5.0, e)
			if k == 40:
				Input.action_release("guard")
				_check(p.special > 0 and p.hp == 100.0, "garde : le coup paré remplit la jauge (%.0f)" % p.special)
				p.guard_gauge = false
				_go("airrecover")
		"airrecover":   # lancé, il se rattrape en l'air : pas de garde ni d'immunité tant qu'il est en l'air
			if k == 1:
				_place(e, Vector3(0, 0, -1.5), Vector3(0, 0, 0))
				e.block_chance = 1.0
			if k == 10:
				e.hit(e.parts.chest, Vector3(0, 1.2, -0.3).normalized() * 50.0, e.parts.chest.global_position, 10.0, 1.0)
			if not v.has("hit") and e.state == "getup" and e.blend_kind == "land" and e.parts.pelvis.global_position.y > 0.6:
				var hp0: float = e.hp
				var blocked: bool = e.hit(e.parts.chest, Vector3(0, 0.9, -1).normalized() * 25.0, e.parts.chest.global_position, 6.0, 0.3)
				v.hit = true
				_check(not blocked and e.hp < hp0, "touché pendant qu'il se rattrape en l'air : ni garde ni immunité, le coup compte (%s)" % e.state)
			if k == 300:
				_check(v.has("hit"), "il s'est bien rattrapé en l'air pendant le test")
				e.block_chance = 0.0
				_go("divekick")
		"divekick":   # en l'air, Y maintenu : piqué en diagonale, dans la direction du saut, il touche un sbire couché
			if k == 1:
				_place(e, Vector3(0, 0, -1.7), Vector3(0, 0, 0))
				e.toss(Vector3(0, 0.5, 0), 0.0)
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 120:
				v.yaw = p.rotation.y
				_tap("jump")
			if k == 150:
				Input.action_press("heavy")   # Y maintenu en l'air
			if k == 190:
				Input.action_release("heavy")
			if p.attack == "dive_kick":
				v.dk = true
				v.turn = maxf(v.get("turn", 0.0), absf(angle_difference(p.rotation.y, v.yaw)))
			if e.state == "down" or e.state == "crisp":
				v.top = maxf(v.get("top", 0.0), e.parts.pelvis.global_position.y) if k > 150 else 0.0
			if k == 260:
				_check(v.has("dk"), "Y maintenu en l'air : coup de pied en piqué")
				_check(v.get("turn", 9.0) < 0.2, "il garde la direction du saut (%.2f rad)" % v.get("turn", 9.0))
				_check(e.hp < e.MAX_HP and v.get("top", 0.0) > 1.0, "il touche le sbire couché et le fait rebondir en l'air (bassin à %.2f m, vie %.0f)" % [v.get("top", 0.0), e.hp])
				_go("headbutt")
		"headbutt":
			if k == 1:
				_place(e, Vector3(0, 0, -0.9), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 20:
				_tap("grab")
			if k == 70:
				_check(p.attack == "collar" and e.state == "held", "chope par le col (%s, %s)" % [p.attack, e.state])
				_tap("heavy")
			if k > 70 and p.attack == "headbutt" and p.hit_done and not v.has("rel"):
				v.rel = true
				_check(e.state == "down", "coup de tête : il le lâche au moment de l'impact (%s)" % e.state)
			if v.has("rel"):
				var y: float = e.parts.pelvis.global_position.y
				if not v.has("low") and e.land_bounce == 0.0:
					v.low = true
				if v.has("low"):
					v.up = maxf(v.get("up", 0.0), e.parts.pelvis.linear_velocity.y)
			if k == 220:
				_check(v.get("up", 0.0) > 3.0, "et il rebondit au sol (remonte à %.1f m/s)" % v.get("up", 0.0))
				_go("grabcd")
		"grabcd":   # chope ratée puis rechope aussitôt : bloquée par le délai
			if k == 1:
				_place(e, Vector3(5, 0, 5), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				p.grab_cd = 0.0
			if k == 10:
				_tap("grab")
			if k == 75:
				_tap("grab")
			if k == 80:
				_check(p.attack != "grab", "chope : pas de spam, un délai avant la suivante (%s)" % p.attack)
			if k == 140:
				_tap("grab")
			if k == 145:
				_check(p.attack == "grab", "après le délai, la chope repart (%s)" % p.attack)
				_go("sweepcd")
		"sweepcd":   # X maintenu = balayage ; martelé, il n'est jamais relancé avant la fin de sa rotation ; puis 3 tours avec l'amélioration
			if k == 1:
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				p.sweep_cd = 0.0
			if k == 4:
				_tap("light")   # appui court : jab, pas de balayage
			if k == 8:
				_check(p.attack == "jab" and p.roll < 0, "appui court sur X : jab (%s)" % p.attack)
			if k in [12, 50]:
				Input.action_press("light")   # maintenu
			if k in [45, 56]:
				Input.action_release("light")
			if p.roll >= 0 and p.roll_kind == "sweep":
				if p.roll < v.get("last", 0.0) - 0.01:
					v.restart = v.get("restart", 0) + 1
				v.last = p.roll
				v.s1 = v.get("s1", 0) + 1
			if k == 100:
				_check(v.get("s1", 0) > 20, "X maintenu : balayage retourné")
				_check(not v.has("restart"), "réappuyé aussitôt : le balayage n'est jamais relancé avant la fin de sa rotation (%d relance(s))" % v.get("restart", 0))
				p.sweep_triple = true
				p.sweep_cd = 0.0
				v.erase("last")
				v.s3 = 0
			if k == 130:
				Input.action_press("light")
			if k == 170:
				Input.action_release("light")
			if k > 120 and p.roll >= 0 and p.roll_kind == "sweep":
				v.s3 += 1
			if k == 300:
				_check(v.s3 > 100, "amélioration : balayage triple, 3 tours (%.2f s au lieu de 0,45 s)" % (v.s3 / 120.0))
				p.sweep_triple = false
				_go("free")
		"free":   # sans aimantation : on ne se tourne pas vers l'ennemi, mais chaque coup avance dans la direction où on se déplace
			if k == 1:
				p.lock_on = false
				_place(e, Vector3(1.0, 0, -1.0), Vector3(0, 0, 0))   # à 45° sur le côté
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				v.rot = p.rotation.y
			if k == 10:
				_tap("light")
			if k == 40:
				_check(absf(angle_difference(p.rotation.y, v.rot)) < 0.05 and e.hp == e.MAX_HP, "sans aimantation : le jab ne se tourne pas vers l'ennemi de côté (vie %.0f)" % e.hp)
				_place(e, Vector3(0, 0, -5), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 60:
				v.p0 = p.global_position
				Input.action_press("up")
			if k == 62:
				_tap("heavy")   # (le jab, lui, ne fait plus avancer : v0.21)
			if k == 64:
				Input.action_release("up")
				v.vm = 0.0
			if k > 64 and k < 80:
				v.vm = maxf(v.vm, Vector2(p.velocity.x, p.velocity.z).length())
			if k == 90:
				_check(v.vm > 2.5, "en se déplaçant : le coup lourd donne une petite avancée (élan jusqu'à %.1f m/s)" % v.vm)
				p.lock_on = true
				_go("props")
		"props":   # chope sur un objet du décor : soulevé, fracassé au sol (zone) ; jeté (X) ; en grand tour
			if k == 1:
				_reset_p(p, Vector3(0, 0, 0.2), Vector3(0, 0, -5))
				_place(e, Vector3(0.2, 0, -2.0), Vector3(0, 0, 0))
			if k == 10:
				p.lock_on = false
				p.grab_cd = 0.0
				var b := RigidBody3D.new()
				var cs := CollisionShape3D.new()
				cs.shape = BoxShape3D.new()
				cs.shape.size = Vector3(0.7, 0.7, 0.7)
				b.add_child(cs)
				b.collision_layer = 1
				b.collision_mask = 1 | 4 | 8
				b.add_to_group("reactive")
				b.set_meta("kind", "crate")
				main.add_child(b)
				b.global_position = Vector3(0, 0.35, -0.8)
				v.box = b
				_place(e, Vector3(0.2, 0, -2.0), Vector3(0, 0, 0))
				_place(e2, Vector3(20, 0, 20), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0.2), Vector3(0, 0, -5))
			if k == 30:
				_tap("grab")
			if k == 60:
				_check(p.attack == "prop_hold" and p.held_prop == v.box, "chope près d'une caisse : il la soulève au-dessus de sa tête (%s)" % p.attack)
				_check(v.box.global_position.y > 1.6, "la caisse est au-dessus de sa tête (%.2f m)" % v.box.global_position.y)
				_tap("grab")   # rappui : lancée droit devant
			if k == 120:
				_check(p.held_prop == null and not v.box.freeze, "rappui sur R1 : la caisse est lancée")
				_check(e.state != "stand" and e.hp < e.MAX_HP, "lancée droit devant, elle percute l'ennemi (%s, vie %.0f)" % [e.state, e.hp])
				_place(e, Vector3(0.1, 0, -4.0), Vector3(0, 0, 0))
				v.box.global_position = Vector3(0, 0.35, -0.8)
				v.box.linear_velocity = Vector3.ZERO
				_reset_p(p, Vector3(0, 0, 0.2), Vector3(0, 0, -5))
				p.grab_cd = 0.0
			if k == 200:
				_tap("grab")
			if k == 230:
				_tap("heavy")   # Y : coup de chaise (l'objet reste en main)
			if k == 250:
				_check(p.attack in ["prop_bash", "prop_hold"] and p.held_prop == v.box, "Y avec l'objet : coup de chaise, il le garde en main (%s)" % p.attack)
			if k == 300:
				_tap("grab")   # R1 : jetée devant
			if k == 360:
				_check(e.state != "stand" and e.hp < e.MAX_HP, "R1 : la caisse jetée percute l'ennemi à 4 m (%s, vie %.0f)" % [e.state, e.hp])
				p.throw_move = "swing"
				_place(e, Vector3(1.4, 0, 0.0), Vector3(0, 0, 0))
				v.box.global_position = Vector3(0, 0.35, -0.8)
				v.box.linear_velocity = Vector3.ZERO
				v.box.angular_velocity = Vector3.ZERO
				_reset_p(p, Vector3(0, 0, 0.2), Vector3(0, 0, -5))
				p.grab_cd = 0.0
			if k == 400:
				Input.action_press("grab")   # grand tour avec la caisse
			if k == 420:
				_check(p.attack == "prop_swing", "grand tour : il fait tourner la caisse au bout de ses bras (%s)" % p.attack)
			if k == 560:
				Input.action_release("grab")
			if k == 620:
				_check(e.state != "stand" and e.hp < e.MAX_HP, "la caisse en grand tour fauche l'ennemi (%s, vie %.0f)" % [e.state, e.hp])
				p.throw_move = "slam"
				p.lock_on = true
				v.box.queue_free()
				_go("slamhit")
		"slamhit":   # chope de base : fracassé au sol, il percute l'autre sbire qui est là
			if k == 1:
				p.grab_cd = 0.0
				_place(e, Vector3(0, 0, -0.9), Vector3(0, 0, 0))
				_place(e2, Vector3(0.3, 0, -1.9), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 10:
				_tap("grab")
			if k == 50:
				_tap("grab")   # rappui : fracas
			if k == 150:
				_check(e2.state != "stand" and e2.hp < e2.MAX_HP, "fracassé au sol, son corps percute l'autre sbire (%s, vie %.0f)" % [e2.state, e2.hp])
				_place(e2, Vector3(20, 0, 20), Vector3(0, 0, 0))
				_go("guardbreak")
		"guardbreak":   # le 3e coup du combo (uppercut, crochet, genou) brise la garde
			if k == 1:
				p.light_move = "hook"
				_place(e, Vector3(0, 0, -1.0), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				e.block_chance = 1.0
				e.ai_on = true
				e.cooldown = 99.0
			if k in [10, 22, 34]:
				_tap("light")
			if k == 16:
				v.blk = e.ai == "block"
			if k == 28:
				v.hp1 = e.hp
			if k == 100:
				_check(v.get("blk", false) and v.hp1 == e.MAX_HP, "jab et direct : bloqués par sa garde")
				_check(e.hp < e.MAX_HP and e.state != "stand", "le crochet (3e coup) brise la garde (%s, vie %.0f)" % [e.state, e.hp])
				e.block_chance = 0.0
				e.ai_on = false
				p.light_move = "base"
				_go("escape")
		"escape":   # chopé debout : il se dégage vite ; chopé au sol (ragdoll) : on le garde bien plus longtemps
			if k == 1:
				p.grab_cd = 0.0
				_place(e, Vector3(0, 0, -0.9), Vector3(0, 0, 0))
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
			if k == 10:
				_tap("grab")
			if e.state == "held":
				v.h1 = v.get("h1", 0) + 1
			if k == 400:
				_check(v.get("h1", 0) > 140 and v.get("h1", 0) < 215, "chopé debout : il se libère au bout d'environ 1,5 s (%.2f s)" % (v.get("h1", 0) / 120.0))
				_check(e.state == "stand", "et il retombe directement sur ses pieds (%s)" % e.state)
				_place(e, Vector3(0, 0, -1.0), Vector3(0, 0, 0))
				e.toss(Vector3(0, 0.5, 0), 0.0)
				_reset_p(p, Vector3(0, 0, 0), Vector3(0, 0, -5))
				p.grab_cd = 0.0
			if k == 500:
				_tap("grab")
			if k > 500 and e.state == "held":
				v.h2 = v.get("h2", 0) + 1
			if k == 1100:
				_check(v.get("h2", 0) > 400, "chopé en ragdoll : on le garde bien plus longtemps (%.2f s)" % (v.get("h2", 0) / 120.0))
				print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
				quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

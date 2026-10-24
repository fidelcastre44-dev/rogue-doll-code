extends SceneTree
## Tests automatiques du proto (sans écran) : godot --headless --path . -s tests/check.gd
## Chaque test met en place une situation, simule la manette image par image et vérifie le résultat. Fin : « RESULTAT: OK ».

var game: Node
var inp: Node
var fails := []
var log_lines := []


func _initialize() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()


func wait(n := 1) -> void:
	for i in n:
		await physics_frame
		for a in ["attack", "jump", "dodge", "grab"]:
			if inp.held(a) and inp.held_time(a) > 0.02 and not _hold.has(a):
				inp.release(a)
		if inp.held("heavy") and inp.held_time("heavy") > 0.02 and not _hold.has("heavy"):
			inp.release("heavy")

var _hold := {}


func tap(a: String, then := 1) -> void:
	inp.press(a)
	await wait(then)


func hold(a: String) -> void:
	_hold[a] = true
	inp.press(a)


func let_go(a: String) -> void:
	_hold.erase(a)
	inp.release(a)


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		print("  ÉCHEC  ", what)
		fails.append(what)


func setup(spot := "centre", n := 1, mode := "passive", gap := 1.6) -> void:
	_hold.clear()
	inp.pressed_at.clear()
	inp.held_since.clear()
	inp.fake_stick = Vector2.ZERO
	game.foe_count = n
	game.foe_mode = mode
	game.load_spot(spot)
	if spot == "centre":
		game.hero.global_position = game.enemies[0].global_position + Vector3(0, 0, gap)
	game.hero.assist = 0.65
	await wait(10)


func foe(i := 0) -> Node:
	return game.enemies[i]


func _run() -> void:
	await physics_frame
	inp = root.get_node("Inputs")
	inp.use_fake = true
	Engine.time_scale = 1.0
	await t_move()
	await t_combo()
	await t_buffer()
	await t_launch_air()
	await t_dodge()
	await t_parry_block()
	await t_grab()
	await t_wall()
	await t_charge()
	await t_guard_break()
	await t_slide_and_dash()
	await t_perfect()
	await t_ai()
	await t_grab_slam()
	await t_grab_escape()
	await t_weapons()
	await t_climb()
	await t_wallrun()
	await t_camera()
	await t_v113()
	await t_v114()
	print("")
	if fails.is_empty():
		print("RESULTAT: OK")
	else:
		print("RESULTAT: ÉCHEC (%d) : %s" % [fails.size(), ", ".join(fails)])
	quit()


# ------------------------------------------------------------------

func t_move() -> void:
	print("déplacement")
	await setup("centre", 1)
	game.hero.global_position = Vector3(0, 0.05, 10)
	await wait(5)
	inp.fake_stick = Vector2(1, 0)
	await wait(6)
	var sp: float = Vector2(game.hero.hvel.x, game.hero.hvel.z).length()
	ok(sp > game.hero.RUN * 0.9, "pleine vitesse en 6 images (%.2f m/s)" % sp)
	inp.fake_stick = Vector2(-1, 0)
	await wait(6)
	ok(game.hero.hvel.x < -game.hero.RUN * 0.6, "demi-tour net en 6 images (vx %.2f)" % game.hero.hvel.x)
	ok(game.hero.facing.x < -0.9, "le héros regarde dans la nouvelle direction")
	inp.fake_stick = Vector2.ZERO
	await wait(6)
	ok(Vector2(game.hero.hvel.x, game.hero.hvel.z).length() < 0.2, "arrêt en 6 images")
	inp.sprint_tap = false
	hold("sprint")
	inp.fake_stick = Vector2(1, 0)
	await wait(20)
	ok(game.hero.hvel.length() > game.hero.SPRINT * 0.9, "sprint (%.2f m/s)" % game.hero.hvel.length())
	let_go("sprint")
	inp.fake_stick = Vector2.ZERO
	await wait(10)
	await tap("jump", 20)
	ok(game.hero.global_position.y > 1.0, "saut (%.2f m)" % game.hero.global_position.y)
	await wait(40)
	ok(game.hero.state == "move", "réception")


func t_combo() -> void:
	print("enchaînement X")
	await setup("centre", 1)
	var hp0: float = foe().hp
	for i in 4:
		await tap("attack", 14)
	await wait(30)
	ok(game.hero.combo >= 4 or foe().hp <= hp0 - 25, "4 coups touchent (combo %d, PV %d -> %d)" % [game.hero.combo, hp0, foe().hp])
	ok(foe().state in ["air", "down"], "le coup retourné renverse (%s)" % foe().state)
	await wait(100)
	ok(foe().state in ["getup", "idle"], "il se relève (%s)" % foe().state)


func t_buffer() -> void:
	print("tampon d'entrées")
	await setup("centre", 1)
	await tap("attack", 2)     # jab
	await tap("attack", 1)     # appuyé très tôt (image 3) : doit quand même enchaîner le direct
	var seen := false
	for i in 30:
		await wait(1)
		if game.hero.move_id == "cross":
			seen = true
	ok(seen, "appui en avance gardé : le direct part")
	await setup("centre", 1)
	await tap("attack", 40)   # jab seul, fini
	ok(game.hero.state == "move", "pas d'enchaînement fantôme")


func t_launch_air() -> void:
	print("lanceur + combo aérien")
	await setup("centre", 1)
	await tap("attack", 7)
	await tap("heavy", 1)
	var launched := false
	for i in 30:
		await wait(1)
		if foe().state == "air" and foe().global_position.y > 0.4:
			launched = true
		if game.hero.has_hit and game.hero.move_id == "launcher" and game.hero.phase() == "recovery":
			break
	ok(launched, "l'uppercut envoie en l'air")
	await tap("jump", 6)
	ok(game.hero.state in ["air", "attack"] and game.hero.global_position.y > 0.2, "saut d'annulation")
	var maxy := 0.0
	for k in 3:
		await tap("attack", 11)
		maxy = maxf(maxy, foe().global_position.y)
	ok(foe().state == "air", "le mannequin reste en l'air pendant le combo aérien (y %.2f)" % foe().global_position.y)
	ok(game.hero.combo >= 4, "combo aérien compté (%d)" % game.hero.combo)
	await tap("heavy", 40)
	ok(foe().state in ["down", "air", "getup"], "piqué : écrasé au sol (%s)" % foe().state)
	await wait(60)


func t_dodge() -> void:
	print("esquive")
	await setup("centre", 1, "passive", 1.3)
	var e := foe()
	e.facing = (game.hero.global_position - e.global_position).normalized()
	e._start_attack("light")
	await wait(int(e.atk.windup) - 8)
	inp.fake_stick = Vector2(1, 0)
	await tap("dodge", 1)
	inp.fake_stick = Vector2.ZERO
	var hp0: float = game.hero.hp
	await wait(30)
	ok(game.hero.hp == hp0, "invincible pendant la roulade")
	await setup("centre", 1)
	await wait(50)
	await tap("dodge", 3)
	await wait(22)
	await tap("dodge", 3)
	await wait(22)
	await tap("dodge", 3)
	ok(game.hero.state != "dodge", "3e esquive d'affilée refusée (rien n'est spammable)")
	await wait(40)
	await tap("dodge", 3)
	ok(game.hero.state == "dodge", "après la recharge, l'esquive revient")


func t_parry_block() -> void:
	print("garde / parade")
	await setup("centre", 1, "passive", 1.2)
	var e := foe()
	e.facing = (game.hero.global_position - e.global_position).normalized()
	game.hero.facing = -e.facing
	e._start_attack("light")
	await wait(int(e.atk.windup) - 4)
	hold("guard")
	await wait(12)
	ok(e.state == "stagger", "parade : le mannequin titube (%s)" % e.state)
	ok(game.hero.riposte_t > 0.0, "riposte disponible")
	await tap("attack", 30)
	ok(e.state == "air", "riposte : il part en l'air (%s)" % e.state)
	let_go("guard")
	await wait(80)
	await setup("centre", 1, "passive", 1.2)
	e = foe()
	e.facing = (game.hero.global_position - e.global_position).normalized()
	game.hero.facing = -e.facing
	hold("guard")
	await wait(20)
	var hp0: float = game.hero.hp
	e._start_attack("light")
	await wait(int(e.atk.windup) + 6)
	ok(game.hero.hp == hp0 and e.state != "stagger", "garde tenue : bloqué sans parade")
	let_go("guard")


func t_grab() -> void:
	print("chope + lancer")
	await setup("centre", 3, "passive", 1.0)
	# deux mannequins alignés derrière le premier : il les renverse en étant lancé
	# v0.114 : projection d'épaule : il retombe dans le sens du stick (le héros lui tourne le dos)
	foe(1).reset_at(foe(0).global_position + Vector3(0, 0, -2.5), Vector3(0, 0, 1))
	foe(2).reset_at(foe(0).global_position + Vector3(0, 0, -4.0), Vector3(0, 0, 1))
	game.hero.facing = Vector3(0, 0, -1)
	await tap("grab", 10)
	ok(foe(0).state == "grabbed", "attrapé (%s)" % foe(0).state)
	await wait(90)
	ok(foe(0).state == "grabbed", "toujours tenu après 1,5 s (%s)" % foe(0).state)
	inp.fake_stick = Vector2(0, -1)
	await tap("grab", 60)
	inp.fake_stick = Vector2.ZERO
	ok(foe(0).state == "air", "R1 : projection d'épaule puis lancé (%s)" % foe(0).state)
	await wait(30)
	ok(foe(1).state in ["air", "down"] or foe(2).state in ["air", "down"], "il renverse les autres (boule de bowling)")
	await wait(60)


func t_wall() -> void:
	print("écrasé contre le mur")
	await setup("mur", 1)
	game.hero.global_position = foe().global_position - Vector3(1.4, 0, 0)
	game.hero.facing = Vector3(1, 0, 0)
	var splat := false
	await tap("heavy", 22)
	await tap("heavy", 1)
	for i in 50:
		await wait(1)
		if foe().state == "splat":
			splat = true
	ok(splat, "le gros crochet l'écrase contre le mur")


func t_charge() -> void:
	print("coup chargé")
	await setup("centre", 1, "passive", 2.2)
	var hp0: float = foe().hp
	hold("heavy")
	await wait(50)
	ok(game.hero.state == "charge", "Y maintenu = charge (%s)" % game.hero.state)
	let_go("heavy")
	await wait(30)
	ok(hp0 - foe().hp >= 18, "le coup chargé fait mal (%d)" % (hp0 - foe().hp))
	await wait(80)


func t_guard_break() -> void:
	print("garde ennemie")
	await setup("centre", 1, "guard", 1.4)
	var hp0: float = foe().hp
	await tap("attack", 20)
	ok(foe().hp == hp0, "le jab est bloqué")
	await wait(20)
	await tap("heavy", 30)
	ok(foe().state == "stagger", "le coup de pied brise la garde (%s)" % foe().state)
	await wait(80)


func t_slide_and_dash() -> void:
	print("attaques de roulade")
	await setup("centre", 1, "passive", 4.5)
	await tap("dodge", 12)
	await tap("attack", 30)
	ok(game.hero.has_hit and game.hero.move_id == "dash_punch", "roulade + X : direct plongeant qui touche")
	await setup("centre", 1, "passive", 6.5)
	await tap("dodge", 12)
	await tap("heavy", 40)
	ok(game.hero.move_id == "slide" and game.hero.has_hit, "roulade + Y : glissade qui fauche")
	await wait(60)


func t_perfect() -> void:
	print("esquive parfaite")
	await setup("centre", 1, "passive", 1.3)
	var e := foe()
	e.facing = (game.hero.global_position - e.global_position).normalized()
	e._start_attack("light")
	await wait(int(e.atk.windup) - 6)
	inp.fake_stick = Vector2(1, 0)
	await tap("dodge", 2)
	inp.fake_stick = Vector2.ZERO
	ok(game.hero.perfect_t > 0.0, "esquive au dernier moment = parfaite")
	Engine.time_scale = 1.0
	game._slow_t = 0.0
	await wait(40)


func t_ai() -> void:
	print("mannequins qui attaquent")
	await setup("foule", 6, "attack")
	var max_att := 0
	var hits := 0
	var h0: int = game.hero.hurt_count
	for i in 600:
		await wait(1)
		var n := 0
		for e in game.enemies:
			if e.state in ["windup", "strike"]:
				n += 1
		max_att = maxi(max_att, n)
	ok(max_att >= 1, "ils attaquent")
	ok(max_att <= game.MAX_ATTACKERS, "jamais plus de %d à la fois (%d)" % [game.MAX_ATTACKERS, max_att])
	ok(game.hero.hurt_count > h0, "le héros se fait toucher s'il ne fait rien (%d coups)" % (game.hero.hurt_count - h0))



# ------------------------------------------------------------------ v0.112

func t_grab_slam() -> void:
	print("chope : l'éclater au sol")
	await setup("centre", 1, "passive", 1.0)
	game.hero.facing = Vector3(0, 0, -1)
	await tap("grab", 10)
	ok(foe().state == "grabbed", "attrapé")
	await wait(50)
	var hp0: float = foe().hp
	await tap("heavy", 1)
	var max_y := -1.0
	var landed := false
	for i in 100:
		await wait(1)
		if foe().slammed_by == null and foe().state == "air":
			landed = true
		if landed:
			max_y = maxf(max_y, foe().global_position.y)
	ok(landed, "écrasé au sol")
	ok(max_y > 0.8, "il rebondit haut, jonglable (%.2f m)" % max_y)
	ok(foe().hp < hp0 - 10.0, "ça fait mal (%d)" % int(hp0 - foe().hp))
	ok(game.hero.state != "grab", "le héros peut agir après l'impact (%s)" % game.hero.state)


func t_grab_escape() -> void:
	print("chope : il se dégage après 3 s")
	await setup("centre", 1, "passive", 1.0)
	game.hero.facing = Vector3(0, 0, -1)
	await tap("grab", 10)
	await wait(45)
	await tap("attack", 20)
	ok(foe().hp < foe().HP_MAX, "X pendant la chope : coups")
	await wait(120)
	ok(foe().state != "grabbed", "après 3 s il se dégage (%s)" % foe().state)


func t_weapons() -> void:
	print("armes")
	await setup("armes", 1, "passive")
	var rk: Dictionary = game.arena.racks["sword"]
	game.hero.global_position = rk.at + Vector3(0, 0.05, -0.3)
	await wait(5)
	await tap("grab", 4)
	ok(game.hero.weapon == "sword", "RB devant le mur : l'épée en main (%s)" % game.hero.weapon)
	ok(not game.arena.racks["sword"].node.visible, "le crochet est vide")
	await tap("grab", 4)
	ok(game.hero.weapon == "", "RB devant son crochet : raccrochée")
	for id in Weapons.ORDER:
		await setup("centre", 1, "passive", 1.3)
		game.set_weapon(id)
		game.hero.facing = Vector3(0, 0, -1)
		var hp0: float = foe().hp
		await tap("attack", 40)
		ok(foe().hp < hp0, "%s : X touche avec la lame (%d)" % [id, int(hp0 - foe().hp)])
		await setup("centre", 1, "passive", 1.3)
		game.hero.facing = Vector3(0, 0, -1)
		hp0 = foe().hp
		await tap("heavy", 50)
		ok(foe().hp < hp0, "%s : Y touche (%d)" % [id, int(hp0 - foe().hp)])
	await setup("centre", 1, "passive", 1.2)
	game.set_weapon("sword")
	game.hero.facing = Vector3(0, 0, -1)
	for i in 3:
		await tap("attack", 14)
	await wait(30)
	ok(game.hero.combo >= 3 or foe().state in ["air", "down"], "épée : X X X enchaîne (combo %d, %s)" % [game.hero.combo, foe().state])
	game.set_weapon("")


func t_climb() -> void:
	print("rebords")
	await setup("parcours", 1, "passive")
	# rebord de 1 m (x 20.5) : on saute dessus en poussant vers lui -> enjambe
	game.hero.global_position = Vector3(20.5, 0.05, 7.6)
	await wait(4)
	inp.fake_stick = Vector2(0, -1)
	await tap("jump", 18)
	inp.fake_stick = Vector2.ZERO
	await wait(30)
	ok(game.hero.global_position.y > 0.9, "1 m : il enjambe et se retrouve dessus (y %.2f)" % game.hero.global_position.y)
	# rebord de 2,4 m (x 26.5) : agrippé puis A = se hisser
	game.hero.global_position = Vector3(26.5, 0.05, 7.0)
	game.hero.state = "move"
	await wait(6)
	inp.fake_stick = Vector2(0, -1)
	await tap("jump", 1)
	var hung := false
	for i in 40:
		await wait(1)
		if game.hero.state == "hang":
			hung = true
			break
	inp.fake_stick = Vector2.ZERO
	ok(hung, "2,4 m : il s'agrippe (%s)" % game.hero.state)
	await wait(12)
	inp.fake_stick = Vector2(1, 0)
	var x0: float = game.hero.global_position.x
	await wait(20)
	inp.fake_stick = Vector2.ZERO
	ok(game.hero.state == "hang" and game.hero.global_position.x > x0 + 0.2, "il se déplace le long du rebord (%.2f m)" % (game.hero.global_position.x - x0))
	await tap("jump", 80)
	ok(game.hero.global_position.y > 2.3 and game.hero.state == "move", "A : il se hisse en haut (y %.2f, %s)" % [game.hero.global_position.y, game.hero.state])
	# rebord de 3,2 m : saut puis agrippe
	game.hero.global_position = Vector3(29.5, 0.05, 7.0)
	game.hero.state = "move"
	await wait(6)
	inp.fake_stick = Vector2(0, -1)
	await tap("jump", 1)
	hung = false
	for i in 50:
		await wait(1)
		if game.hero.state == "hang":
			hung = true
			break
	inp.fake_stick = Vector2.ZERO
	ok(hung, "3,2 m : saut + agrippe (%s)" % game.hero.state)
	await tap("dodge", 30)
	ok(game.hero.state in ["move", "air"], "B : il lâche (%s)" % game.hero.state)


func t_wallrun() -> void:
	print("course au mur")
	await setup("parcours", 1, "passive")
	game.hero.global_position = Vector3(22.9, 0.05, 33.0)
	game.hero.facing = Vector3(0, 0, -1)
	inp.fake_stick = Vector2(0, -1)
	await wait(30)
	await tap("jump", 1)
	var ran := false
	var n1 := Vector3.ZERO
	for i in 30:
		await wait(1)
		if game.hero.state == "wallrun":
			ran = true
			n1 = game.hero.wall_n
			break
	ok(ran, "sauter le long du mur = courir dessus (%s)" % game.hero.state)
	await wait(12)
	ok(game.hero.state == "wallrun" and game.hero.global_position.y > 0.6, "il reste sur le mur (y %.2f)" % game.hero.global_position.y)
	await tap("jump", 1)
	var other := false
	for i in 45:
		await wait(1)
		if game.hero.state == "wallrun" and game.hero.wall_n.dot(n1) < -0.5:
			other = true
			break
	ok(other, "A : saut de mur, il reprend la course sur le mur d'en face (%s)" % game.hero.state)
	inp.fake_stick = Vector2.ZERO
	await wait(90)
	ok(game.hero.state in ["move", "air"], "fin de course : il retombe (%s)" % game.hero.state)


func t_camera() -> void:
	print("caméra")
	await setup("centre", 1)
	game.set_cam("yaw", 90.0)
	var p0: Vector3 = game.hero.global_position
	inp.fake_stick = Vector2(0, -1)
	await wait(20)
	inp.fake_stick = Vector2.ZERO
	var d: Vector3 = game.hero.global_position - p0
	ok(absf(d.x) > absf(d.z) * 3.0, "rotation 90° : « haut » suit la caméra (%.1f, %.1f)" % [d.x, d.z])
	game.set_cam("yaw", 0.0)
	game.set_cam("pitch", 40.0)
	game.set_cam("zoom", 1.0)



# ------------------------------------------------------------------ v0.113

func t_v113() -> void:
	print("v0.113")
	# saut de poursuite aussi haut que l'ennemi envoyé en l'air
	await setup("centre", 1)
	await tap("attack", 7)
	await tap("heavy", 1)
	for i in 30:
		await wait(1)
		if game.hero.has_hit and game.hero.move_id == "launcher" and game.hero.phase() == "recovery":
			break
	await tap("jump", 1)
	var top_e := 0.0
	var top_h := 0.0
	for i in 50:
		await wait(1)
		top_e = maxf(top_e, foe().global_position.y)
		top_h = maxf(top_h, game.hero.global_position.y)
	ok(top_h > top_e - 0.9 and top_h > 1.8, "saut de poursuite : héros %.2f m, ennemi %.2f m" % [top_h, top_e])
	await wait(60)
	# combo aérien : jab puis coups de pied latéraux (animations Mixamo)
	ok(str(Moves.M.air_cross.anim).contains("side_kick") and str(Moves.M.air_kick.anim).contains("stomp"), "combo aérien : jab, pied latéral, talon qui écrase")
	# chope : on marche en le tenant
	await setup("centre", 1, "passive", 1.0)
	game.hero.facing = Vector3(0, 0, -1)
	await tap("grab", 10)
	var p0: Vector3 = game.hero.global_position
	inp.fake_stick = Vector2(1, 0)
	await wait(70)
	ok(foe().state == "grabbed" and (game.hero.global_position - p0).length() > 1.0, "on marche en tenant l'ennemi (%.2f m)" % (game.hero.global_position - p0).length())
	ok(game.hero.rig.current == "walk" and game.hero.rig.overlay_anim.contains("choke_lift"), "il marche, le bras levé de la prise (%s)" % game.hero.rig.current)
	inp.fake_stick = Vector2.ZERO
	await tap("dodge", 30)
	# réactions variées des ennemis + réaction physique partielle
	await setup("centre", 1, "passive", 1.2)
	game.hero.facing = Vector3(0, 0, -1)
	var anims := {}
	var reacted := false
	for k in 4:
		await tap("attack", 3)
		for i in 10:
			await wait(1)
			if foe().state == "hurt":
				anims[foe().rig.current] = true
			if foe().rag.reacting:
				reacted = true
		await wait(26)
	ok(anims.size() >= 2, "réactions variées (%s)" % ", ".join(anims.keys()))
	ok(reacted, "réaction physique partielle (buste, tête, bras)")
	# esquive en garde : directionnelle, le héros reste face à l'ennemi
	await setup("centre", 1, "passive", 2.0)
	game.hero.facing = Vector3(0, 0, -1)
	hold("guard")
	await wait(6)
	inp.fake_stick = Vector2(1, 0)
	await tap("dodge", 8)
	ok(game.hero.state == "dodge" and game.hero.facing.dot(Vector3(0, 0, -1)) > 0.9 and game.hero.rig.current.contains("dodge_"), "esquive en garde : de côté, toujours face à l'ennemi (%s)" % game.hero.rig.current)
	inp.fake_stick = Vector2.ZERO
	let_go("guard")
	await wait(30)
	# course au mur affaiblie
	await setup("parcours", 1, "passive")
	game.hero.global_position = Vector3(22.9, 0.05, 33.0)
	game.hero.facing = Vector3(0, 0, -1)
	inp.fake_stick = Vector2(0, -1)
	await wait(30)
	await tap("jump", 1)
	var wr := 0
	for i in 120:
		await wait(1)
		if game.hero.state == "wallrun":
			wr += 1
	inp.fake_stick = Vector2.ZERO
	ok(wr > 10 and wr <= int(game.hero.WR_MAX * 60) + 2, "course au mur courte (%d images)" % wr)
	# franchir un muret en courant
	await setup("centre", 1, "passive")
	game.hero.global_position = Vector3(-14, 0.05, 9.5)
	game.hero.facing = Vector3(0, 0, -1)
	inp.fake_stick = Vector2(0, -1)
	var vaulted := false
	for i in 80:
		await wait(1)
		if game.hero.state == "climb" and game.hero.climb_kind == "vault":
			vaulted = true
	inp.fake_stick = Vector2.ZERO
	ok(vaulted and game.hero.global_position.z < 5.5, "muret franchi en courant (z %.2f)" % game.hero.global_position.z)
	# monter en courant sur le bloc de 3,2 m
	await setup("parcours", 1, "passive")
	game.hero.global_position = Vector3(29.5, 0.05, 11.0)
	game.hero.facing = Vector3(0, 0, -1)
	inp.fake_stick = Vector2(0, -1)
	await wait(28)
	await tap("jump", 1)
	var ran_up := false
	for i in 80:
		await wait(1)
		if game.hero.state == "climb" and game.hero.climb_kind == "runup":
			ran_up = true
			inp.fake_stick = Vector2.ZERO
	inp.fake_stick = Vector2.ZERO
	await wait(10)
	ok(ran_up and game.hero.global_position.y > 3.0, "mur de 3,2 m monté en courant (y %.2f)" % game.hero.global_position.y)
	# aperçu des animations Mixamo
	ok(game._mx_names().size() >= 120, "%d animations Mixamo dans le jeu" % game._mx_names().size())


func t_v114() -> void:
	print("v0.114")
	# coups : l'animation va dans le sens de l'effet
	ok(str(Moves.M.air_kick.anim).contains("stomp") and str(Moves.M.launcher.anim).contains("uppercut") and str(Moves.M.hook.anim).contains("elbow"), "coups : nouvelles animations (talon, uppercut, coude)")
	ok(Moves.SWEEP.get("ka_c", 0) == -1 and Moves.SWEEP.get("ka_a", 0) == 1, "sens du geste noté pour les réactions")
	# réactions : la tête part dans le sens du geste
	await setup("centre", 1, "passive", 1.0)
	var picks := {}
	for i in 6:
		picks[foe()._pick_hit_anim(-foe().facing, {"dmg": 4, "box": [1, 1.4, 0.5], "sweep": 1})] = true
	ok(picks.keys().all(func(a): return a in Dummy.HIT_ANIMS.front_high_r), "geste vers sa droite : réaction « droite » (%s)" % str(picks.keys()))
	# chope : il pend en ragdoll, la tête dans la main du héros
	game.hero.facing = Vector3(0, 0, -1)
	await tap("grab", 10)
	await wait(60)
	var d_head: float = foe().rag.head_pos().distance_to(game.hero.grip_point())
	ok(foe().state == "grabbed" and foe().rag.active and d_head < 0.35, "tenu à bout de bras, il pend en ragdoll (tête à %.2f m de la main)" % d_head)
	# Y : animation à deux (le sbire joue la victime de « Hell Slammer »)
	await tap("heavy", 4)
	ok(foe().state == "paired" and foe().rig.current == "mx/grab__hell_slammer_b" and game.hero.rig.current == "mx/grab__hell_slammer_a", "Y : animation à deux (%s / %s)" % [foe().rig.current, game.hero.rig.current])
	await wait(100)
	# ragdoll : la capsule ne suit jamais le corps
	await setup("centre", 1, "passive", 1.6)
	game.hero.facing = Vector3(0, 0, -1)
	await tap("attack", 10)
	await tap("attack", 10)
	await tap("attack", 10)
	await tap("attack", 1)
	var down_seen := false
	var drift := 0.0
	var p_down := Vector3.ZERO
	for i in 120:
		await wait(1)
		if foe().state == "down" and foe().f >= 14:
			if not down_seen:
				down_seen = true
				p_down = foe().global_position
			drift = maxf(drift, Vector2(foe().global_position.x - p_down.x, foe().global_position.z - p_down.z).length())
	ok(down_seen and drift < 0.05, "au sol : la capsule ne bouge pas avec le ragdoll (%.3f m)" % drift)
	ok(foe().fall_up, "poussé vers l'arrière : il se relèvera sur le dos")
	# course au mur : pas au ras du sol
	ok(game.hero.WR_MIN_H >= 0.7, "course au mur : seulement à partir de %.1f m" % game.hero.WR_MIN_H)

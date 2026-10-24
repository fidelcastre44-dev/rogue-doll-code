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
	foe(1).reset_at(foe(0).global_position + Vector3(0, 0, -2.5), Vector3(0, 0, 1))
	foe(2).reset_at(foe(0).global_position + Vector3(0, 0, -4.0), Vector3(0, 0, 1))
	game.hero.facing = Vector3(0, 0, -1)
	await tap("grab", 10)
	ok(foe(0).state == "grabbed", "attrapé (%s)" % foe(0).state)
	await wait(30)
	ok(foe(0).state == "air", "lancé (%s)" % foe(0).state)
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

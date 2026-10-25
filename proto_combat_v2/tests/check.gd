extends SceneTree
## Tests automatiques du proto v2 (sans écran) : godot --headless --path . -s tests/check.gd
## Chaque test met en place une situation, simule la manette image par image (commandes fausses) et vérifie la simulation.
## Fin : « RESULTAT: OK ». Un seul fichier pour la 1re livraison ; à découper par système quand il grossit.

var game: Node
var w: SimWorld
var inp: Node
var fails := []
var hits := []           # événements hit_result du dernier bloc
var held := {}


func _initialize() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	_run.call_deferred()


func hero() -> Fighter:
	return w.players[0]


func foe(i := 0) -> Fighter:
	return w.foes[i]


func wait(n := 1) -> void:
	for i in n:
		await physics_frame
		for b in held.keys():
			if held[b] >= 0:
				held[b] -= 1
				if held[b] < 0:
					inp.fake[0]["held"] &= ~InputSource.BIT[b]
					held.erase(b)


func tap(b: String, then := 1) -> void:
	inp.fake[0]["press"] |= InputSource.BIT[b]
	inp.fake[0]["held"] |= InputSource.BIT[b]
	held[b] = 1
	await wait(then)


func hold(b: String) -> void:
	inp.fake[0]["press"] |= InputSource.BIT[b]
	inp.fake[0]["held"] |= InputSource.BIT[b]
	held.erase(b)


func let_go(b: String) -> void:
	inp.fake[0]["held"] &= ~InputSource.BIT[b]
	held.erase(b)


func stick(v: Vector2) -> void:
	inp.fake[0]["stick"] = v


func ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		print("  ÉCHEC  ", what)
		fails.append(what)


func setup(spot := "centre", n := 1, mode := "passive", gap := 1.6) -> void:
	held.clear()
	inp.fake[0] = {"stick": Vector2.ZERO, "press": 0, "held": 0}
	w.set_foe_mode(mode)
	w.load_spot(spot, n if spot == "centre" and n != 1 else -1)
	if spot == "centre" and n == 1:
		hero().global_position = foe().global_position + Vector3(0, 0, gap)
	hits = []
	await wait(8)


func _on_events(events: Array) -> void:
	for e in events:
		if e.type == "hit_result":
			hits.append(e)


func landed(res := "hit") -> int:
	return hits.filter(func(e): return e.result == res and e.who == hero().id).size()


func _run() -> void:
	await physics_frame
	w = game.world
	inp = root.get_node("Inputs")
	w.stepped.connect(_on_events)
	var only := OS.get_environment("TESTS")
	for t in ["move", "jump", "roll", "combo", "launch_air", "heavy", "hold_moves", "sprint_moves", "guard_parry", "dodge_perfect", "grab", "foes", "ko", "two_players"]:
		if only == "" or t in only.split(","):
			await call("t_" + t)
	print("")
	if fails.is_empty():
		print("RESULTAT: OK")
	else:
		print("RESULTAT: %d ÉCHEC(S)" % fails.size())
		for f in fails:
			print("   - ", f)
	quit()


# ------------------------------------------------------------------ déplacement
func t_move() -> void:
	print("\n[déplacement]")
	await setup("vide", 0)
	var p0 := hero().global_position
	stick(Vector2(1, 0))
	await wait(6)
	ok(hero().hvel.length() > Tuning.v("run_speed") - 0.3, "pleine vitesse de course en 6 images (%.1f m/s)" % hero().hvel.length())
	ok(hero().facing.dot(Vector3(1, 0, 0)) > 0.95, "il regarde dans le sens du stick")
	await wait(30)
	ok(hero().state == "sprint" or hero().hvel.length() > 7.0, "stick à fond 0,3 s = sprint (%.1f m/s, %s)" % [hero().hvel.length(), hero().state])
	stick(Vector2.ZERO)
	await wait(7)
	ok(hero().hvel.length() < 0.6, "arrêt en 6 images (%.2f m/s)" % hero().hvel.length())
	stick(Vector2(-1, 0))
	await wait(6)
	ok(hero().facing.dot(Vector3(-1, 0, 0)) > 0.9, "demi-tour en ~5 images")
	stick(Vector2(0.3, 0))
	await wait(12)
	ok(hero().hvel.length() < 3.2 and hero().hvel.length() > 1.5, "stick à moitié = marche (%.1f m/s)" % hero().hvel.length())
	stick(Vector2.ZERO)
	await wait(10)


func t_jump() -> void:
	print("\n[saut]")
	await setup("vide", 0)
	await tap("jump")
	var top := 0.0
	for i in 70:
		await wait()
		top = maxf(top, hero().global_position.y)
	ok(top > 1.2 and top < 1.7, "hauteur du saut ~1,4 m (%.2f)" % top)
	ok(hero().state in ["idle", "land"], "retombé (%s)" % hero().state)
	await tap("jump")
	await wait(14)
	await tap("jump")
	top = 0.0
	for i in 80:
		await wait()
		top = maxf(top, hero().global_position.y)
	ok(top > 1.9, "double saut plus haut (%.2f)" % top)
	await wait(5)
	await tap("jump")
	await wait(10)
	var p0 := hero().global_position
	await tap("dodge")
	await wait(16)
	ok(hero().global_position.distance_to(p0) > 2.4, "dash aérien ~3,4 m (%.1f)" % hero().global_position.distance_to(p0))
	await wait(60)


func t_roll() -> void:
	print("\n[roulade]")
	await setup("vide", 0)
	var p0 := hero().global_position
	stick(Vector2(1, 0))
	await tap("dodge")
	stick(Vector2.ZERO)
	ok(hero().state == "roll", "roulade")
	await wait(5)
	ok(hero().invincible, "invincible pendant la roulade")
	await wait(16)
	var d := hero().global_position.distance_to(p0)
	ok(d > 3.0 and d < 4.5, "distance de roulade ~3,7 m (%.1f)" % d)
	ok(hero().state != "roll", "roulade finie en 20 images (%s)" % hero().state)
	await tap("dodge")
	await wait(2)
	ok(hero().state != "roll", "pas deux roulades d'affilée")
	await wait(30)
	# attaque de roulade
	await setup("centre", 1, "passive", 3.0)
	stick(Vector2(0, -1))
	await tap("dodge")
	stick(Vector2.ZERO)
	await wait(12)
	await tap("attack")
	await wait(2)
	ok(hero().move_id == "dash_punch", "roulade + X = direct plongeant (%s)" % hero().move_id)
	await wait(30)
	ok(landed() >= 1, "le direct plongeant touche")
	await setup("centre", 1, "passive", 3.0)
	stick(Vector2(0, -1))
	await tap("dodge")
	stick(Vector2.ZERO)
	await wait(12)
	await tap("heavy")
	await wait(2)
	ok(hero().move_id == "slide", "roulade + Y = glissade (%s)" % hero().move_id)
	await wait(40)
	ok(foe().state == "air_hit" or foe().velocity.y > 0 or foe().juggle >= 0 and landed() >= 1, "la glissade touche et envoie en l'air (%s)" % foe().state)
	await wait(60)


# ------------------------------------------------------------------ combat
func t_combo() -> void:
	print("\n[combo X]")
	await setup()
	await tap("attack")
	ok(hero().state == "attack" and hero().move_id == "jab", "X = jab")
	await wait(6)
	ok(hero().move_phase() == "active", "actif à l'image 6 (f%d)" % hero().f)
	await wait(10)
	ok(foe().hp < foe().hp_max, "le jab touche")
	ok(foe().freeze > 0 or hits.size() > 0, "figé à l'impact")
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "cross", "X → direct (%s)" % hero().move_id)
	await wait(14)
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "elbow", "X → coude (%s)" % hero().move_id)
	await wait(16)
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "spin_kick", "X → coup de pied retourné (%s)" % hero().move_id)
	await wait(40)
	ok(foe().state in ["air_hit", "down", "getup"], "le retourné renverse (%s)" % foe().state)
	ok(landed() == 4, "4 coups ont touché (%d)" % landed())
	await wait(120)
	ok(foe().state == "idle", "le sbire s'est relevé (%s)" % foe().state)
	# tampon : appui 6 images avant la fin
	await setup()
	await tap("attack")
	await wait(6)
	await tap("attack")
	await wait(14)
	ok(hero().move_id == "cross", "appui en avance gardé en tampon (%s)" % hero().move_id)
	await wait(60)


func t_launch_air() -> void:
	print("\n[lanceur et combo aérien]")
	await setup()
	await tap("attack")
	await wait(8)
	await tap("heavy")
	await wait(6)
	ok(hero().move_id == "push_kick", "Y après un seul jab = coup de pied poussé (%s)" % hero().move_id)
	await setup()
	await tap("attack")
	await wait(8)
	await tap("attack")
	await wait(8)
	await tap("heavy")
	await wait(6)
	ok(hero().move_id == "launcher", "Y après 2 X = uppercut lanceur (%s)" % hero().move_id)
	await wait(12)
	ok(foe().state == "air_hit" and foe().velocity.y > 3.0, "le sbire est envoyé en l'air (%s vy %.1f)" % [foe().state, foe().velocity.y])
	ok(hero().brain.pursuit_win > 0, "saut de poursuite ouvert")
	await tap("jump")
	await wait(2)
	ok(hero().state == "air", "A annule le lanceur en saut")
	await wait(6)
	await tap("attack")
	await wait(2)
	ok(hero().move_id == "air_jab", "X en l'air = jab aérien")
	await wait(10)
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "air_kick", "X → pied latéral aérien (%s)" % hero().move_id)
	await wait(10)
	await tap("heavy")
	await wait(3)
	ok(hero().move_id == "air_knee", "Y en l'air → gros genou (%s)" % hero().move_id)
	await wait(14)
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "air_jab", "genou → jab aérien (enchaînable)")
	await wait(12)
	await tap("attack")
	await wait(12)
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "air_heel", "→ talon qui écrase (%s)" % hero().move_id)
	await wait(50)
	ok(landed() >= 5, "jongle : %d coups ont touché" % landed())
	ok(foe().state in ["air_hit", "down", "getup"] , "le sbire retombe (%s)" % foe().state)
	await wait(150)


func t_heavy() -> void:
	print("\n[Y : coup de pied poussé, gros crochet, chargé]")
	await setup()
	await tap("heavy")
	await wait(20)
	ok(hero().move_id == "push_kick" and foe().state == "stagger", "coup de pied poussé : recule en titubant (%s)" % foe().state)
	await tap("heavy")
	await wait(6)
	ok(hero().move_id == "haymaker", "Y → gros crochet (%s)" % hero().move_id)
	await wait(40)
	ok(foe().state in ["air_hit", "down"], "le gros crochet renverse (%s)" % foe().state)
	await wait(150)
	await setup()
	hold("heavy")
	await wait(30)
	ok(hero().state == "charge", "Y maintenu = charge (%s)" % hero().state)
	let_go("heavy")
	await wait(4)
	ok(hero().move_id == "charged", "relâché = coup chargé (%s)" % hero().move_id)
	await wait(30)
	ok(foe().state in ["air_hit", "down"] and landed() >= 1, "le coup chargé renverse")
	await wait(150)


func t_hold_moves() -> void:
	print("\n[coups maintenus]")
	await setup()
	hold("attack")
	await wait(16)
	ok(hero().move_id == "sweep", "X maintenu pendant le jab → balayette (%s)" % hero().move_id)
	let_go("attack")
	await wait(30)
	ok(foe().state in ["air_hit", "down"], "la balayette fait tomber (%s)" % foe().state)
	await wait(130)
	await setup()
	await tap("jump")
	await wait(8)
	hold("heavy")
	await wait(16)
	ok(hero().move_id == "dive_kick", "Y maintenu en l'air → coup de pied plongeant (%s)" % hero().move_id)
	let_go("heavy")
	await wait(60)
	ok(hero().state in ["land", "idle"], "retombé après le plongeant (%s)" % hero().state)
	await wait(80)


func t_sprint_moves() -> void:
	print("\n[sprint + X / Y]")
	await setup("centre", 1, "passive", 6.0)
	stick(Vector2(0, -1))
	hold("sprint")
	await wait(14)
	ok(hero().state == "sprint", "L3 = sprint (%s)" % hero().state)
	await tap("attack")
	let_go("sprint")
	stick(Vector2.ZERO)
	await wait(2)
	ok(hero().move_id == "slide_kick", "sprint + X = coup de pied glissé (%s)" % hero().move_id)
	await wait(45)
	ok(landed() >= 1 and foe().state in ["air_hit", "down", "getup"], "le glissé fait tomber (%s)" % foe().state)
	await wait(120)
	await setup("centre", 1, "passive", 6.0)
	stick(Vector2(0, -1))
	hold("sprint")
	await wait(14)
	await tap("heavy")
	let_go("sprint")
	stick(Vector2.ZERO)
	await wait(2)
	ok(hero().move_id == "big_kick", "sprint + Y = gros coup de pied (%s)" % hero().move_id)
	await wait(50)
	ok(landed() >= 1, "le gros coup de pied touche")
	await wait(120)


func t_guard_parry() -> void:
	print("\n[garde, parade, riposte]")
	await setup("centre", 1, "passive", 1.4)
	var d := foe()
	hold("guard")
	await wait(12)
	ok(hero().state == "guard", "L1 = garde (%s)" % hero().state)
	var hp0 := hero().hp
	d.start_move("e_cross")
	await wait(30)
	ok(hero().hp == hp0, "coup bloqué de face (vie %.0f)" % hero().hp)
	ok(hits.filter(func(e): return e.result == "block").size() == 1, "résultat « block »")
	d.start_move("e_hook")
	await wait(40)
	ok(hero().state == "stagger" or hero().hp < hp0, "le gros crochet brise la garde (%s)" % hero().state)
	let_go("guard")
	await wait(60)
	# parade : L1 dans les 8 images avant le coup
	await setup("centre", 1, "passive", 1.4)
	d = foe()
	d.start_move("e_cross")
	await wait(int(Moves.M.e_cross.startup) - 4)
	hold("guard")
	await wait(8)
	ok(d.state == "stagger" and hits.filter(func(e): return e.result == "parry").size() == 1, "parade réussie : le sbire est étourdi (%s)" % d.state)
	ok(hero().brain.riposte_win > 0, "riposte ouverte")
	await tap("attack")
	await wait(3)
	ok(hero().move_id == "riposte", "X après la parade = riposte (%s)" % hero().move_id)
	await wait(20)
	ok(d.state == "air_hit" and d.velocity.y > 5.0, "la riposte envoie en l'air")
	let_go("guard")
	await wait(150)


func t_dodge_perfect() -> void:
	print("\n[esquive parfaite]")
	await setup("centre", 1, "passive", 1.4)
	var d := foe()
	d.start_move("e_cross")
	await wait(int(Moves.M.e_cross.startup) - 5)
	ok(hero().brain.dodge_ok_win > 0, "fenêtre d'esquive parfaite ouverte")
	stick(Vector2(1, 0))
	await tap("dodge")
	stick(Vector2.ZERO)
	await wait(2)
	ok(hero().crit_next and hero().slow > 0, "esquive parfaite : ralenti + prochain coup critique")
	await wait(40)
	ok(hero().hp == hero().hp_max, "pas touché pendant la roulade")
	await wait(30)


func t_grab() -> void:
	print("\n[chope]")
	await setup("centre", 1, "passive", 1.2)
	var d := foe()
	if OS.get_environment("DBG") != "":
		for i in 8:
			print("   dbg ", hero().state, " ", hero().global_position, " hv ", hero().hvel, " lunge ", hero().lunge_left, " foe ", d.global_position, " ", d.state)
			await wait()
	await tap("grab")
	await wait(9)
	ok(hero().state == "hold" and d.state == "held", "RB près d'un sbire = prise (%s / %s, dist %.2f, phase %s)" % [hero().state, d.state, hero().global_position.distance_to(d.global_position), hero().brain.grab_phase])
	await wait(60)
	ok(hero().brain.grab_phase == "hold", "tenu")
	var hp0 := d.hp
	await tap("attack")
	await wait(4)
	ok(d.hp < hp0, "X = coups pendant le tenu")
	await tap("grab")
	await wait(2)
	ok(hero().brain.grab_phase == "slam", "RB = slam")
	await wait(int((Moves.GRAB.slam.impact - Moves.GRAB.slam["from"]) / Moves.GRAB.slam.speed * 60.0) + 3)
	ok(d.state == "air_hit" or d.state == "down", "impact : il s'écrase (%s)" % d.state)
	ok(d.hp < hp0 - Tuning.v("grab_slam_dmg") + 1, "dégâts du slam")
	await wait(200)
	ok(d.state == "idle", "il s'est relevé (%s)" % d.state)
	# chope ratée
	await setup("centre", 1, "passive", 4.0)
	await tap("grab")
	await wait(10)
	ok(hero().brain.grab_phase == "whiff", "chope dans le vide = récupération")
	await wait(30)
	ok(hero().state == "idle", "fin de la récupération")
	# dégagement après 3 s
	await setup("centre", 1, "passive", 1.2)
	await tap("grab")
	await wait(int(Tuning.v("grab_hold_max")) + 70)
	ok(hero().state in ["stagger", "idle"] and foe().state != "held", "il se dégage au bout de 3 s (%s / %s)" % [hero().state, foe().state])
	await wait(40)


func t_foes() -> void:
	print("\n[sbires attaquants]")
	await setup("foule", 5, "attack")
	var attacks := 0
	var simul := 0
	for i in 400:
		await wait()
		var n := 0
		for d in w.foes:
			if d.state == "attack":
				n += 1
		simul = maxi(simul, n)
		attacks += hits.filter(func(e): return e.who != hero().id).size()
		hits = []
	ok(attacks > 0, "les sbires attaquent (%d coups)" % attacks)
	ok(simul <= Tuning.vi("foe_attackers_max"), "au plus %d attaquants à la fois (%d)" % [Tuning.vi("foe_attackers_max"), simul])
	ok(hero().hp < hero().hp_max, "le héros a pris des dégâts (%.0f)" % hero().hp)
	w.set_foe_mode("passive")
	await setup("centre", 1, "guard", 1.4)
	await tap("attack")
	await wait(14)
	ok(foe().hp == foe().hp_max and hits.filter(func(e): return e.result == "block").size() >= 1, "le sbire en garde bloque le jab")
	await wait(20)
	await tap("heavy")
	await wait(30)
	ok(foe().state == "stagger" or foe().hp < foe().hp_max, "le coup de pied poussé brise sa garde (%s)" % foe().state)
	w.set_foe_mode("passive")
	await wait(60)


func t_ko() -> void:
	print("\n[K.O. et relevé frappable]")
	await setup()
	var d := foe()
	d.hp = 3.0
	await tap("attack")
	await wait(12)
	ok(d.ko and d.state in ["air_hit", "down"], "K.O. : il tombe (%s)" % d.state)
	await wait(300)
	ok(not d.ko and d.hp == d.hp_max and d.state == "idle", "remis à neuf après le relevé (%s %.0f)" % [d.state, d.hp])
	# relevé frappable : un coup pendant le relevé l'interrompt
	await setup()
	d = foe()
	await tap("heavy")
	await wait(4)
	await tap("heavy")
	for i in 200:
		await wait()
		if d.state == "down":
			break
	ok(d.state in ["down", "getup"], "au sol (%s)" % d.state)
	while d.state == "down":
		await wait()
	ok(d.state == "getup", "il se relève")
	hero().global_position = d.global_position + Vector3(0, 0, 1.3)
	hero().facing = Vector3(0, 0, -1)
	await wait(6)
	await tap("attack")
	await wait(14)
	ok(d.state != "getup" and landed() >= 1, "coup pendant le relevé : il est touché (%s)" % d.state)
	await wait(200)


func t_two_players() -> void:
	print("\n[deux joueurs]")
	await setup()
	game._toggle_p2()
	await wait(2)
	ok(w.players.size() == 2, "2e joueur ajouté")
	inp.fake[1] = {"stick": Vector2(1, 0), "press": 0, "held": 0}
	await wait(20)
	ok(w.players[1].hvel.length() > 3.0, "le 2e joueur se déplace avec sa commande (%s %.1f)" % [w.players[1].state, w.players[1].hvel.length()])
	inp.fake[1]["stick"] = Vector2.ZERO
	await wait(10)
	game._toggle_p2()
	inp.fake[1] = null
	await wait(2)
	ok(w.players.size() == 1, "2e joueur retiré")

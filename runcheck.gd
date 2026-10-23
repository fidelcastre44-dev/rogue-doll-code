extends SceneTree
## Auto-test de la partie : godot --headless --path . -s runcheck.gd --fixed-fps 120
## Salle 1 : 2 sbires ; quand ils sont morts (et restent morts), écran de choix de 3 améliorations ;
## on en prend une, elle s'applique, salle 2 ; un K.O. propose de recommencer ; les 8 salles mènent à la fin du monde.

var main: Node3D
var f := 0
var fails := []
var phase := "start"
var pt := 0


func _initialize():
	main = load("res://main.tscn").instantiate()
	main.force_room = true
	main.force_run = true
	root.add_child(main)


func _go(p: String) -> void:
	phase = p
	pt = f


func _kill_all() -> void:
	for e in main.enemies:
		if e.state != "dead":
			e.hit(e.parts.chest, Vector3(0, 0.3, -1) * 40.0, e.parts.chest.global_position, 999.0, 1.0, true)


func _buttons() -> Array:
	var out := []
	for c in main.run.row.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _process(_d):
	f += 1
	var run = main.run
	var k := f - pt
	match phase:
		"start":
			if f == 10:
				_check(run.room_i == 0 and main.enemies.size() == 2, "salle 1 : 2 sbires (%d)" % main.enemies.size())
				_check(main.player.heavy_move == "kick" and main.player.light_move == "base", "on démarre avec les coups de base")
				_kill_all()
				_go("cleared")
		"cleared":
			if k == 400:   # bien après le délai de réapparition hors partie
				var dead := 0
				for e in main.enemies:
					if e.state == "dead":
						dead += 1
				_check(dead == 2, "en partie, les sbires morts restent morts (%d/2)" % dead)
				_check(run.busy and main.get_tree().paused and _buttons().size() == 3, "salle nettoyée : jeu en pause, 3 améliorations proposées (%d)" % _buttons().size())
				var b: Button = _buttons()[0]
				_check(b.text.length() > 40, "chaque carte explique le coup :\n%s" % b.text)
				main.player.hp = 50.0
				b.pressed.emit()
				_go("room2")
		"room2":
			if k == 5:
				var got := 0
				for u in load("res://upgrades.gd").LIST:
					if u[1].begins_with("form_") or (u[1] == "air_heavy" and u[2] == "dropkick"):
						continue   # formes déjà en place au départ de la run (v0.212)
					if typeof(u[2]) == TYPE_ARRAY:
						if main.player.btn_ups.has(u[0]):
							got += 1
					elif main.player.get(u[1]) == u[2]:
						got += 1
				_check(got == 1, "l'amélioration choisie est appliquée (%d)" % got)
				_check(run.room_i == 1 and not main.get_tree().paused and main.enemies.size() == 2, "salle 2 (salle %d, %d sbires)" % [run.room_i + 1, main.enemies.size()])
				_check(main.player.hp == 80.0, "un peu de vie rendue entre les salles (%.0f)" % main.player.hp)
				main.player.hp = 0.0
			if k == 10:
				_check(run.busy and run.title.text.begins_with("K.O."), "K.O. : écran pour recommencer")
				_buttons()[0].pressed.emit()
			if k == 15:
				_check(run.room_i == 0 and main.player.hp == 100.0 and main.player.light_move == "base" and main.player.heavy_move == "kick", "on recommence le monde avec les coups de base")
				_go("all")
		"all":   # toutes les salles d'affilée
			if run.busy and k % 5 == 0:
				var bs := _buttons()
				if run.title.text.begins_with("Monde 1 terminé"):
					var n := 0
					for u in load("res://upgrades.gd").LIST:
						if main.player.get(u[1]) == u[2]:
							n += 1
					_check(true, "8 salles nettoyées : monde terminé")
					_check(n >= 4, "améliorations accumulées en route (%d, certaines en remplacent d'autres sur le même bouton)" % n)
					print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
					quit(1 if fails.size() else 0)
				elif bs.size() > 0:
					bs[randi() % bs.size()].pressed.emit()
			elif not run.busy and k % 20 == 0:
				_kill_all()
			if k > 6000:
				_check(false, "le monde n'a pas pu être terminé (salle %d)" % (run.room_i + 1))
				print("\nRESULTAT: ECHEC " + str(fails))
				quit(1)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

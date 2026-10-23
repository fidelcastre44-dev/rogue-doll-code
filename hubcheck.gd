extends SceneTree
## Auto-test du salon (v0.211) : godot --headless --path . -s hubcheck.gd --fixed-fps 120
## Scène de démarrage, héros qui se déplace, quatre objets (punching-ball, établi, ordinateur, porte), RB près d'un objet
## = l'ouvrir, menu des paliers à l'établi, retours vers le salon.

var hub
var p
var fails := []


func _initialize() -> void:
	hub = load("res://hub.tscn").instantiate()
	hub.dry = true
	root.add_child(hub)
	_run()


func ok(c: bool, msg: String) -> void:
	print(("  [ok] " if c else "  [ECHEC] ") + msg)
	if not c:
		fails.append(msg)


func wait(n: int) -> void:
	for i in n:
		await physics_frame


func tap(a: String) -> void:
	Input.action_press(a)
	await wait(2)
	Input.action_release(a)
	await wait(2)


## Marche jusqu'à un point au stick (haut / bas / gauche / droite selon la caméra en diagonale).
func walk_to(at: Vector3) -> void:
	for i in 600:
		var d: Vector3 = (at - p.global_position) * Vector3(1, 0, 1)
		if d.length() < 0.35:
			break
		# stick (x, y) -> monde : la caméra regarde en diagonale ; on cherche la combinaison la plus proche.
		var best := ""
		var bd := -2.0
		for k in [["up", Vector3(1, 0, -1)], ["down", Vector3(-1, 0, 1)], ["left", Vector3(-1, 0, -1)], ["right", Vector3(1, 0, 1)]]:
			var dot: float = k[1].normalized().dot(d.normalized())
			if dot > bd:
				bd = dot
				best = k[0]
		for a in ["up", "down", "left", "right"]:
			if a == best:
				Input.action_press(a)
			else:
				Input.action_release(a)
		await physics_frame
	for a in ["up", "down", "left", "right"]:
		Input.action_release(a)
	await wait(10)


func _run() -> void:
	await wait(10)
	p = hub.player
	print("Salon")
	ok(ProjectSettings.get_setting("application/run/main_scene") == "res://hub.tscn", "le jeu démarre dans le salon")
	ok(hub.stations.size() == 4, "quatre objets : punching-ball, établi, ordinateur, porte")
	ok(hub.near == -1 and hub.prompt.text == "", "au départ, aucun objet à portée")
	var p0: Vector3 = p.global_position
	Input.action_press("up")
	await wait(30)
	Input.action_release("up")
	ok(p.global_position.distance_to(p0) > 0.5, "le héros se déplace")
	ok(not hub.main.enemies[0].visible, "pas de sbire dans le salon")
	await tap("grab")
	ok(hub.went == "" and p.attack == "", "RB loin des objets : rien (pas de chope)")

	var expect := {"labo": "res://labo.tscn", "editor": "res://anim_editor.tscn", "run": "res://main.tscn"}
	for i in hub.stations.size():
		var st: Dictionary = hub.stations[i]
		hub.went = ""
		await walk_to(st.at)
		ok(hub.near == i, "%s : à portée en s'approchant (%s)" % [st.what, hub.prompt.text])
		ok(hub.prompt.text.contains(st.name), "le message dit « RB : %s »" % st.name)
		await tap("grab")
		if st.act == "tiers":
			ok(hub.menu_open and hub.tiers_box.visible and paused, "établi : RB ouvre le menu des paliers (jeu en pause)")
			ok(hub.tiers_btns.size() == BuildTiers.TIERS.size(), "un bouton par palier (%d)" % hub.tiers_btns.size())
			var ev := InputEventAction.new()
			ev.action = "ui_cancel"
			ev.pressed = true
			hub._unhandled_input(ev)
			ok(not hub.menu_open and not paused, "B ferme le menu")
			await tap("grab")
			hub.tiers_btns[2].pressed.emit()
			ok(hub.went == "res://labo.tscn" and LaboCatalog.start_id == "build_t2", "Palier 2 : le labo s'ouvre sur la salle du palier 2")
			hub.open_tiers_menu(false)
		else:
			ok(hub.went == expect[st.act], "%s : RB ouvre %s (%s)" % [st.what, expect[st.act], hub.went])
		await tap("light")   # un coup dans le vide, pour libérer
		await wait(30)

	print("Labo ouvert depuis l'établi")
	var lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
	await wait(10)
	ok(lab.entry().id == "build_t2" and not lab.menu_open, "le labo démarre directement dans la salle du palier 2, menu fermé")
	ok(LaboCatalog.start_id == "", "une seule fois (la fois suivante, le labo s'ouvre normalement)")
	ok(lab.player.light_move == "knee" and lab.player.throw_move == "swing" and lab.player.form_capoeira, "avec les coups du palier 2")
	lab.queue_free()
	await wait(5)

	print("Retours au salon")
	for f in ["res://combat/labo.gd", "res://combat/anim_editor.gd", "res://combat/move_lab.gd", "res://main.gd", "res://run.gd"]:
		var src := FileAccess.get_file_as_string(f)
		ok(src.contains("hub.tscn") or src.contains("open_hub"), "%s ramène au salon" % f.get_file())

	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

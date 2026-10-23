extends SceneTree
## Auto-test du menu (améliorations + nombre d'ennemis) : godot --headless --path . -s menucheck.gd
## Par défaut, les coups de base ; le menu propose chaque amélioration et la change en jeu ; on choisit de 1 à 5 ennemis.

var main: Node3D
var f := 0
var fails := []
var v_pos := Vector3.ZERO
var v_epos := Vector3.ZERO
var focus0 = null


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	if f < 5:
		return false
	var p = main.player
	if f == 5:
		_check(p.dodge_move == "roll" and p.heavy_move == "kick" and p.air_move == "jab" and p.throw_move == "slam" and p.light_move == "base", "par défaut : les coups de base (%s, %s, %s, %s, %s)" % [p.dodge_move, p.heavy_move, p.air_move, p.throw_move, p.light_move])
		_check(p._combo() == ["jab", "cross", "jab2", "upper"], "combo de base : jab, direct, jab, uppercut (%s)" % str(p._combo()))
		var obs := []
		for c in main.panel.get_children():
			if c is OptionButton:
				obs.append(c)
		_check(obs.size() == 7, "7 menus déroulants : 6 améliorations + nombre d'ennemis (%d)" % obs.size())
		for ob in obs:
			ob.select(ob.item_count - 1)
			ob.item_selected.emit(ob.item_count - 1)
		_check(p.dodge_move == "dash" and p.heavy_move == "quake" and p.charge_move == "hadoken" and p.air_move == "jab" and p.light_move == "knee" and p.sprint_attack == "flop" and p.throw_move == "throw", "choisir dans le menu change le coup en jeu (%s, %s, %s, %s, %s)" % [p.dodge_move, p.heavy_move, p.air_move, p.light_move, p.throw_move])
		_check(p._combo() == ["jab", "cross", "jab2", "knee"], "l'amélioration change le dernier coup du combo (%s)" % str(p._combo()))
		_check(main.enemies.size() == 5, "nombre d'ennemis : 5 (%d)" % main.enemies.size())
		var cbs := []
		for c in main.panel.get_children():
			if c is CheckButton:
				cbs.append(c)
		_check(cbs.size() == 9, "9 modificateurs à cocher (%d)" % cbs.size())
		for cb in cbs:
			cb.button_pressed = true
		_check(p.double_jump and p.dive and p.air_slam and p.sweep_triple and p.parry and p.riposte and p.guard_gauge, "cocher active les modificateurs")
		for ob in obs:
			ob.select(0)
			ob.item_selected.emit(0)
	if f == 22:
		main.toggle_menu()
		v_pos = p.global_position
		_check(main.get_tree().paused and main.scroll.visible, "Start : menu ouvert, jeu en pause")
		var f0 = main.get_viewport().gui_get_focus_owner()
		_check(f0 != null, "le menu a le focus (pilotable à la manette)")
		focus0 = f0
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_DPAD_DOWN
		ev.pressed = true
		Input.parse_input_event(ev)
	if f == 26:
		var ev2 := InputEventJoypadButton.new()
		ev2.button_index = JOY_BUTTON_DPAD_DOWN
		ev2.pressed = false
		Input.parse_input_event(ev2)
		_check(main.get_viewport().gui_get_focus_owner() != focus0, "la croix descend dans le menu")
	if f == 40:
		main.toggle_menu()
		_check(not main.get_tree().paused and not main.scroll.visible, "Start à nouveau : menu fermé, le jeu reprend")
	if f == 50:
		_check(p.dodge_move == "roll" and p.air_move == "jab" and p.throw_move == "slam", "et on peut revenir aux coups de base")
		_check(main.enemies.size() == 1 and main.get_tree().get_nodes_in_group("enemies").size() == 1, "nombre d'ennemis : 1 (%d)" % main.get_tree().get_nodes_in_group("enemies").size())
		print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
		quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

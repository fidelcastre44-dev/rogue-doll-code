extends SceneTree
## Auto-test du décor : godot --headless --path . -s roomcheck.gd --fixed-fps 120
## Une pièce tirée au hasard : murets tout autour, objets (tables, poubelles...) qui laissent libres le joueur et les sbires,
## objets physiques qui se posent sans exploser ; une nouvelle pièce est différente de la précédente.

var main: Node3D
var f := 0
var fails := []
var first := []


func _initialize():
	main = load("res://main.tscn").instantiate()
	main.force_room = true
	main.force_extras = 4
	root.add_child(main)


func _layout() -> Array:
	var out := []
	for c in main.room.get_children():
		if c is RigidBody3D or (c is StaticBody3D and not c.is_in_group("walls")):
			out.append(c)
	return out


func _process(_d):
	f += 1
	if f == 5:
		var walls := 0
		for c in main.room.get_children():
			if c.is_in_group("walls"):
				walls += 1
		var props := _layout()
		_check(walls == 4, "4 murets autour de la pièce (%d)" % walls)
		_check(props.size() >= 9, "des objets dans la pièce (%d)" % props.size())
		var kinds := {}
		for b in props:
			if b.has_meta("kind"):
				kinds[b.get_meta("kind")] = true
		_check(kinds.size() >= 3 and get_nodes_in_group("reactive").size() >= 8, "plusieurs sortes d'objets réactifs (%s)" % str(kinds.keys()))
		var near := 99.0
		for b in props:
			near = minf(near, Vector2(b.position.x - main.player.global_position.x, b.position.z - main.player.global_position.z).length())
			for e in main.enemies:
				near = minf(near, Vector2(b.position.x - e.global_position.x, b.position.z - e.global_position.z).length())
		_check(near > 1.0, "aucun objet sur le joueur ni sur un sbire (le plus proche à %.2f m)" % near)
		for b in props:
			first.append(b.position)
	if f == 250:
		var ok := true
		var hx: float = main.room.size.x * 0.5 + 0.5
		var hz: float = main.room.size.y * 0.5 + 0.5
		for b in _layout():
			if b.global_position.y < -0.5 or absf(b.global_position.x) > hx or absf(b.global_position.z) > hz:
				ok = false
		_check(ok, "les objets se posent sans exploser ni sortir de la pièce")
		main.new_room()
	if f == 260:
		var same := 0
		var props := _layout()
		for b in props:
			for p in first:
				if b.position.distance_to(p) < 0.05:
					same += 1
		_check(same < 3, "nouvelle pièce : un décor différent (%d objets à la même place)" % same)
		print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
		quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

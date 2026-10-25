extends SceneTree
var w: SimWorld
func _initialize() -> void:
	w = SimWorld.new()
	root.add_child(w)
	_run.call_deferred()
func _run() -> void:
	await physics_frame
	var h := w.add_player()
	w.load_spot("centre")
	var inp = root.get_node("Inputs")
	inp.fake[0] = {"stick": Vector2.ZERO, "press": 0, "held": 0}
	for i in 10: await physics_frame
	inp.fake[0]["press"] = InputSource.BIT.attack
	for i in 40:
		await physics_frame
		if i % 5 == 0: print(w.frame, " ", h.debug_line(), " | foe ", w.foes[0].debug_line())
	print("RESULTAT: OK")
	quit()

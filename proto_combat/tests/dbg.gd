extends SceneTree
var game; var inp; var fr := 0
var seq := {10: "attack", 17: "heavy", 44: "jump", 50: "attack", 61: "attack", 72: "attack", 88: "heavy"}
func _initialize():
	game = load("res://main.tscn").instantiate(); root.add_child(game)
func _physics_process(_d):
	if inp == null:
		inp = root.get_node("Inputs"); inp.use_fake = true
	fr += 1
	if fr == 2: game.foe_count = 1; game.load_spot("centre")
	if seq.has(fr): inp.press(seq[fr])
	for a in ["attack","heavy","jump"]:
		if inp.held(a) and inp.held_time(a) > 0.02: inp.release(a)
	var e = game.enemies[0]
	if fr % 3 == 0 and fr < 140:
		var h = game.hero
		print(fr, " ", h.state, ":", h.move_id, " f", h.f, " hit", h.has_hit, " pos(%.1f,%.1f,%.1f)" % [h.global_position.x,h.global_position.y,h.global_position.z], " | foe ", e.state, " (%.1f,%.1f,%.1f)" % [e.global_position.x,e.global_position.y,e.global_position.z], " combo ", h.combo)
	return fr > 140

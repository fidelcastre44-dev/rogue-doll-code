extends SceneTree
## Rejoue un scénario d'entrées sur le vrai jeu (main.tscn) et prend des captures. Pour les images de contrôle.
## SCN=nom SHOTS=/dossier  xvfb-run godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s tests/play.gd
## Étapes : [image, action, valeur]. Actions : stick (Vector2 écran), press, release, spot, mode, count, shot, strip [début, fin, pas], zoom, end.

const SCENARIOS := {
	"combo": [[2, "spot", "centre"], [3, "zoom", 0.4], [3, "yaw", 90.0], [3, "pitch", 30.0], [10, "press", "attack"], [24, "press", "attack"], [38, "press", "attack"], [52, "press", "attack"], [8, "strip", [10, 140, 5]], [150, "end", 0]],
	"launch": [[2, "spot", "centre"], [3, "zoom", 0.5], [3, "yaw", 90.0], [3, "pitch", 25.0], [10, "press", "attack"], [24, "press", "attack"], [36, "press", "heavy"], [62, "press", "jump"], [70, "press", "attack"], [82, "press", "attack"], [94, "press", "attack"], [108, "press", "heavy"], [8, "strip", [10, 180, 6]], [190, "end", 0]],
	"heavy": [[2, "spot", "centre"], [3, "zoom", 0.45], [3, "yaw", 90.0], [3, "pitch", 30.0], [10, "press", "heavy"], [40, "press", "heavy"], [8, "strip", [10, 150, 5]], [160, "end", 0]],
	"grab": [[2, "spot", "centre"], [3, "zoom", 0.45], [3, "yaw", 90.0], [3, "pitch", 30.0], [10, "press", "grab"], [50, "press", "attack"], [80, "press", "attack"], [110, "press", "grab"], [8, "strip", [10, 190, 6]], [200, "end", 0]],
	"move": [[2, "spot", "ligne"], [3, "zoom", 0.5], [3, "pitch", 30.0], [5, "stick", Vector2(1, 0)], [40, "press", "dodge"], [52, "press", "attack"], [80, "stick", Vector2(-1, 0)], [100, "stick", Vector2.ZERO], [104, "press", "heavy"], [8, "strip", [10, 150, 5]], [160, "end", 0]],
	"attackers": [[2, "mode", "attack"], [3, "spot", "foule"], [60, "shot", "crowd"], [120, "shot", "crowd2"], [121, "press", "guard"], [200, "shot", "guard"], [201, "release", "guard"], [260, "end", 0]],
	"side": [[2, "spot", "centre"], [3, "yaw", 90.0], [3, "pitch", 30.0], [3, "zoom", 0.8], [40, "shot", "side"], [41, "press", "attack"], [49, "shot", "side_jab"], [60, "end", 0]],
	"overview": [[2, "spot", "ligne"], [30, "shot", "idle"], [31, "stick", Vector2(0, -1)], [60, "shot", "run"], [61, "stick", Vector2.ZERO], [70, "press", "attack"], [80, "shot", "jab"], [120, "end", 0]],
}

var step := 0
var frame := 0
var game: Node
var scn: Array
var shots := ""
var inp: Node
var strip := []
var held := {}


func _initialize() -> void:
	var name := OS.get_environment("SCN")
	if name == "":
		name = "overview"
	scn = SCENARIOS[name].duplicate()
	scn.sort_custom(func(a, b): return a[0] < b[0])
	shots = OS.get_environment("SHOTS")
	if shots == "":
		shots = "/tmp"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)


func _physics_process(_dt: float) -> bool:
	if inp == null:
		inp = root.get_node("Inputs")
		inp.fake[0] = {"stick": Vector2.ZERO, "press": 0, "held": 0}
	frame += 1
	while step < scn.size() and scn[step][0] <= frame:
		var s: Array = scn[step]
		step += 1
		match s[1]:
			"stick": inp.fake[0]["stick"] = s[2]
			"press":
				inp.fake[0]["press"] |= InputSource.BIT[s[2]]
				inp.fake[0]["held"] |= InputSource.BIT[s[2]]
				held[s[2]] = frame
			"release": inp.fake[0]["held"] &= ~InputSource.BIT[s[2]]; held.erase(s[2])
			"spot": game.world.load_spot(s[2]); game.view.cam.snap()
			"mode": game.world.set_foe_mode(s[2])
			"shot": _shot(s[2])
			"zoom": game.view.cam.zoom = s[2]
			"yaw": game.view.cam.yaw = s[2]
			"pitch": game.view.cam.pitch = s[2]
			"strip": strip = s[2]
			"end":
				print("fin du scénario")
				return true
	for b in held.keys():
		if b != "guard" and frame - held[b] >= 2:
			inp.fake[0]["held"] &= ~InputSource.BIT[b]
			held.erase(b)
	if strip.size() and frame >= strip[0] and frame <= strip[1] and (frame - strip[0]) % strip[2] == 0:
		_shot("strip_%04d" % frame)
	return false


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots + "/" + n + ".png")
	var h = game.world.players[0]
	print("capture ", n, " héros=", h.state, " ", h.move_id, " f", h.f)

extends SceneTree
## Rejoue un scénario d'entrées sur le vrai jeu et prend des captures. Utilisé pour les tests et les images de contrôle.
## SCN=nom (voir SCENARIOS) SHOTS=/dossier  xvfb-run godot --path . --rendering-driver opengl3 -s tests/play.gd
## Chaque étape : [image, action, valeur]. Actions : stick (Vector2), press, release, spot, mode, shot, look.

const SCENARIOS := {
	"overview": [[2, "spot", "centre"], [30, "shot", "idle"], [31, "stick", Vector2(0.0, -1.0)], [70, "shot", "run"], [71, "stick", Vector2.ZERO],
		[90, "press", "attack"], [96, "shot", "jab"], [100, "press", "attack"], [110, "shot", "cross"], [112, "press", "attack"], [124, "shot", "hook"],
		[126, "press", "attack"], [140, "shot", "spin"], [150, "shot", "spin2"], [200, "end", 0]],
	"launch": [[2, "spot", "centre"], [20, "press", "attack"], [28, "press", "heavy"], [44, "shot", "uppercut"], [52, "press", "jump"], [60, "shot", "jump"],
		[64, "press", "attack"], [70, "shot", "airjab"], [76, "press", "attack"], [86, "press", "attack"], [92, "shot", "airkick"], [100, "press", "heavy"], [116, "shot", "spike"], [180, "end", 0]],
	"wall": [[2, "spot", "mur"], [20, "press", "heavy"], [40, "press", "heavy"], [60, "shot", "haymaker"], [75, "shot", "splat"], [140, "end", 0]],
	"combo_strip": [[2, "spot", "centre"], [3, "zoom", 0.55], [10, "press", "attack"], [24, "press", "attack"], [38, "press", "attack"], [52, "press", "attack"], [8, "strip", [10, 130, 4]], [140, "end", 0]],
	"air_strip": [[2, "spot", "centre"], [3, "zoom", 0.7], [10, "press", "attack"], [17, "press", "heavy"], [44, "press", "jump"], [50, "press", "attack"], [61, "press", "attack"], [72, "press", "attack"], [88, "press", "heavy"], [8, "strip", [10, 150, 5]], [160, "end", 0]],
	"move_strip": [[2, "spot", "ligne"], [3, "zoom", 0.6], [10, "stick", Vector2(1, 0)], [40, "press", "dodge"], [52, "press", "attack"], [80, "stick", Vector2(-1, 0)], [100, "stick", Vector2.ZERO], [104, "press", "heavy"], [8, "strip", [10, 140, 5]], [150, "end", 0]],
	"rag_strip": [[2, "spot", "centre"], [3, "zoom", 0.6], [10, "press", "attack"], [17, "press", "heavy"], [44, "press", "jump"], [50, "press", "attack"], [61, "press", "attack"], [72, "press", "attack"], [8, "strip", [30, 200, 6]], [210, "end", 0]],
	"rag_kick": [[2, "spot", "centre"], [3, "zoom", 1.0], [10, "press", "heavy"], [30, "press", "heavy"], [8, "strip", [36, 190, 6]], [200, "end", 0]],
	"attackers": [[2, "mode", "attack"], [3, "spot", "foule"], [60, "shot", "crowd"], [120, "shot", "crowd2"], [121, "press", "guard"], [200, "shot", "guard"], [201, "release", "guard"], [260, "end", 0]],
}

var step := 0
var frame := 0
var game: Node
var scn: Array
var shots := ""
var inp: Node
var strip := []


func _initialize() -> void:
	var name := OS.get_environment("SCN")
	if name == "":
		name = "overview"
	scn = SCENARIOS[name]
	shots = OS.get_environment("SHOTS")
	if shots == "":
		shots = "/tmp"
	var ps: PackedScene = load("res://main.tscn")
	game = ps.instantiate()
	root.add_child(game)


func _physics_process(_dt: float) -> bool:
	if inp == null:
		inp = root.get_node("Inputs")
		inp.use_fake = true
	frame += 1
	while step < scn.size() and scn[step][0] <= frame:
		var s: Array = scn[step]
		step += 1
		match s[1]:
			"stick": inp.fake_stick = s[2]
			"press": inp.press(s[2])
			"release": inp.release(s[2])
			"tap":
				inp.press(s[2])
			"spot": game.load_spot(s[2])
			"mode": game.set_foe_mode(s[2])
			"look": game.set_look(s[2])
			"shot": _shot(s[2])
			"zoom": game.cam.zoom = s[2]
			"strip": strip = s[2]
			"end":
				print("fin du scénario")
				return true
	if strip.size() and frame >= strip[0] and frame <= strip[1] and (frame - strip[0]) % strip[2] == 0:
		_shot("strip_%04d" % frame)
	# un appui « press » est relâché à l'image suivante sauf garde (maintenue jusqu'à release)
	for a in ["attack", "jump", "dodge", "grab"]:
		if inp.held(a) and inp.held_time(a) > 0.02:
			inp.release(a)
	if inp.held("heavy") and inp.held_time("heavy") > 0.02 and not OS.get_environment("HOLD_HEAVY"):
		inp.release("heavy")
	return false


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(shots + "/" + n + ".png")
	print("capture ", n, " héros=", game.hero.state, " ", game.hero.move_id)

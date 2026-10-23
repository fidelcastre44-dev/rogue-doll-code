extends SceneTree
## Auto-test physique : godot --headless --path . -s selfcheck.gd --fixed-fps 120
## Vérifie : debout et posé, vacille sans tomber, éjecté à la chute, se relève, meurt, joints intacts.

var main: Node3D
var f := 0
var fails := []
var max_gap := 0.0
var max_lean := 0.0
var before_fall := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false   # sac de frappe immobile pour ce test
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	var e = main.enemy
	var p = main.player
	if e.parts.is_empty():
		return false
	var head: float = e.parts.head.global_position.y
	var pel: Vector3 = e.parts.pelvis.global_position
	for d in e.BODY:   # le point d'articulation vu par le membre et par son parent doit rester le même
		if d[1] != "":
			var gap: float = e.parts[d[1]].to_global(d[4] - e.rest_center[d[1]]).distance_to(e.parts[d[0]].to_global(d[4] - d[3]))
			max_gap = maxf(max_gap, gap)
	if f > 240 and f < 330:
		max_lean = maxf(max_lean, e.lean.length())
	if f % 60 == 0:
		print("t=%.1fs %s hp=%.0f poise=%.2f tete=%.2f" % [f / 120.0, e.state, e.hp, e.poise, head])
	# Avant chaque coup : le joueur est placé à 0.9 m devant le bassin, face à lui. Le pied frappe à hauteur de bassin : il ne touche pas un ennemi au sol.
	if f in [240, 330, 400, 1000, 1100, 1450]:
		var to_p: Vector3 = (p.global_position - pel) * Vector3(1, 0, 1)
		p.global_position = Vector3(pel.x, 0, pel.z) + to_p.normalized() * 0.9
		p.start("jab" if f == 240 else "kick")
	if f == 400:
		before_fall = pel
	if f == 990:
		e.hp = e.MAX_HP   # vie remise à plein : les coups suivants testent la relève, pas la mort
	if f == 1440:
		e.hp = 5.0   # le dernier coup le tue
	match f:
		230:
			var foot: float = e.parts.shin_l.global_position.y - 0.225
			_check(e.state == "stand" and absf(head - 1.69) < 0.03 and absf(foot) < 0.02, "debout, pieds au sol (tête %.2f, pied %.3f)" % [head, foot])
		300: _check(e.state == "stand" and e.hp == e.MAX_HP - 8 and max_lean > 0.02, "le poing touche et le fait vaciller (hp %.0f, penché %.0f°)" % [e.hp, rad_to_deg(max_lean)])
		520:
			var d := Vector2(pel.x - before_fall.x, pel.z - before_fall.z).length()
			_check(e.state == "down" and head < 0.8 and d > 1.0, "au sol et éjecté (tête %.2f, recul %.2f m)" % [head, d])
		800: _check(e.state == "stand" and absf(head - 1.69) < 0.03, "relevé et posé (tête %.2f)" % head)
		1650: _check(e.state == "dead" and head < 0.6, "mort et effondré (%s, tête %.2f)" % [e.state, head])
		1670:
			_check(max_gap < 0.08, "joints intacts (écart max %.3f m)" % max_gap)
			print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
			quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

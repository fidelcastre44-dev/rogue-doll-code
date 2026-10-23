extends SceneTree
## Auto-test du combo : godot --headless --path . -s combocheck.gd --fixed-fps 120
## 4 appuis rapides = jab, direct, jab, uppercut qui touchent tous (v0.216) ; l'uppercut fait décoller l'ennemi puis il retombe au sol (v0.218) ;
## après une pause, on repart du jab ; un uppercut seul lance aussi un ennemi frais.

var main: Node3D
var f := 0
var seen := []
var prev := ""
var prev_t := 0.0
var peak := 0.0
var fails := []


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.get_node("Player").light_move = "upper"   # combo à 3 coups (amélioration)
	main.get_node("Enemy").ai_on = false   # sac de frappe immobile pour ce test
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if f == 20:
		var pel: Vector3 = e.parts.pelvis.global_position
		p.global_position = Vector3(pel.x, 0, pel.z + 0.9)
		p.rotation.y = 0
	if f in [100, 112, 124, 136, 600]:   # appuis à ~100 ms d'intervalle (martelage), puis un appui isolé bien plus tard
		Input.action_press("light")
	if f in [101, 113, 125, 137, 601]:
		Input.action_release("light")
	if p.attack != "" and (p.attack != prev or p.t < prev_t):   # un nouveau coup a démarré
		seen.append(p.attack)
	prev = p.attack
	prev_t = p.t
	if e.state in ["launch", "down"] and not e.parts.is_empty():
		peak = maxf(peak, e.parts.pelvis.global_position.y)
	if f == 280:
		var names := seen
		_check(names == ["jab", "cross", "jab2", "upper"], "enchaînement jab > direct > jab > uppercut (%s)" % str(names))
		_check(e.hp == e.MAX_HP - 8 - 10 - 8 - 14, "les 4 coups touchent (hp %.0f)" % e.hp)
		_check(peak > 1.6, "l'uppercut le fait décoller (bassin monté à %.2f m, 1.0 debout)" % peak)
	if f == 380:
		_check(e.state in ["down", "getup", "rise"] and not e.air_recover, "puis il retombe au sol, sans se rattraper sur ses pieds (v0.218, %s)" % e.state)
	if f == 610:
		_check(p.attack == "jab", "après une pause, le combo repart du jab (%s)" % p.attack)
	if f == 700:
		e.build()
	if f == 720:
		var pel: Vector3 = e.parts.pelvis.global_position
		p.global_position = Vector3(pel.x, 0, pel.z + 0.9)
		p.rotation.y = 0
		p.start("upper")
	if f == 750:
		_check(e.state == "down" and e.parts.pelvis.global_position.y > 1.2, "un uppercut seul sur un ennemi frais le lance aussi (%s, bassin à %.2f m) ; seul, il reste un lanceur" % [e.state, e.parts.pelvis.global_position.y])
	if f == 810:
		print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
		quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

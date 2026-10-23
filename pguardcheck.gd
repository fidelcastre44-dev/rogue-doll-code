extends SceneTree
## Auto-test de la garde du joueur : godot --headless --path . -s pguardcheck.gd --fixed-fps 120
## L1 maintenu : le sbire frappe dans la garde, aucun dégât ; garde relâchée : il touche.

var main: Node3D
var f := 0
var fails := []
var phase := "guard"
var hp0 := 0.0
var posed := false
var strikes := 0
var prev := ""


func _initialize() -> void:
	seed(4)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	if e.ai == "strike" and prev != "strike":
		strikes += 1
	prev = e.ai
	match phase:
		"guard":
			if f == 10:
				Input.action_press("guard")
				hp0 = p.hp
			if f == 60:
				_check(p.guarding and p.guard_mix > 0.9, "L1 maintenu : en garde")
				var hands: float = (p.j.fist_l.global_position.y + p.j.fist_r.global_position.y) * 0.5
				_check(hands > p.j.head.global_position.y - 0.25, "garde haute : poings au niveau du visage (%.2f / tête %.2f)" % [hands, p.j.head.global_position.y])
			if f == 70:   # coups simulés : de côté (paré), de dos (passe)
				var fwd: Vector3 = -p.global_basis.z
				var side: Vector3 = p.global_basis.x
				var h0: float = p.hp
				p.take_hit(-side, 5.0)   # vient de sa droite
				p.take_hit((fwd * 0.3 - side).normalized(), 5.0)   # de côté, un peu de dos
				_check(p.hp == h0, "la garde pare aussi les coups venant des côtés (vie %.0f)" % p.hp)
				p.take_hit(fwd, 5.0)   # vient pile de dos
				_check(p.hp == h0 - 5.0, "un coup vraiment de dos passe la garde (vie %.0f -> %.0f)" % [h0, p.hp])
				p.hp = h0
				hp0 = h0
				p.hurt = 0.0
			if strikes >= 3 and e.ai == "recover":
				_check(p.hp == hp0, "en garde : ses coups ne font aucun dégât (%d coups, vie %.0f)" % [strikes, p.hp])
				Input.action_release("guard")
				hp0 = p.hp
				strikes = 0
				phase = "open"
		"open":
			if strikes >= 1 and e.ai == "recover":
				_check(p.hp < hp0, "garde relâchée : il touche (vie %.0f -> %.0f)" % [hp0, p.hp])
				phase = "end"
		"end":
			print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
			quit(1 if fails.size() else 0)
	if f > 120 * 30:
		_check(false, "test bloqué en phase " + phase)
		print("\nRESULTAT: ECHEC")
		quit(1)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

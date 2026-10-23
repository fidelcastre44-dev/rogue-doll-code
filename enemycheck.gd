extends SceneTree
## Auto-test du sbire : godot --headless --path . -s enemycheck.gd --fixed-fps 120
## Il tourne autour du joueur à distance ; il recule en armant ; son coup touche un joueur immobile ;
## une roulade au bon moment l'esquive ; un coup reçu pendant qu'il arme l'interrompt ;
## reculer d'un pas ou faire un pas de côté ne suffit pas à l'esquiver (zone généreuse, élan adaptatif, suivi pendant l'armé).

var main: Node3D
var f := 0
var fails := []
var phase := "circle_watch"
var angle0 := 0.0
var dmin := INF
var dmax := 0.0
var windup_d0 := 0.0
var hp0 := 0.0
var attacks := 0


func _initialize() -> void:
	seed(1)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	var to: Vector3 = (e.root.origin - p.global_position) * Vector3(1, 0, 1)
	var dist := to.length()
	if f == 30:
		angle0 = atan2(to.x, to.z)
	if f > 30 and f < 140:   # 0,9 s d'observation, avant sa première attaque
		dmin = minf(dmin, dist)
		dmax = maxf(dmax, dist)
	if f == 140:
		var turned := absf(angle_difference(angle0, atan2(to.x, to.z)))
		_check(turned > deg_to_rad(10), "il tourne autour du joueur (%.0f° parcourus)" % rad_to_deg(turned))
		_check(dmin > 1.2 and dmax < 2.8, "en restant proche (entre %.1f et %.1f m)" % [dmin, dmax])
	# Chaque attaque : on observe l'armé, puis selon le numéro de l'attaque on encaisse, on roule, ou on l'interrompt.
	if e.ai == "windup" and phase in ["circle_watch", "circle"]:
		phase = "windup"
		attacks += 1
		windup_d0 = dist
		hp0 = p.hp
	if phase == "windup" and attacks == 1 and e.ai_t > e.windup_len - 0.02:
		_check(dist > windup_d0 + 0.1, "il recule en armant son coup (%.2f -> %.2f m)" % [windup_d0, dist])
		phase = "wait_hit"
	if phase == "windup" and attacks == 2 and e.ai_t > e.windup_len - 0.06:
		Input.action_press("roll")   # roulade juste avant qu'il frappe
		phase = "rolled"
	if phase == "rolled" and Input.is_action_pressed("roll"):
		Input.action_release("roll")
	if phase == "windup" and attacks == 3 and e.ai_t > 0.2:
		e.hit(e.parts.chest, -e.root.basis.z * 10.0, e.parts.chest.global_position, 1.0, 0.05)   # petit coup pendant l'armé
		phase = "interrupted"
	if e.ai == "recover" and phase == "wait_hit":
		_check(p.hp == hp0 - e.PUNCH_DMG, "son coup touche le joueur immobile (vie %.0f -> %.0f)" % [hp0, p.hp])
		phase = "circle"
	if e.ai == "recover" and phase == "rolled":
		_check(p.hp == hp0, "la roulade au bon moment esquive le coup (vie %.0f)" % p.hp)
		phase = "circle"
	if phase == "interrupted" and f % 10 == 0:
		_check(e.ai == "circle" and p.hp == hp0, "touché pendant qu'il arme, il est interrompu (%s, vie %.0f)" % [e.ai, p.hp])
		phase = "circle"
	if phase == "windup" and attacks == 4:
		p.global_position -= to.normalized() * 0.6   # le joueur recule d'un pas au moment où il commence à armer
		phase = "backed"
	if phase == "windup" and attacks == 5 and e.ai_t > 0.2:
		p.global_position += to.normalized().cross(Vector3.UP) * 0.6   # pas de côté pendant l'armé
		phase = "sidestep"
	if e.ai == "recover" and phase == "backed":
		_check(p.hp < hp0, "reculer d'un pas ne suffit pas : son élan comble l'écart (vie %.0f -> %.0f)" % [hp0, p.hp])
		phase = "circle"
	if e.ai == "recover" and phase == "sidestep":
		_check(p.hp < hp0, "un pas de côté pendant l'armé ne suffit pas : il te suit (vie %.0f -> %.0f)" % [hp0, p.hp])
		phase = "done"
	if phase == "done" or f > 120 * 60:
		_check(attacks >= 5, "il a attaqué au moins 5 fois (%d)" % attacks)
		print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
		quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

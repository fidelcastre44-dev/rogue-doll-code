extends SceneTree
## Auto-test lanceur / jongle / relevé : godot --headless --path . -s jugglecheck.gd --fixed-fps 120
## 1. Uppercut seul : il s'envole et se rattrape sur ses pieds sans toucher le sol, accroupi un instant, puis garde.
## 2. Accroupi après réception : on peut le punir.
## 3. Uppercut puis coup aérien : il ne se rattrape plus, s'écrase, puis se relève en roulade arrière (intouchable pendant).
## 4. En l'air, le combo de X est celui du sol : jab, direct, puis le 3e coup s'il est débloqué (au plus 3 par saut).

var main: Node3D
var f := 0
var fails := []
var phase := "start"
var low := INF
var seen := {}
var hp0 := 0.0
var air_starts := 0
var air_seq := []
var prev_attack := ""
var roll_from := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false
	root.add_child(main)


func _place(p, e) -> void:
	var pel: Vector3 = e.parts.pelvis.global_position
	p.global_position = Vector3(pel.x, 0, pel.z + 0.9)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	seen[e.state] = true
	var pel: Vector3 = e.parts.pelvis.global_position
	match phase:
		"start":
			if f == 20:
				_place(p, e)
				p.start("upper")
				phase = "fly"
				seen = {}
		"fly":
			if e.state == "down":
				low = INF
			if e.state == "getup":
				low = minf(low, pel.y)
			if e.state == "stand" and e.ai == "landed" and seen.has("down"):
				_check(low > 0.55, "uppercut seul : il se rattrape sans toucher le sol (bassin au plus bas %.2f m)" % low)
				_check(e.drop > 0.1, "il atterrit accroupi (bassin abaissé de %.2f m)" % e.drop)
				hp0 = e.hp
				_place(p, e)
				p.start("jab")   # punition pendant qu'il est accroupi
				phase = "punish"
		"punish":
			if p.attack == "" :
				_check(e.hp < hp0, "accroupi après réception, on peut le punir (vie %.0f -> %.0f)" % [hp0, e.hp])
				phase = "guard_back"
		"guard_back":
			if e.ai != "landed":
				_check(e.state == "stand" and e.drop == 0.0, "puis il se remet en garde")
				e.build()
				phase = "juggle_setup"
				f = 1000
		"juggle_setup":
			if f == 1020:
				_place(p, e)
				p.start("upper")
				seen = {}
			if p.connected and p.attack == "upper" and not Input.is_action_pressed("jump"):
				Input.action_press("jump")   # vrai enchaînement : uppercut qui touche, saut d'annulation, coup de poing aérien
			if Input.is_action_pressed("jump") and p.attack == "":
				Input.action_release("jump")
			if p.global_position.y > 0.4 and not Input.is_action_pressed("light"):   # dès qu'il arrive à hauteur, en montant
				Input.action_press("light")
				phase = "juggled"
		"juggled":
			if Input.is_action_pressed("light"):
				Input.action_release("light")
			if p.attack == "" and e.juggles == 0 and f > 1300:
				_check(false, "le coup aérien touche l'ennemi en l'air")
				phase = "end"
			if e.juggles > 0 and phase == "juggled":
				_check(not e.air_recover, "touché en l'air : il ne se rattrapera plus (jongle %d)" % e.juggles)
				phase = "crash"
		"crash":
			if e.state == "down" and pel.y < 0.35:
				_check(true, "il s'écrase au sol en ragdoll (bassin à %.2f m)" % pel.y)
				phase = "techroll"
		"techroll":
			if e.state == "techroll" and roll_from == Vector3.ZERO:
				roll_from = e.roll_start
				hp0 = e.hp
				e.hit(e.parts.chest, Vector3(0, 0, -20), e.parts.chest.global_position, 10.0, 0.5)   # on tente de l'achever pendant son relevé
				_check(e.hp == hp0, "intouchable pendant son relevé (vie %.0f)" % e.hp)
			if e.state == "stand" and roll_from != Vector3.ZERO:
				var back: float = Vector2(e.root.origin.x - roll_from.x, e.root.origin.z - roll_from.z).length()
				_check(back > 1.0, "il se relève en roulade arrière en reculant (%.2f m)" % back)
				_check(absf(e.parts.head.global_position.y - 1.69) < 0.05, "et finit debout en garde (tête à %.2f m)" % e.parts.head.global_position.y)
				phase = "air_limit"
				e.global_position = Vector3(30, 0, 30)
				e.build()
				f = 3000
		"air_limit":
			if f == 3010:
				p.light_move = "upper"
				p.global_position = Vector3(0, 0, 0.5)
				p.velocity = Vector3.ZERO
				Input.action_press("jump")
			if f == 3011:
				Input.action_release("jump")
			if f in [3030, 3050, 3070, 3090]:   # 4 appuis en l'air
				Input.action_press("light")
			if f in [3031, 3051, 3071, 3091]:
				Input.action_release("light")
			if p.attack in ["air", "air_cross", "air_upper"] and p.attack != prev_attack:
				air_starts += 1
				air_seq.append(p.attack)
			prev_attack = p.attack
			if f == 3200:
				_check(air_starts == 3 and air_seq == ["air", "air_cross", "air_upper"], "en l'air : jab, direct, uppercut, et pas plus (%s)" % str(air_seq))
				phase = "end"
		"end":
			print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
			quit(1 if fails.size() else 0)
	if f > 4000:
		_check(false, "test bloqué en phase " + phase)
		phase = "end"
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

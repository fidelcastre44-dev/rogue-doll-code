extends SceneTree
## Auto-test lancer visé + massue humaine (améliorations de chope) : godot --headless --path . -s grabupcheck.gd --fixed-fps 120
## Lancer visé : R1 maintenu = élan automatique (l'ennemi passe derrière), R1 relâché = lancé devant, il percute un autre sbire.
## Massue : R1 maintenu = tenu par les pieds (il bascule) ; X = abattu devant, il percute un autre sbire ; R1 relâché = lâché.

var main: Node3D
var f := 0
var fails := []
var phase := "throw"
var pt := 0
var e2: Node3D
var start := Vector3.ZERO
var behind := false
var peak := 0.0
var gap := 0.0
var circled := false


func _initialize() -> void:
	seed(12)
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false
	root.add_child(main)


func _go(next: String) -> void:
	phase = next
	pt = f


func _second(pos: Vector3) -> void:
	if e2 == null:
		e2 = Node3D.new()
		e2.set_script(load("res://enemy.gd"))
		e2.ai_on = false
		e2.position = pos
		main.add_child(e2)
	else:
		e2.global_position = pos
		e2.build()
	e2.block_chance = 0.0


func _setup(p, e) -> void:
	e.global_position = Vector3(0, 0, -1.5)
	e.build()
	e.block_chance = 0.0
	p.global_position = Vector3(0, 0, -0.6)
	p.rotation.y = 0
	p.velocity = Vector3.ZERO
	p.attack = ""
	p.hurt = 0.0


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	var k := f - pt
	var pel: Vector3 = e.parts.pelvis.global_position
	match phase:
		"throw":
			if k == 10:
				p.throw_move = "throw"
				_setup(p, e)
				_second(Vector3(0, 0, -6.0))   # plus loin devant : la cible du lancer
			if k == 20:
				Input.action_press("grab")   # chope, puis R1 maintenu = élan
			if k == 40:
				_check(p.attack == "collar" and e.state == "held", "chope (%s, %s)" % [p.attack, e.state])
			if k == 145:
				var back: float = (e.parts.chest.global_position - p.global_position).dot(-p.global_basis.z)
				_check(p.throw_t >= p.THROW_WIND - 0.01 and back < 0.0, "R1 maintenu : élan automatique, il passe derrière l'épaule (%.2f s d'élan, buste à %.2f m devant)" % [p.throw_t, back])
				start = pel
				Input.action_release("grab")   # lancé
			if k > 145:
				peak = maxf(peak, ((pel - start) * Vector3(1, 0, 1)).length())
			if k == 150:
				_check(p.attack == "throw_release" and e.state == "down", "R1 relâché : il est lancé (%s, %s)" % [p.attack, e.state])
			if k == 330:
				_check(peak > 3.0, "lancé devant, loin (%.1f m)" % peak)
				_check(e2.state != "stand" and e2.hp < e2.MAX_HP, "en vol, son corps percute un autre sbire (%s, vie %.0f)" % [e2.state, e2.hp])
				_check(e.hp < e.MAX_HP, "et il prend le coup en touchant le sol (vie %.0f)" % e.hp)
				# (la massue humaine a été abandonnée : ses tests ne tournent plus)
				print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
				quit(1 if fails.size() else 0)
		"club":
			if k == 10:
				p.throw_move = "club"
				_setup(p, e)
				_second(Vector3(20, 0, 20))
			if k == 20:
				Input.action_press("grab")   # R1 maintenu : par les pieds
			if k == 60:
				var ankle: Vector3 = e.parts.shin_l.global_transform * Vector3(0, -0.225, 0)
				var hand: Vector3 = p.j.fist_r.global_position if p.swap_feet else p.j.fist_l.global_position
				_check(p.attack == "club_hold" and e.state == "swung", "massue : attrapé par les pieds, debout il bascule (%s, %s)" % [p.attack, e.state])
				_check(ankle.distance_to(hand) < 0.2, "ses chevilles dans tes mains (%.2f m)" % ankle.distance_to(hand))
				start = p.global_position
				Input.action_press("up")   # on marche en le traînant
			if k == 110:
				Input.action_release("up")
				_check(((p.global_position - start) * Vector3(1, 0, 1)).length() > 0.5 and e.state == "swung", "on marche en le traînant")
				var fwd: Vector3 = -p.global_basis.z
				_second(p.global_position + fwd * 1.4)   # un sbire devant
				p.hp = 100.0
			if k == 130:
				Input.action_press("light")
			if k == 132:
				Input.action_release("light")
			if k == 136:
				_check(p.attack == "club_swing", "X : coup de massue (%s)" % p.attack)
			if p.attack == "club_swing" and p.t > 0.2 and p.t < 0.4:
				var side: float = (e.parts.pelvis.global_position - p.global_position).dot(p.global_basis.x)
				var behind: float = (e.parts.pelvis.global_position - p.global_position).dot(p.global_basis.z)
				circled = circled or side > 0.5 or behind > 0.5
			if k == 230:
				_check(circled, "le corps passe sur le côté / vers l'arrière avant de retomber (grand cercle)")
				_check(e2.state != "stand" and e2.hp < e2.MAX_HP, "le corps abattu percute le sbire devant (%s, vie %.0f)" % [e2.state, e2.hp])
				_check(e.hp < e.MAX_HP and p.attack == "club_hold", "la massue prend un coup aussi, et on la tient toujours (vie %.0f, %s)" % [e.hp, p.attack])
			if k in [235, 325]:
				Input.action_press("light")
			if k in [237, 327]:
				Input.action_release("light")
			if k == 430:
				_check(p.club_hits == 3 and e.state != "swung" and p.attack == "", "au bout de 3 coups, il est lâché tout seul (%d coups, %s)" % [p.club_hits, e.state])
				Input.action_release("grab")
				_go("release")
		"release":   # R1 relâché avant les 3 coups : on le lâche
			if k == 10:
				_setup(p, e)
			if k == 20:
				Input.action_press("grab")
			if k == 60:
				_check(p.attack == "club_hold", "repris par les pieds (%s)" % p.attack)
				Input.action_release("grab")
			if k == 64:
				_check(e.state != "swung" and p.attack == "", "R1 relâché : on le lâche (%s)" % e.state)
				print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
				quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

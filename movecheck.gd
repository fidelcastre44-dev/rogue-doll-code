extends SceneTree
## Auto-test saut + roulade : godot --headless --path . -s movecheck.gd --fixed-fps 120
## Saut : ~1 m de haut, retombe et se pose. Roulade : avance de plusieurs mètres, fait un tour complet, se relève en garde.

var main: Node3D
var f := 0
var fails := []
var top := 0.0
var flipped := false
var roll_start := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false   # sac de frappe immobile pour ce test
	root.add_child(main)
	main.get_node("Player").dodge_move = "roll"   # la roulade est maintenant une amélioration (le balayage est testé dans movescheck)


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	if f == 20:
		main.enemy.position = Vector3(30, 0, 30)   # hors du chemin
		main.enemy.build()
		p.global_position = Vector3(0, 0, 0.5)
		p.rotation.y = 0
	if f == 60:
		Input.action_press("jump")
	if f == 61:
		Input.action_release("jump")
	if f > 60 and f < 200:
		top = maxf(top, p.global_position.y)
	if f == 200:
		_check(top > 0.8 and top < 1.4, "le saut monte à ~1 m (%.2f m)" % top)
		_check(p.is_on_floor() and p.land <= 0, "il est retombé et posé (au sol : %s)" % p.is_on_floor())
		_check(p.j.foot_l.global_position.y < 0.05, "pieds de nouveau plantés (pied gauche à %.2f m)" % p.j.foot_l.global_position.y)
	if f == 240:
		roll_start = p.global_position
		Input.action_press("left")
		Input.action_press("roll")
	if f == 241:
		Input.action_release("roll")
	if f > 240 and f < 310 and p.j.hips.global_basis.y.y < -0.5:
		flipped = true
	if f == 245:
		_check(p.is_invulnerable(), "invulnérable pendant la roulade")
	if f == 300:
		Input.action_release("left")
		var d: float = (p.global_position - roll_start).length()
		_check(d > 2.5, "la roulade avance de plusieurs mètres (%.2f m)" % d)
		_check(flipped, "il fait un tour complet sur lui-même (tête en bas à un moment)")
	if f == 330:
		_check(p.roll < 0 and not p.is_invulnerable(), "roulade terminée, plus invulnérable")
		_check(absf(p.j.head.global_position.y - 1.6) < 0.15, "il se relève en garde (tête à %.2f m)" % p.j.head.global_position.y)
		print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
		quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

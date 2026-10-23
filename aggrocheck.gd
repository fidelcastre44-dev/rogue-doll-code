extends SceneTree
## Auto-test agressivité : godot --headless --path . -s aggrocheck.gd --fixed-fps 120
## Joueur immobile pendant 8 s : le sbire frappe souvent, enchaîne des séries, et ses coups enchaînés partent vite.

var main: Node3D
var f := 0
var fails := []
var strikes := []   # instants (s) où un coup part
var prev_ai := ""
var first := -1.0


func _initialize() -> void:
	seed(7)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	p.hp = 1000.0   # il encaisse tout, on compte
	var now := f / 120.0
	if e.ai == "strike" and prev_ai != "strike":
		strikes.append(now)
	if e.ai == "windup" and first < 0:
		first = now
	prev_ai = e.ai
	if f == 120 * 8:
		var chained := 0
		var gap := INF
		for i in range(1, strikes.size()):
			var d: float = strikes[i] - strikes[i - 1]
			gap = minf(gap, d)
			if d < 0.6:
				chained += 1
		print("  coups : %s" % str(strikes.map(func(x): return snappedf(x, 0.01))))
		_check(first > 0 and first < 1.8, "il passe à l'attaque vite (premier armé à %.2f s)" % first)
		_check(strikes.size() >= 7, "il frappe souvent (%d coups en 8 s)" % strikes.size())
		_check(chained >= 3, "il enchaîne des séries (%d coups enchaînés)" % chained)
		_check(gap > 0.3, "mais chaque coup reste visible avant de partir (écart min %.2f s)" % gap)
		print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
		quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

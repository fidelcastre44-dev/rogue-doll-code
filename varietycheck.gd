extends SceneTree
## Auto-test de la variété des chutes : godot --headless --path . -s varietycheck.gd --fixed-fps 120
## 4 uppercuts identiques (qui le mettent KO) sur un ennemi neuf au même endroit : les 4 chutes doivent finir différemment,
## tout en restant raisonnables (il décolle, distance correcte) et sans articulation qui lâche.

var main: Node3D
var f := 0
var run := 0
var t0 := 0
var peak := 0.0
var max_gap := 0.0
var ends := []   # [position du bassin relative au départ, orientation du torse]
var fails := []
var start := Vector3.ZERO


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.get_node("Enemy").ai_on = false
	root.add_child(main)


func _process(_dt: float) -> bool:
	f += 1
	var p = main.player
	var e = main.enemy
	if e.parts.is_empty():
		return false
	var k := f - t0
	if k == 20:   # nouvelle manche : ennemi neuf, joueur placé pareil, uppercut
		e.global_position = Vector3(0, 0, -1.5)
		e.build()
	if k == 22:
		start = e.parts.pelvis.global_position
		p.global_position = Vector3(start.x, 0, start.z + 0.9)
		p.velocity = Vector3.ZERO
		p.rotation.y = 0
		e.hp = 10.0   # l'uppercut le met KO : il s'écrase en ragdoll (sinon il se rattrape sur ses pieds)
		p.start("upper")
	if k > 22:
		if e.state in ["down", "launch", "dead"]:
			peak = maxf(peak, e.parts.pelvis.global_position.y)
		for d in e.BODY:
			if d[1] != "":
				max_gap = maxf(max_gap, e.parts[d[1]].to_global(d[4] - e.rest_center[d[1]]).distance_to(e.parts[d[0]].to_global(d[4] - d[3])))
	if k == 190:   # ~1,4 s après l'uppercut : il est retombé
		var off: Vector3 = e.parts.pelvis.global_position - start
		ends.append([off, e.parts.chest.global_basis.y])
		print("  chute %d : recul %.2f m, décalage latéral %+.2f m, sommet %.2f m, torse vers (%.1f, %.1f, %.1f)" % [run + 1, -off.z, off.x, peak, ends[-1][1].x, ends[-1][1].y, ends[-1][1].z])
		_check(peak > 1.4, "chute %d : il décolle (sommet %.2f m)" % [run + 1, peak])
		_check(-off.z > 1.0 and -off.z < 6.0, "chute %d : distance raisonnable, rebond compris (%.2f m)" % [run + 1, -off.z])
		peak = 0.0
		run += 1
		t0 = f
		if run == 4:
			var min_diff := INF
			for a in range(4):
				for b in range(a + 1, 4):
					var dd: float = ends[a][0].distance_to(ends[b][0]) + ends[a][1].distance_to(ends[b][1])
					min_diff = minf(min_diff, dd)
			_check(min_diff > 0.3, "les 4 chutes sont toutes différentes (écart minimal %.2f)" % min_diff)
			_check(max_gap < 0.08, "aucune articulation ne lâche (écart max %.3f m)" % max_gap)
			print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
			quit(1 if fails.size() else 0)
	return false


func _check(ok: bool, what: String) -> void:
	print(("  [ok] " if ok else "  [ECHEC] ") + what)
	if not ok:
		fails.append(what)

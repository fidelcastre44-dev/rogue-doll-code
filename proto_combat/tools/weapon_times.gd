extends SceneTree
## Trajectoire de la pointe de l'arme (prise Weapons.GRIP) pendant chaque animation : instant où elle va le plus vite
## (= impact), où elle est alors (repère du perso : +Z devant, +Y haut, +X gauche du perso), et sa portée devant.
## godot --headless --path . -s tools/weapon_times.gd
const LIST := [["sword", "sword_a"], ["sword", "sword_b"], ["sword", "sword_c"], ["sword", "sword_attack"], ["sword", "sword_dash"],
	["sword", "sword_combo"], ["axe", "chop"], ["axe", "sword_attack"], ["bat", "cmu/bat_swing"], ["bat", "chop"], ["katana", "sword_dash"], ["katana", "sword_b"]]
func pose_at(a: Animation, sk: Skeleton3D, t: float) -> Dictionary:
	var loc := {}
	for i in a.get_track_count():
		var bn := str(a.track_get_path(i).get_concatenated_subnames())
		var b := sk.find_bone(bn)
		if b < 0: continue
		if not loc.has(b): loc[b] = sk.get_bone_rest(b)
		var tr: Transform3D = loc[b]
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			tr.basis = Basis(a.rotation_track_interpolate(i, t))
		elif a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			tr.origin = a.position_track_interpolate(i, t)
		loc[b] = tr
	var g := {}
	for b in sk.get_bone_count():
		var l: Transform3D = loc.get(b, sk.get_bone_rest(b))
		var p := sk.get_bone_parent(b)
		g[b] = l if p < 0 else (g[p] as Transform3D) * l
	return g
func _init():
	var m: Node3D = load("res://assets/hero/male/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var L: AnimationLibrary = load("res://assets/anims/lib_male.res")
	var C: AnimationLibrary = load("res://assets/anims/lib_cmu_male.res")
	var hb := sk.find_bone("hand_r")
	for e in LIST:
		var d: Dictionary = Weapons.DEFS[e[0]]
		var an: String = e[1]
		var a: Animation = C.get_animation(an.substr(4)) if an.begins_with("cmu/") else L.get_animation(an)
		var t := 0.0
		var prev := Vector3.ZERO
		var best := 0.0
		var bt := 0.0
		var bp := Vector3.ZERO
		var maxz := -9.0
		var maxz_t := 0.0
		var path := ""
		while t <= a.length:
			var hg: Transform3D = pose_at(a, sk, t)[hb]
			var tip: Vector3 = hg * Weapons.GRIP * Vector3(0, d.blade.y, 0)
			if t > 0.0:
				var sp := tip.distance_to(prev) * 60.0
				if sp > best and tip.z > 0.1:
					best = sp; bt = t; bp = tip
			if tip.z > maxz:
				maxz = tip.z; maxz_t = t
			prev = tip
			t += 1.0 / 60.0
		var k := 0.0
		while k <= 1.001:
			var hg2: Transform3D = pose_at(a, sk, a.length * k)[hb]
			var tp: Vector3 = hg2 * Weapons.GRIP * Vector3(0, d.blade.y, 0)
			path += "(%.1f,%.1f,%.1f) " % [tp.x, tp.y, tp.z]
			k += 0.125
		print("%-7s %-14s len %.2f | vitesse max %.1f m/s à %.2f s, pointe %s | plus loin devant %.2f m à %.2f s" % [e[0], an, a.length, best, bt, snapped(bp, Vector3(0.01,0.01,0.01)), maxz, maxz_t])
		print("        ", path)
	quit()

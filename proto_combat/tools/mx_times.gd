extends SceneTree
## Instants d'impact d'animations (bibliothèques lib_male / lib_cmu_male / lib_mx_male) : pics de vitesse d'un membre ou de
## la pointe d'une arme (prise Weapons.GRIP), avec sa position à ce moment (repère du perso : +Z devant, +Y haut).
## LIST="mx/enemy__mma_side_kick:foot_r,mx/axe__three_hit_combo:blade:axe" godot --headless --path . -s tools/mx_times.gd

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


func _init() -> void:
	var m: Node3D = load("res://assets/hero/male/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var libs := {"": load("res://assets/anims/lib_male.res"), "cmu": load("res://assets/anims/lib_cmu_male.res"), "mx": load("res://assets/anims/lib_mx_male.res")}
	for e in OS.get_environment("LIST").split(",", false):
		var parts := e.split(":")
		var an := parts[0]
		var lib: AnimationLibrary = libs[an.get_slice("/", 0)] if an.contains("/") else libs[""]
		var a: Animation = lib.get_animation(an.get_slice("/", 1) if an.contains("/") else an)
		var limb := parts[1]
		var b := sk.find_bone("hand_r" if limb == "blade" else limb)
		var tipy := 0.0
		if limb == "blade":
			tipy = (Weapons.DEFS[parts[2]].blade as Vector2).y
		var pts := []
		var t := 0.0
		while t <= a.length + 0.0001:
			var gt: Transform3D = pose_at(a, sk, t)[b]
			var p: Vector3 = (gt * Weapons.GRIP * Vector3(0, tipy, 0)) if limb == "blade" else gt.origin
			pts.append([t, p])
			t += 1.0 / 60.0
		var sp := [0.0]
		for i in range(1, pts.size()):
			sp.append((pts[i][1] as Vector3).distance_to(pts[i - 1][1]) * 60.0)
		var mx: float = sp.max()
		var peaks := []
		for i in range(2, sp.size() - 2):
			if sp[i] >= sp[i - 1] and sp[i] >= sp[i + 1] and sp[i] >= sp[i - 2] and sp[i] >= sp[i + 2] and sp[i] > mx * 0.45:
				var p: Vector3 = pts[i][1]
				var v: Vector3 = ((pts[i + 1][1] as Vector3) - (pts[i - 1][1] as Vector3)).normalized()
				peaks.append("%.2fs %.0fm/s devant %.2f haut %.2f côté %.2f | dir devant %+.2f haut %+.2f côté %+.2f" % [pts[i][0], sp[i], p.z, p.y, p.x, v.z, v.y, v.x])
		print("%s [%s] len %.2f\n   %s" % [an, limb, a.length, "\n   ".join(peaks)])
	quit()

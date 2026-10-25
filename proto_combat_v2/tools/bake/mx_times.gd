extends SceneTree
## Instants d'impact : pics de vitesse d'un membre (repère du perso : +Z devant, +Y haut, +X gauche du perso), position et
## direction à ce moment. LIST="jab:hand_l,push_kick:foot_r" ou ALL=1 (mains, pieds, genoux, coudes pour chaque animation ; JSON dans OUT).
## godot --headless --path /home/claude/bake -s tools/mx_times.gd

const LIMBS := ["hand_l", "hand_r", "foot_l", "foot_r", "calf_l", "calf_r", "lowerarm_l", "lowerarm_r", "Head"]

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


func peaks(a: Animation, sk: Skeleton3D, limb: String) -> Array:
	var b := sk.find_bone(limb)
	var pts := []
	var t := 0.0
	while t <= a.length + 0.0001:
		pts.append([t, (pose_at(a, sk, t)[b] as Transform3D).origin])
		t += 1.0 / 60.0
	var sp := [0.0]
	for i in range(1, pts.size()):
		sp.append((pts[i][1] as Vector3).distance_to(pts[i - 1][1]) * 60.0)
	var mx: float = sp.max()
	var out := []
	for i in range(2, sp.size() - 2):
		if sp[i] >= sp[i - 1] and sp[i] >= sp[i + 1] and sp[i] >= sp[i - 2] and sp[i] >= sp[i + 2] and sp[i] > mx * 0.45:
			var p: Vector3 = pts[i][1]
			var v: Vector3 = ((pts[i + 1][1] as Vector3) - (pts[i - 1][1] as Vector3)).normalized()
			out.append({"t": snappedf(pts[i][0], 0.01), "speed": snappedf(sp[i], 0.1), "pos": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)], "dir": [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]})
	return out


func _init() -> void:
	var m: Node3D = load("res://assets/hero/male/Superhero_Male_FullBody.gltf").instantiate()
	var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
	var lib: AnimationLibrary = load("res://assets/anims/lib_mx_male.res")
	if OS.get_environment("ALL") != "":
		var res := {}
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			var d := {"len": snappedf(a.length, 0.01)}
			for limb in LIMBS:
				var pk := peaks(a, sk, limb)
				if not pk.is_empty():
					d[limb] = pk
			res[an] = d
		var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/mx_times.json"
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(JSON.stringify(res, " "))
		print("ok ", out)
	else:
		for e in OS.get_environment("LIST").split(",", false):
			var parts := e.split(":")
			var a: Animation = lib.get_animation(parts[0])
			print(parts[0], " [", parts[1], "] len %.2f" % a.length)
			for p in peaks(a, sk, parts[1]):
				print("   %.2fs %.1fm/s devant %.2f haut %.2f côté %.2f | dir devant %+.2f haut %+.2f côté %+.2f" % [p.t, p.speed, p.pos[2], p.pos[1], p.pos[0], p.dir[2], p.dir[1], p.dir[0]])
	quit()

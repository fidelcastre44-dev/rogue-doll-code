extends SceneTree
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
	var lib: AnimationLibrary = load("res://assets/anims/lib_mx_male.res")
	var pel := sk.find_bone("pelvis")
	var hr := sk.find_bone("hand_r")
	var rest: Basis = sk.get_bone_global_rest(pel).basis
	var pr := OS.get_environment("PAIR").split(",")
	var a: Animation = lib.get_animation(pr[0])
	var b: Animation = lib.get_animation(pr[1]) if pr.size() > 1 else null
	var t := 0.0
	while t <= a.length:
		var ga: Dictionary = pose_at(a, sk, t)
		var pa: Transform3D = ga[pel]
		var fw: Vector3 = (pa.basis * rest.inverse()) * Vector3(0, 0, 1)
		var line := "%.2f A pel(%.2f,%.2f,%.2f) fw(%.2f,%.2f) hand(%.2f,%.2f,%.2f)" % [t, pa.origin.x, pa.origin.y, pa.origin.z, fw.x, fw.z, (ga[hr] as Transform3D).origin.x, (ga[hr] as Transform3D).origin.y, (ga[hr] as Transform3D).origin.z]
		if b:
			var pb: Transform3D = (pose_at(b, sk, t))[pel]
			line += " | B pel(%.2f,%.2f,%.2f)" % [pb.origin.x, pb.origin.y, pb.origin.z]
		print(line)
		t += 0.1
	quit()

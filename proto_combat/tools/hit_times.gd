extends SceneTree
## Instant d'impact = moment où le membre est le plus loin devant (+Z). FK calculée à la main depuis les pistes.
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
	var spec := {"jab": "hand_l", "cross": "hand_r", "hook": "hand_r", "hook_rec": "hand_r", "throw": "hand_r", "slide_start": "foot_r", "sword_a": "hand_r", "sword_b": "hand_r", "sword_c": "hand_r", "dash": "hand_l",
		"c:kick_front": "foot_r", "c:kick_round": "foot_r", "c:kick_low": "foot_r", "c:uppercut": "hand_l", "c:hook_box": "hand_l", "c:jab_box": "hand_l", "c:cross_box": "hand_r", "roll": "pelvis", "knockback": "pelvis", "jump_start": "pelvis", "ninja_start": "pelvis"}
	for an in spec:
		var a: Animation = C.get_animation(an.substr(2)) if an.begins_with("c:") else L.get_animation(an)
		var best := -99.0; var bt := 0.0; var bp := Vector3.ZERO
		var t := 0.0
		var b := sk.find_bone(spec[an])
		while t <= a.length:
			var p: Vector3 = (pose_at(a, sk, t)[b] as Transform3D).origin
			if p.z > best: best = p.z; bt = t; bp = p
			t += 1.0 / 60.0
		var pb := sk.find_bone("pelvis")
		var s0: Vector3 = (pose_at(a, sk, 0)[pb] as Transform3D).origin
		var s1: Vector3 = (pose_at(a, sk, a.length)[pb] as Transform3D).origin
		print("%-14s len %.3f hit %.3f tip %s | pelvis %s -> %s" % [an, a.length, bt, bp, s0, s1])
	quit()

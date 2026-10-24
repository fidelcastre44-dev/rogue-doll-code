extends SceneTree
## Audit des coups (bilan v0.113) : membre qui frappe à l impact, sa direction comparée au recul kb ; tête des réactions.

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



const EFF := ["hand_l", "hand_r", "foot_l", "foot_r"]
const WPN := {"sw_": "sword", "ka_": "katana", "ax_": "axe", "bt_": "bat"}
var sk: Skeleton3D
var libs := {}

func anim_of(an: String) -> Animation:
	var lib: AnimationLibrary = libs[an.get_slice("/", 0)] if an.contains("/") else libs[""]
	var nm := an.get_slice("/", 1) if an.contains("/") else an
	return lib.get_animation(nm) if lib.has_animation(nm) else null

func eff_pos(a: Animation, t: float, e: String, tipy: float) -> Vector3:
	var g: Dictionary = pose_at(a, sk, t)
	if e == "blade":
		return (g[sk.find_bone("hand_r")] as Transform3D) * Weapons.GRIP * Vector3(0, tipy, 0)
	return (g[sk.find_bone(e)] as Transform3D).origin

func head_pos(a: Animation, t: float) -> Vector3:
	var g: Dictionary = pose_at(a, sk, t)
	return (g[sk.find_bone("Head") if sk.find_bone("Head") >= 0 else sk.find_bone("head")] as Transform3D).origin

func v3(v: Vector3) -> String:
	return "devant %+.2f haut %+.2f côté %+.2f" % [v.z, v.y, v.x]

func _init() -> void:
	var m: Node3D = load("res://assets/hero/male/Superhero_Male_FullBody.gltf").instantiate()
	sk = m.find_child("Skeleton3D", true, false)
	libs = {"": load("res://assets/anims/lib_male.res"), "cmu": load("res://assets/anims/lib_cmu_male.res"), "mx": load("res://assets/anims/lib_mx_male.res")}
	var all := {}
	for k in Moves.M:
		all[k] = Moves.M[k]
	for k in Dummy.ATTACKS:
		all["sbire:" + k] = Dummy.ATTACKS[k]
	for id in all:
		var mv: Dictionary = all[id]
		if not mv.has("anim"):
			continue
		var a := anim_of(mv.anim)
		if a == null:
			print("MANQUE ", id, " ", mv.anim)
			continue
		var wid := ""
		for p in WPN:
			if str(id).begins_with(p):
				wid = WPN[p]
		var effs: Array = ["blade"] if wid != "" else EFF
		var tipy: float = (Weapons.DEFS[wid].blade as Vector2).y if wid != "" else 0.0
		var th: float = mv.hit
		var best := ""
		var bv := Vector3()
		var bp := Vector3()
		var bs := -1.0
		for e in effs:
			# déplacement du membre pendant les 0,1 s qui mènent à l'impact (à l'impact même, un poing tendu est à l'arrêt)
			var p0 := eff_pos(a, maxf(th - 0.1, 0.0), e, tipy)
			var p1 := eff_pos(a, th, e, tipy)
			var v := (p1 - p0) * 10.0
			if v.length() > bs:
				bs = v.length()
				best = e
				bv = v
				bp = p1
		var peak_t := th
		var pk := 0.0
		var t: float = maxf(float(mv.get("from", 0.0)), th - 0.3)
		var t_end: float = minf(float(mv.get("end", a.length)), th + 0.3)
		while t <= t_end:
			var s := (eff_pos(a, t + 1.0 / 60.0, best, tipy) - eff_pos(a, t - 1.0 / 60.0, best, tipy)).length() * 30.0
			if s > pk:
				pk = s
				peak_t = t
			t += 1.0 / 60.0
		var kb = mv.get("kb", [0.0, 0.0])
		var kbv := Vector3(0, 0, float(kb)) if typeof(kb) != TYPE_ARRAY else Vector3(0, float(kb[1]), float(kb[0]))
		var ang := rad_to_deg(bv.normalized().angle_to(kbv.normalized())) if kbv.length() > 0.01 else -1.0
		var box = mv.get("box", null)
		print("ROW %s | %s | %s | membre %s %.1f m/s | dir %s | pos %s | pic %.2fs (hit %.2fs) | kb %s %s | angle %.0f" % [id, mv.anim, mv.get("effect", ""), best, bs, v3(bv.normalized()), v3(bp), peak_t, th, str(kb), ("box " + str(box)) if box != null else "", ang])
	for key in Dummy.HIT_ANIMS:
		for an in Dummy.HIT_ANIMS[key]:
			var a := anim_of(an)
			if a == null:
				continue
			var h0 := head_pos(a, 0.0)
			var mx := Vector3()
			var ml := 0.0
			var t := 0.0
			while t < minf(a.length, 0.6):
				var d := head_pos(a, t) - h0
				if d.length() > ml:
					ml = d.length()
					mx = d
				t += 1.0 / 30.0
			print("HIT %s | %s | tête max %s (%.2f m)" % [key, an, v3(mx), ml])
	quit()

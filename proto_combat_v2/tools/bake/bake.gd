extends SceneTree
## Reprend les animations Mixamo listées dans anim_list.json (liens dans res://src/<nom>.fbx, projet de cuisson préparé par
## tools/bake/setup_bake.sh) sur nos squelettes (héros homme / femme, mannequin) et écrit res://assets/anims/lib_mx_<cible>.res
## (bibliothèque « mx/ » du jeu) + mx_info.json (durée, boucle, déplacement du bassin, instant où le pied retouche le sol).
## Méthode éprouvée de l'ancien proto (par direction des segments ; bassin, dos, cou, tête par rotation ; mains orientées).
## Le déplacement horizontal du bassin (root motion) est retiré linéairement et noté dans "move" (le jeu déplace la capsule),
## sauf pour les paires (keep_root) où attaquant et victime gardent leur repère commun.
## godot --headless --path /home/claude/bake -s tools/bake.gd      (ONLY=jab,cross pour ne refaire qu'une partie)

const SRC_DIR := "res://src"
const FULL := {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2", "neck_01": "Neck", "Head": "Head"}
const AIM := {
	"upperarm_l": ["LeftArm", "LeftForeArm"], "lowerarm_l": ["LeftForeArm", "LeftHand"],
	"upperarm_r": ["RightArm", "RightForeArm"], "lowerarm_r": ["RightForeArm", "RightHand"],
	"clavicle_l": ["LeftShoulder", "LeftArm"], "clavicle_r": ["RightShoulder", "RightArm"],
	"thigh_l": ["LeftUpLeg", "LeftLeg"], "calf_l": ["LeftLeg", "LeftFoot"], "foot_l": ["LeftFoot", "LeftToeBase"], "ball_l": ["LeftToeBase", "LeftToe_End"],
	"thigh_r": ["RightUpLeg", "RightLeg"], "calf_r": ["RightLeg", "RightFoot"], "foot_r": ["RightFoot", "RightToeBase"], "ball_r": ["RightToeBase", "RightToe_End"],
}
const HANDS := {"hand_l": ["LeftHand", "LeftHandMiddle1", "LeftHandIndex1", "LeftHandPinky1"], "hand_r": ["RightHand", "RightHandMiddle1", "RightHandIndex1", "RightHandPinky1"]}
const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const TARGETS := {
	"male": "res://assets/hero/male/Superhero_Male_FullBody.gltf",
	"female": "res://assets/hero/female/Superhero_Female_FullBody.gltf",
	"dummy": "res://assets/anims/Mannequin_F.glb",
}
const FPS := 30.0
var LIST := {}
var MIRROR := []
var NO_VERT := []
var KEEP_ROOT := []
var FLAT := []        # bassin fixé à sa hauteur de repos (coups aériens : la capsule donne la hauteur)
var LOOPS := []


func _init() -> void:
	var only: Array = Array(OS.get_environment("ONLY").split(",", false))
	var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://anim_list.json"))
	for k in j:
		if k.begins_with("_"):
			continue
		var opts: Array = j[k][1]
		LIST[k] = j[k][0]
		if "loop" in opts: LOOPS.append(k)
		if "mirror" in opts: MIRROR.append(k)
		if "no_vert" in opts: NO_VERT.append(k)
		if "keep_root" in opts: KEEP_ROOT.append(k)
		if "flat" in opts: FLAT.append(k)
	var files := []
	for k in LIST:
		if only.is_empty() or k in only:
			if ResourceLoader.exists(SRC_DIR + "/" + k + ".fbx"):
				files.append(k)
			else:
				push_warning("source absente : " + k)
	files.sort()
	var info := {}
	for t in TARGETS:
		var tgt: Node3D = load(TARGETS[t]).instantiate()
		var tsk: Skeleton3D = tgt.find_child("Skeleton3D", true, false)
		var path := "res://assets/anims/lib_mx_%s.res" % t
		var lib: AnimationLibrary = load(path) if ResourceLoader.exists(path) and not only.is_empty() else AnimationLibrary.new()
		for nm in files:
			var src: Node = load(SRC_DIR + "/" + nm + ".fbx").instantiate()
			var ssk: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
			var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
			var an := "mixamo_com" if ap.has_animation("mixamo_com") else ap.get_animation_list()[0]
			for mir in ([false, true] if nm in MIRROR else [false]):
				var nm2: String = nm + ("_m" if mir else "")
				var res := _bake(ap.get_animation(an), ssk, tsk, nm2, mir)
				if lib.has_animation(nm2):
					lib.remove_animation(nm2)
				(res[0] as Animation).compress()
				lib.add_animation(nm2, res[0])
				if t == "male":
					info[nm2] = res[1]
			src.free()
		ResourceSaver.save(lib, path)
		print(t, " : ", lib.get_animation_list().size(), " animations")
		tgt.free()
	if not info.is_empty():
		var old := {}
		if FileAccess.file_exists("res://assets/anims/mx_info.json"):
			old = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anims/mx_info.json"))
		old.merge(info, true)
		var fo := FileAccess.open("res://assets/anims/mx_info.json", FileAccess.WRITE)
		fo.store_string(JSON.stringify(old, "  ", true))
	print("mixamo ok")
	quit()


const MX := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))


func _swap(n: String) -> String:
	if n.begins_with("Left"):
		return "Right" + n.substr(4)
	if n.begins_with("Right"):
		return "Left" + n.substr(5)
	return n


## Miroir gauche / droite d'un dictionnaire de poses globales (plan x = 0 du squelette source).
func _mirror(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		var tr: Transform3D = d[k]
		out[_swap(k)] = Transform3D(MX * tr.basis * MX, MX * tr.origin)
	return out


## Pose globale (repère du squelette source) de chaque os à l'instant t.
func _src_pose(a: Animation, sk: Skeleton3D, t: float, mir := false) -> Dictionary:
	var loc := {}
	for i in a.get_track_count():
		var bn := str(a.track_get_path(i).get_concatenated_subnames())
		var b := sk.find_bone(bn)
		if b < 0:
			continue
		if not loc.has(b):
			loc[b] = sk.get_bone_rest(b)
		var tr: Transform3D = loc[b]
		match a.track_get_type(i):
			Animation.TYPE_ROTATION_3D: tr.basis = Basis(a.rotation_track_interpolate(i, t))
			Animation.TYPE_POSITION_3D: tr.origin = a.position_track_interpolate(i, t)
		loc[b] = tr
	var g := {}
	var out := {}
	for b in sk.get_bone_count():
		var l: Transform3D = loc.get(b, sk.get_bone_rest(b))
		var p := sk.get_bone_parent(b)
		g[b] = l if p < 0 else (g[p] as Transform3D) * l
		out[sk.get_bone_name(b).trim_prefix("mixamorig_")] = g[b]
	return _mirror(out) if mir else out


func _bake(a: Animation, ssk: Skeleton3D, tsk: Skeleton3D, nm: String, mir := false) -> Array:
	var srest := {}
	for b in ssk.get_bone_count():
		srest[ssk.get_bone_name(b).trim_prefix("mixamorig_")] = ssk.get_bone_global_rest(b)
	if mir:
		srest = _mirror(srest)
	var shh: float = (srest["Hips"] as Transform3D).origin.y
	var pel := tsk.find_bone("pelvis")
	var scale := tsk.get_bone_global_rest(pel).origin.y / maxf(shh, 0.01)
	var out := Animation.new()
	var tracks := {}
	var fingers := {}   # os cible -> [source a, source b]
	for side in ["l", "r"]:
		var S := "Left" if side == "l" else "Right"
		for fg in FINGERS:
			for k in [1, 2, 3]:
				var tb := "%s_%02d_%s" % [fg.to_lower(), k, side]
				if tsk.find_bone(tb) >= 0:
					fingers[tb] = ["%sHand%s%d" % [S, fg, k], "%sHand%s%d" % [S, fg, k + 1]]
	var aimed := AIM.duplicate()
	aimed.merge(fingers)
	for bn in FULL.keys() + aimed.keys() + HANDS.keys():
		if tsk.find_bone(bn) < 0:
			continue
		var ti := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(ti, NodePath("Armature/Skeleton3D:" + bn))
		tracks[bn] = ti
	var pti := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(pti, NodePath("Armature/Skeleton3D:pelvis"))
	var dur := a.length
	var n := int(ceil(dur * FPS)) + 1
	var prevq := {}
	var s0 := _src_pose(a, ssk, 0.0, mir)
	var start: Vector3 = (s0["Hips"] as Transform3D).origin
	var root := tsk.find_bone("root")
	var rootg := tsk.get_bone_global_rest(root) if root >= 0 else Transform3D()
	var last_hp := Vector3.ZERO
	var feet := []      # hauteur du pied le plus bas (m, cible) à chaque image : pour démarrer une réception au contact
	# déplacement horizontal total (root motion) : retiré linéairement (le jeu déplace la capsule lui-même), noté dans mx_info
	var send := _src_pose(a, ssk, dur, mir)
	var drift: Vector3 = ((send["Hips"] as Transform3D).origin - start) * scale
	if not (nm.trim_suffix("_m") in NO_VERT):
		drift.y = 0
	var keep: bool = nm.trim_suffix("_m") in KEEP_ROOT
	if keep:
		drift = Vector3.ZERO
	for fr in n:
		var tg: float = minf(fr / FPS, dur)
		var src := _src_pose(a, ssk, tg, mir)
		var G := {}
		for b in tsk.get_bone_count():
			var bn := tsk.get_bone_name(b)
			var par := tsk.get_bone_parent(b)
			var pg: Basis = G[par] if par >= 0 else Basis()
			var g: Basis = pg * tsk.get_bone_rest(b).basis
			if FULL.has(bn) and src.has(FULL[bn]):
				var sname: String = FULL[bn]
				var delta: Basis = (src[sname] as Transform3D).basis * (srest[sname] as Transform3D).basis.inverse()
				g = delta * tsk.get_bone_global_rest(b).basis
			elif aimed.has(bn) or HANDS.has(bn):
				var pair: Array = HANDS[bn] if HANDS.has(bn) else aimed[bn]
				if src.has(pair[0]) and src.has(pair[1]):
					var s: Vector3 = (src[pair[1]] as Transform3D).origin - (src[pair[0]] as Transform3D).origin
					var child := -1
					var want_child := ""
					if HANDS.has(bn):
						want_child = "middle_01_" + bn.right(1)
					for cb in tsk.get_bone_children(b):
						if want_child == "" or tsk.get_bone_name(cb) == want_child:
							child = cb
							break
					if child >= 0 and s.length() > 0.0001:
						var dl := tsk.get_bone_rest(child).origin.normalized()
						var d := (g * dl).normalized()
						g = Basis(Quaternion(d, s.normalized())) * g
						if HANDS.has(bn) and src.has(pair[2]) and src.has(pair[3]):
							# côté de la main : index -> auriculaire, comme la source
							var side := bn.right(1)
							var ti_b := tsk.find_bone("index_01_" + side)
							var tp_b := tsk.find_bone("pinky_01_" + side)
							if ti_b >= 0 and tp_b >= 0:
								var lat_l := tsk.get_bone_rest(ti_b).origin - tsk.get_bone_rest(tp_b).origin
								var lat_t := g * lat_l
								var lat_s: Vector3 = (src[pair[2]] as Transform3D).origin - (src[pair[3]] as Transform3D).origin
								var ax := s.normalized()
								lat_t = (lat_t - ax * lat_t.dot(ax))
								lat_s = (lat_s - ax * lat_s.dot(ax))
								if lat_t.length() > 0.0001 and lat_s.length() > 0.0001:
									var ang := lat_t.normalized().signed_angle_to(lat_s.normalized(), ax)
									g = Basis(ax, ang) * g
			G[b] = g.orthonormalized()
			if tracks.has(bn):
				var lq: Quaternion = (pg.inverse() * (G[b] as Basis)).get_rotation_quaternion().normalized()
				if prevq.has(bn) and (prevq[bn] as Quaternion).dot(lq) < 0:
					lq = -lq
				prevq[bn] = lq
				out.rotation_track_insert_key(tracks[bn], tg, lq)
		var hp: Vector3 = ((src["Hips"] as Transform3D).origin - (Vector3.ZERO if keep else Vector3(start.x, 0, start.z))) * scale
		last_hp = hp
		feet.append(minf((src["LeftToeBase"] as Transform3D).origin.y, (src["RightToeBase"] as Transform3D).origin.y) * scale)
		hp -= drift * (tg / maxf(dur, 0.001))
		if nm.trim_suffix("_m") in FLAT:
			hp = Vector3(0, tsk.get_bone_global_rest(pel).origin.y, 0)
		out.position_track_insert_key(pti, tg, rootg.affine_inverse() * hp)
	out.length = dur
	var loop: bool = nm.trim_suffix("_m") in LOOPS
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var hip0 := start * scale
	# instant où le pied touche le sol après avoir été en l'air (0 si l'animation part du sol)
	var gmin: float = feet.min()
	var ground_t := 0.0
	var was_up := false
	for i in feet.size():
		if feet[i] > gmin + 0.15:
			was_up = true
		elif was_up and feet[i] < gmin + 0.04:
			ground_t = i / FPS
			break
	return [out, {"length": dur, "loop": loop, "ground_t": snappedf(ground_t, 0.01), "move": [snappedf(last_hp.x, 0.01), snappedf(last_hp.y - hip0.y, 0.01), snappedf(last_hp.z, 0.01)],
		"start": [snappedf(hip0.x, 0.01), snappedf(hip0.z, 0.01)]}]

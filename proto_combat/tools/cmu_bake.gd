extends SceneTree
## Reprend des captures CMU (BVH, usage libre) sur nos squelettes (héros homme / femme, mannequin) et écrit
## res://assets/anims/lib_cmu_<cible>.res. Méthode « par direction » : chaque segment de membre de la cible vise la même
## direction que le segment de la capture ; bassin, dos, cou et tête copient la rotation de la capture (debout = identité).
## Le clip est tourné pour que le coup parte vers +Z (devant du perso) et recentré au départ.
## CMU=/home/claude/cmu/bvh  godot --headless --path . -s tools/cmu_bake.gd

# nom -> fichier, début, impact, fin (secondes de capture), membre qui frappe, vitesse de lecture
const CLIPS := {
	"kick_front": {"file": "144_05", "t0": 0.67, "hit": 1.22, "t1": 1.9, "tip": "RightToeBase", "speed": 1.35},
	"kick_round": {"file": "135_07", "t0": 0.55, "hit": 1.0, "t1": 1.32, "tip": "RightToeBase", "speed": 1.2},
	"kick_low": {"file": "10_01", "t0": 4.59, "hit": 5.0, "t1": 5.5, "tip": "RightToeBase", "speed": 1.2},
	"uppercut": {"file": "15_13", "t0": 54.62, "hit": 54.95, "t1": 55.3, "tip": "LeftHand", "speed": 1.0},
	"hook_box": {"file": "15_13", "t0": 68.0, "hit": 68.32, "t1": 68.7, "tip": "LeftHand", "speed": 1.0},
	"jab_box": {"file": "144_14", "t0": 3.32, "hit": 3.58, "t1": 3.82, "tip": "LeftHand", "speed": 1.0},
	"cross_box": {"file": "144_20", "t0": 1.38, "hit": 1.68, "t1": 1.95, "tip": "RightHand", "speed": 1.0},
	"guard_idle": {"file": "13_17", "t0": 0.45, "hit": 0.6, "t1": 1.225, "tip": "", "speed": 1.0, "loop": true},
	# relevés (repris de tools/cmu/clips.py du jeu principal) : à plat ventre 139_16, sur le dos 140_09 ; « hit » = fin, debout (donne le devant)
	"getup_front": {"file": "139_16", "t0": 1.62, "hit": 3.45, "t1": 3.45, "tip": "", "speed": 2.2},
	"getup_back": {"file": "140_09", "t0": 2.1, "hit": 4.48, "t1": 4.48, "tip": "", "speed": 2.2},
	# v0.112 : suspendu à une barre puis traction (01_12 « playground - climb, pull up, dangle »). Essayé et écarté : la batte
	# 124_07 « Baseball Swing » (la capture n'a pas les poignets : la batte reste sur l'épaule).
	"hang": {"file": "01_12", "t0": 2.0, "hit": 2.0, "t1": 4.2, "tip": "", "speed": 1.0, "loop": true},
	"hang_pull": {"file": "01_12", "t0": 4.3, "hit": 5.5, "t1": 5.55, "tip": "", "speed": 1.0},
}

const FULL := {"pelvis": "Hips", "spine_01": "LowerBack", "spine_02": "Spine", "spine_03": "Spine1", "neck_01": "Neck", "Head": "Head"}
const AIM := {
	"upperarm_l": ["LeftArm", "LeftForeArm"], "lowerarm_l": ["LeftForeArm", "LeftHand"],
	"upperarm_r": ["RightArm", "RightForeArm"], "lowerarm_r": ["RightForeArm", "RightHand"],
	"thigh_l": ["LeftUpLeg", "LeftLeg"], "calf_l": ["LeftLeg", "LeftFoot"], "foot_l": ["LeftFoot", "LeftToeBase"],
	"thigh_r": ["RightUpLeg", "RightLeg"], "calf_r": ["RightLeg", "RightFoot"], "foot_r": ["RightFoot", "RightToeBase"],
}
const TARGETS := {
	"male": "res://assets/hero/male/Superhero_Male_FullBody.gltf",
	"female": "res://assets/hero/female/Superhero_Female_FullBody.gltf",
	"dummy": "res://assets/anims/Mannequin_F.glb",
}
const FPS := 30.0

var joints := []   # {name, parent, offset, chans}
var frames := []
var ftime := 0.0


func _init() -> void:
	var dir := OS.get_environment("CMU")
	if dir == "":
		dir = "/home/claude/cmu/bvh"
	var cache := {}
	for t in TARGETS:
		var tgt: Node3D = load(TARGETS[t]).instantiate()
		var sk: Skeleton3D = tgt.find_child("Skeleton3D", true, false)
		var base: AnimationLibrary = load("res://assets/anims/lib_%s.res" % t)
		var fist := _fist(base.get_animation("jab"), sk)
		var lib := AnimationLibrary.new()
		var info := {}
		for name in CLIPS:
			var c: Dictionary = CLIPS[name]
			if not cache.has(c.file):
				_parse(dir + "/" + c.file + ".bvh")
				cache[c.file] = [joints.duplicate(true), frames, ftime]
			joints = cache[c.file][0]
			frames = cache[c.file][1]
			ftime = cache[c.file][2]
			var a := _bake(c, sk, fist)
			lib.add_animation(name, a)
			info[name] = {"length": a.length, "hit": (c.hit - c.t0) / c.speed}
		ResourceSaver.save(lib, "res://assets/anims/lib_cmu_%s.res" % t)
		if t == "male":
			var f := FileAccess.open("res://assets/anims/cmu_timing.json", FileAccess.WRITE)
			f.store_string(JSON.stringify(info, "  "))
			print(JSON.stringify(info))
		tgt.free()
	print("cmu ok")
	quit()


func _parse(path: String) -> void:
	joints = []
	frames = []
	var txt := FileAccess.get_file_as_string(path)
	var toks := txt.replace("\t", " ").replace("\r", "").split("\n")
	var stack := []
	var i := 0
	var motion := false
	var cur := -1
	while i < toks.size():
		var l := toks[i].strip_edges()
		i += 1
		if l == "":
			continue
		var w := l.split(" ", false)
		if motion:
			if w[0] == "Frames:":
				continue
			if w[0] == "Frame" and w[1] == "Time:":
				ftime = float(w[2])
				continue
			var row := PackedFloat32Array()
			for x in w:
				row.append(float(x))
			frames.append(row)
			continue
		match w[0]:
			"ROOT", "JOINT":
				joints.append({"name": w[1], "parent": stack.back() if stack.size() else -1, "offset": Vector3.ZERO, "chans": []})
				cur = joints.size() - 1
			"End":
				joints.append({"name": joints[stack.back()].name + "_end", "parent": stack.back(), "offset": Vector3.ZERO, "chans": []})
				cur = joints.size() - 1
			"{":
				stack.append(cur)
			"}":
				stack.pop_back()
				cur = stack.back() if stack.size() else -1
			"OFFSET":
				joints[cur].offset = Vector3(float(w[1]), float(w[2]), float(w[3]))
			"CHANNELS":
				joints[cur].chans = w.slice(2)
			"MOTION":
				motion = true


## Positions et rotations monde de chaque articulation à l'instant t (interpolation entre images).
func _fk(t: float) -> Dictionary:
	var fi := clampf(t / ftime, 0, frames.size() - 1.001)
	var f0 := int(fi)
	var u := fi - f0
	var r0: PackedFloat32Array = frames[f0]
	var r1: PackedFloat32Array = frames[min(f0 + 1, frames.size() - 1)]
	var out := {}
	var glob := []
	var k := 0
	for j in joints.size():
		var jt: Dictionary = joints[j]
		var pos := jt.offset as Vector3
		var b := Basis()
		var q := Quaternion.IDENTITY
		var p0 := Vector3.ZERO
		var p1 := Vector3.ZERO
		var rot0 := Basis()
		var rot1 := Basis()
		for ch in jt.chans:
			var v0 := r0[k]
			var v1 := r1[k]
			k += 1
			match ch:
				"Xposition": p0.x = v0; p1.x = v1
				"Yposition": p0.y = v0; p1.y = v1
				"Zposition": p0.z = v0; p1.z = v1
				"Xrotation": rot0 = rot0 * Basis(Vector3.RIGHT, deg_to_rad(v0)); rot1 = rot1 * Basis(Vector3.RIGHT, deg_to_rad(v1))
				"Yrotation": rot0 = rot0 * Basis(Vector3.UP, deg_to_rad(v0)); rot1 = rot1 * Basis(Vector3.UP, deg_to_rad(v1))
				"Zrotation": rot0 = rot0 * Basis(Vector3.BACK, deg_to_rad(v0)); rot1 = rot1 * Basis(Vector3.BACK, deg_to_rad(v1))
		q = rot0.get_rotation_quaternion().slerp(rot1.get_rotation_quaternion(), u)
		if jt.chans.has("Xposition"):
			pos = pos + p0.lerp(p1, u)
		var lt := Transform3D(Basis(q), pos)
		var g := lt if jt.parent < 0 else (glob[jt.parent] as Transform3D) * lt
		glob.append(g)
		out[jt.name] = g
	return out


func _fist(a: Animation, sk: Skeleton3D) -> Dictionary:
	var d := {}
	for i in a.get_track_count():
		var bone := str(a.track_get_path(i).get_concatenated_subnames())
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		for key in ["index", "middle", "pinky", "ring", "thumb", "hand_"]:
			if bone.begins_with(key):
				d[bone] = a.rotation_track_interpolate(i, 0.0)
	return d


func _bake(c: Dictionary, sk: Skeleton3D, fist: Dictionary) -> Animation:
	# repère : coup vers +Z, départ recentré
	var g0 := _fk(c.t0)
	var gh := _fk(c.hit)
	var fwd: Vector3
	if c.tip != "":
		fwd = gh[c.tip].origin - gh["Hips"].origin
	else:
		fwd = gh["Hips"].basis.z
	fwd.y = 0
	var face := Basis(Vector3.UP, atan2(fwd.x, fwd.z)).inverse()
	var start: Vector3 = g0["Hips"].origin
	var g1 := _fk(c.t1)
	var drift: Vector3 = face * ((g1["Hips"] as Transform3D).origin - start)
	drift.y = 0
	# échelle : hauteur du bassin debout (pose T) -> cible
	var tpose_hip := 0.0
	for j in joints:
		pass
	var leg := 0.0
	var jx := _find("LeftUpLeg")
	while jx >= 0 and joints[jx].name != "LeftToeBase_end":
		leg += -joints[jx].offset.y
		var nxt := -1
		for j in joints.size():
			if joints[j].parent == jx:
				nxt = j
				break
		jx = nxt
	var pel := sk.find_bone("pelvis")
	var scale := sk.get_bone_global_rest(pel).origin.y / maxf(leg, 0.01)
	var order := []
	for b in sk.get_bone_count():
		order.append(b)   # les os d'un glTF sont rangés parents d'abord
	var a := Animation.new()
	var tracks := {}
	for bn in FULL.keys() + AIM.keys():
		var ti := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath("Armature/Skeleton3D:" + bn))
		tracks[bn] = ti
	for bn in fist:
		var ti := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath("Armature/Skeleton3D:" + bn))
		a.rotation_track_insert_key(ti, 0.0, fist[bn])
	var pti := a.add_track(Animation.TYPE_POSITION_3D)
	a.track_set_path(pti, NodePath("Armature/Skeleton3D:pelvis"))
	var dur: float = (c.t1 - c.t0) / c.speed
	var n := int(ceil(dur * FPS)) + 1
	var prevq := {}
	for f in n:
		var tg: float = minf(f / FPS, dur)
		var src := _fk(c.t0 + tg * c.speed)
		var G := {}   # os -> Basis globale (repère squelette)
		for b in order:
			var bn := sk.get_bone_name(b)
			var par := sk.get_bone_parent(b)
			var pg: Basis = G[par] if par >= 0 else Basis()
			var rl := sk.get_bone_rest(b).basis
			var g := pg * rl
			if FULL.has(bn):
				var w: Basis = face * (src[FULL[bn]] as Transform3D).basis
				g = w * sk.get_bone_global_rest(b).basis
			elif AIM.has(bn):
				var pair: Array = AIM[bn]
				var s: Vector3 = face * ((src[pair[1]] as Transform3D).origin - (src[pair[0]] as Transform3D).origin)
				var child := -1
				for cb in sk.get_bone_children(b):
					child = cb
					break
				if child >= 0 and s.length() > 0.0001:
					var dl := sk.get_bone_rest(child).origin.normalized()
					var d := (g * dl).normalized()
					g = Basis(Quaternion(d, s.normalized())) * g
			G[b] = g.orthonormalized()
			if tracks.has(bn):
				var lq: Quaternion = (pg.inverse() * (G[b] as Basis)).get_rotation_quaternion().normalized()
				if prevq.has(bn) and (prevq[bn] as Quaternion).dot(lq) < 0:
					lq = -lq
				prevq[bn] = lq
				a.rotation_track_insert_key(tracks[bn], tg, lq)
		# bassin : position (repère de l'os root)
		var hp: Vector3 = (face * ((src["Hips"] as Transform3D).origin - Vector3(start.x, 0, start.z)) - drift * (tg / dur)) * scale
		var root := sk.find_bone("root")
		var rootg := sk.get_bone_global_rest(root)
		a.position_track_insert_key(pti, tg, rootg.affine_inverse() * hp)
	a.length = dur
	a.loop_mode = Animation.LOOP_LINEAR if c.get("loop", false) else Animation.LOOP_NONE
	return a


func _find(n: String) -> int:
	for j in joints.size():
		if joints[j].name == n:
			return j
	return -1

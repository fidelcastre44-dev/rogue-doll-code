extends SceneTree
## Construit les bibliothèques d'animations du proto à partir des packs Quaternius UAL1 / UAL2 (CC0) et des captures CMU.
## Chaque animation est « reprise » (retarget) sur chaque squelette cible : même rig (type mannequin UE), donc on transpose
## simplement l'écart à la pose de repos, os par os : cible = repos_cible × (repos_source⁻¹ × pose_source).
## Bassin : décalage à son repos, mis à l'échelle de la taille du perso. L'os « root » est ignoré (le jeu déplace le perso).
## Lancer : godot --headless --path . -s tools/build_anims.gd

const SOURCES := {
	"ual1": {"path": "res://assets/anims/UAL1_UE.fbx", "prefix": "Rig|", "unit": 100.0},
	"ual2": {"path": "res://assets/anims/UAL2.glb", "prefix": "", "unit": 1.0},
}

# nom dans le jeu -> [source, animation, boucle]
const WANTED := {
	"idle": ["ual1", "Idle", true],
	"walk": ["ual1", "Walk", true],
	"jog": ["ual1", "Jog_Fwd", true],
	"sprint": ["ual1", "Sprint", true],
	"jump_start": ["ual1", "Jump_Start", false],
	"jump_loop": ["ual1", "Jump", true],
	"jump_land": ["ual1", "Jump_Land", false],
	"roll": ["ual1", "Roll", false],
	"jab": ["ual1", "Punch_Jab", false],
	"cross": ["ual1", "Punch_Cross", false],
	"hit_chest": ["ual1", "Hit_Chest", false],
	"hit_head": ["ual1", "Hit_Head", false],
	"death": ["ual1", "Death01", false],
	"crouch_idle": ["ual1", "Crouch_Idle", true],
	"hook": ["ual2", "Melee_Hook", false],
	"hook_rec": ["ual2", "Melee_Hook_Rec", false],
	"knockback": ["ual2", "Hit_Knockback", false],
	"getup": ["ual2", "LayToIdle", false],
	"ninja_start": ["ual2", "NinjaJump_Start", false],
	"ninja_loop": ["ual2", "NinjaJump_Idle", true],
	"ninja_land": ["ual2", "NinjaJump_Land", false],
	"slide_start": ["ual2", "Slide_Start", false],
	"slide_loop": ["ual2", "Slide", true],
	"slide_exit": ["ual2", "Slide_Exit", false],
	"sword_a": ["ual2", "Sword_Regular_A", false],
	"sword_b": ["ual2", "Sword_Regular_B", false],
	"sword_c": ["ual2", "Sword_Regular_C", false],
	"block": ["ual2", "Sword_Block", false],
	# v0.112 : armes, chope, escalade
	"sword_a_rec": ["ual2", "Sword_Regular_A_Rec", false],
	"sword_b_rec": ["ual2", "Sword_Regular_B_Rec", false],
	"sword_combo": ["ual2", "Sword_Regular_Combo", false],
	"sword_dash": ["ual2", "Sword_Dash_RM", false],
	"sword_attack": ["ual1", "Sword_Attack", false],
	"sword_idle": ["ual1", "Sword_Idle", true],
	"chop": ["ual2", "TreeChopping", false],
	"carry": ["ual2", "Walk_Carry", true],
	"pickup": ["ual1", "PickUp_Table", false],
	"push": ["ual1", "Push", false],
	"shield_break": ["ual2", "Idle_Shield_Break", false],
	"dash": ["ual2", "Shield_Dash_RM", false],
	"throw": ["ual2", "OverhandThrow", false],
	"climb_up": ["ual2", "ClimbUp_1m_RM", false],
	"no": ["ual2", "Idle_No", true],
	"tpose": ["ual2", "A_TPose", false],
}

const TARGETS := {
	"male": "res://assets/hero/male/Superhero_Male_FullBody.gltf",
	"female": "res://assets/hero/female/Superhero_Female_FullBody.gltf",
	"dummy": "res://assets/anims/Mannequin_F.glb",
}

const CMU_JSON := "res://assets/anims/cmu_clips.json"   # écrit par tools/cmu_retarget.py (facultatif)


func _init() -> void:
	var src_nodes := {}
	for k in SOURCES:
		src_nodes[k] = load(SOURCES[k].path).instantiate()
	var cmu := {}
	if FileAccess.file_exists(CMU_JSON):
		cmu = JSON.parse_string(FileAccess.get_file_as_string(CMU_JSON))
	for t in TARGETS:
		var tgt: Node3D = load(TARGETS[t]).instantiate()
		var tsk: Skeleton3D = tgt.find_child("Skeleton3D", true, false)
		var lib := AnimationLibrary.new()
		for name in WANTED:
			var w: Array = WANTED[name]
			var sroot: Node = src_nodes[w[0]]
			var ssk: Skeleton3D = sroot.find_child("Skeleton3D", true, false)
			var ap: AnimationPlayer = sroot.find_child("AnimationPlayer", true, false)
			var an: String = SOURCES[w[0]].prefix + w[1]
			if not ap.has_animation(an):
				push_error("manque " + an)
				continue
			var a := _retarget(ap.get_animation(an), sroot.get_path_to(ssk), ssk, tsk, SOURCES[w[0]].unit)
			a.loop_mode = Animation.LOOP_LINEAR if w[2] else Animation.LOOP_NONE
			lib.add_animation(name, a)
		for name in cmu:
			lib.add_animation(name, _from_cmu(cmu[name], tsk))
		var out := "res://assets/anims/lib_%s.res" % t
		var err := ResourceSaver.save(lib, out)
		print(out, " : ", lib.get_animation_list().size(), " animations, err=", err)
		tgt.free()
	for k in src_nodes:
		src_nodes[k].free()
	quit()


func _retarget(src: Animation, skpath: NodePath, ssk: Skeleton3D, tsk: Skeleton3D, unit: float) -> Animation:
	var a := Animation.new()
	a.length = src.length
	var pel_s := ssk.get_bone_global_rest(ssk.find_bone("pelvis")).origin.length() / unit
	var pel_t := tsk.get_bone_global_rest(tsk.find_bone("pelvis")).origin.length()
	var hscale: float = pel_t / maxf(pel_s, 0.001)
	for i in src.get_track_count():
		var path := src.track_get_path(i)
		if NodePath(str(path.get_concatenated_names())) != skpath:
			continue
		var bone := str(path.get_concatenated_subnames())
		if bone == "root":
			continue
		var sb := ssk.find_bone(bone)
		var tb := tsk.find_bone(bone)
		if sb < 0 or tb < 0:
			continue
		var srest := ssk.get_bone_rest(sb)
		var trest := tsk.get_bone_rest(tb)
		var ty := src.track_get_type(i)
		var dst_path := NodePath("Armature/Skeleton3D:" + bone)
		if ty == Animation.TYPE_ROTATION_3D:
			var sq := srest.basis.get_rotation_quaternion()
			var tq := trest.basis.get_rotation_quaternion()
			var ti := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(ti, dst_path)
			a.track_set_interpolation_type(ti, src.track_get_interpolation_type(i))
			var prev := Quaternion.IDENTITY
			for k in src.track_get_key_count(i):
				var q: Quaternion = src.track_get_key_value(i, k)
				var r := (tq * (sq.inverse() * q)).normalized()
				if k > 0 and prev.dot(r) < 0.0:
					r = -r
				prev = r
				a.rotation_track_insert_key(ti, src.track_get_key_time(i, k), r)
		elif ty == Animation.TYPE_POSITION_3D and bone == "pelvis":
			var ti := a.add_track(Animation.TYPE_POSITION_3D)
			a.track_set_path(ti, dst_path)
			for k in src.track_get_key_count(i):
				var p: Vector3 = src.track_get_key_value(i, k)
				var off: Vector3 = (p - srest.origin) / unit * hscale
				a.position_track_insert_key(ti, src.track_get_key_time(i, k), trest.origin + off)
	return a


## Capture CMU déjà reprise en Python : {fps, loop, bones: {os: [[x,y,z,w], ...]}, pelvis: [[x,y,z], ...]}
## Les rotations sont des écarts au repos (repère local de l'os, mannequin UE) : cible = repos × écart.
func _from_cmu(d: Dictionary, tsk: Skeleton3D) -> Animation:
	var a := Animation.new()
	var fps: float = d.fps
	var n := 0
	for bone in d.bones:
		var tb := tsk.find_bone(bone)
		if tb < 0:
			continue
		var tq := tsk.get_bone_rest(tb).basis.get_rotation_quaternion()
		var ti := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(ti, NodePath("Armature/Skeleton3D:" + bone))
		var prev := Quaternion.IDENTITY
		var frames: Array = d.bones[bone]
		n = frames.size()
		for f in frames.size():
			var v: Array = frames[f]
			var r := (tq * Quaternion(v[0], v[1], v[2], v[3])).normalized()
			if f > 0 and prev.dot(r) < 0.0:
				r = -r
			prev = r
			a.rotation_track_insert_key(ti, f / fps, r)
	if d.has("pelvis"):
		var tb := tsk.find_bone("pelvis")
		var trest := tsk.get_bone_rest(tb)
		var pel_t := tsk.get_bone_global_rest(tb).origin.length()
		var ti := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(ti, NodePath("Armature/Skeleton3D:pelvis"))
		var frames: Array = d.pelvis
		for f in frames.size():
			var v: Array = frames[f]
			a.position_track_insert_key(ti, f / fps, trest.origin + Vector3(v[0], v[1], v[2]) * pel_t)
	a.length = maxf(n - 1, 1) / fps
	a.loop_mode = Animation.LOOP_LINEAR if d.get("loop", false) else Animation.LOOP_NONE
	return a

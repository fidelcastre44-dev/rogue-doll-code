extends SceneTree
func _init():
	var h = load("res://assets/hero/male/Superhero_Male_FullBody.gltf").instantiate()
	_tree(h, "")
	var u = load("res://assets/anims/UAL1.glb").instantiate()
	_tree(u, "")
	var ap: AnimationPlayer = u.find_child("AnimationPlayer", true, false)
	var a := ap.get_animation("Punch_Jab")
	print("len ", a.length, " tracks ", a.get_track_count())
	for i in min(8, a.get_track_count()):
		print(a.track_get_path(i), " type ", a.track_get_type(i))
	var sh: Skeleton3D = h.find_child("Skeleton3D", true, false)
	var su: Skeleton3D = u.find_child("Skeleton3D", true, false)
	for b in ["root","pelvis","spine_01","thigh_l","calf_l","upperarm_l","hand_l","Head"]:
		var i1 = sh.find_bone(b); var i2 = su.find_bone(b)
		print(b, " hero ", sh.get_bone_rest(i1).origin, " ", sh.get_bone_rest(i1).basis.get_rotation_quaternion(), " | ual ", su.get_bone_rest(i2).origin, " ", su.get_bone_rest(i2).basis.get_rotation_quaternion())
	quit()
func _tree(n, ind):
	if ind.length() > 8: return
	print(ind, n.name, " <", n.get_class(), ">")
	for c in n.get_children(): _tree(c, ind + "  ")

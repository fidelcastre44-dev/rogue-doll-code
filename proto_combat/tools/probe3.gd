extends SceneTree
func _init():
	for p in ["res://assets/anims/UAL2.glb", "res://assets/anims/Mannequin_F.glb", "res://assets/hero/male/Superhero_Male_FullBody.gltf", "res://assets/anims/UAL1_UE.fbx"]:
		var u = load(p).instantiate()
		var su: Skeleton3D = u.find_child("Skeleton3D", true, false)
		print(p, " path=", u.get_path_to(su), " skel_xform=", su.transform, " parent_xform=", su.get_parent().transform)
		for b in ["root","pelvis","thigh_l","upperarm_l"]:
			var i2 = su.find_bone(b)
			print("  ", b, " ", su.get_bone_rest(i2).origin, " ", su.get_bone_rest(i2).basis.get_rotation_quaternion(), " global ", su.get_bone_global_rest(i2).origin)
		var ap = u.find_child("AnimationPlayer", true, false)
		if ap:
			var a: Animation = ap.get_animation(ap.get_animation_list()[3])
			print("  anim ", ap.get_animation_list()[3], " ", a.track_get_path(0), " ", a.track_get_path(1))
	quit()

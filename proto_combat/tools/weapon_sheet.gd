extends SceneTree
## Planche : le héros joue une animation avec une arme en main (6 instants), vue 3/4 de dessus.
## WEAPON=sword ANIM=sword_a [CMU=1] OUT=/chemin.png xvfb-run godot --path . --rendering-driver opengl3 -s tools/weapon_sheet.gd
func _init():
	_run.call_deferred()
func _run():
	var wid := OS.get_environment("WEAPON")
	var anim := OS.get_environment("ANIM")
	var cols := 6
	var vp := SubViewport.new(); vp.size = Vector2i(cols * 300, 420); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.own_world_3d = true; root.add_child(vp)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.82,0.84,0.88); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.7,0.7,0.75); vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); vp.add_child(sun)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 3.4; vp.add_child(cam)
	var w := cols * 2.6
	cam.position = Vector3(w * 0.5 - 1.3, 7, 7)
	cam.look_at(Vector3(w * 0.5 - 1.3, 0.6, 0))
	var lib: AnimationLibrary = load("res://assets/anims/lib_male.res")
	var cmu: AnimationLibrary = load("res://assets/anims/lib_cmu_male.res")
	var a: Animation = cmu.get_animation(anim.trim_prefix("cmu/")) if anim.begins_with("cmu/") else lib.get_animation(anim)
	for c in cols:
		var m: Node3D = load("res://assets/hero/male/Superhero_Male_FullBody.gltf").instantiate()
		vp.add_child(m)
		m.position = Vector3(c * 2.6, 0, 0)
		m.rotation.y = PI   # regarde vers -Z (loin de la caméra) : on voit le dos et la lame devant
		var ap := AnimationPlayer.new(); m.add_child(ap); ap.root_node = NodePath(".."); ap.add_animation_library("", lib); ap.add_animation_library("cmu", cmu)
		ap.play(anim); ap.seek(a.length * c / float(cols - 1) * 0.999, true); ap.pause()
		var sk: Skeleton3D = m.find_child("Skeleton3D", true, false)
		if wid != "":
			var wn := Weapons.make_model(wid)
			var ba := BoneAttachment3D.new(); ba.bone_name = "hand_r"; sk.add_child(ba)
			ba.add_child(wn)
		var lab := Label3D.new(); lab.text = "%.2f" % (a.length * c / float(cols - 1)); lab.position = Vector3(c * 2.6, 2.3, 0); lab.font_size = 48; lab.modulate = Color.BLACK; vp.add_child(lab)
		var mk := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.05, 0.02, 1.2); mk.mesh = bm; vp.add_child(mk); mk.position = Vector3(c * 2.6, 0.01, -0.6)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OS.get_environment("OUT"))
	print("ok")
	quit()

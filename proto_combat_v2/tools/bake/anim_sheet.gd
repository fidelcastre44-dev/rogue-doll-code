extends SceneTree
## Planche de contrôle : pour chaque animation, COLS instants côte à côte (vue de profil, le perso regarde vers +X ; FRONT=1 = de face).
## ANIMS="jab,cross" MODEL=male OUT=/chemin.png LIB=mx  xvfb-run godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility -s tools/anim_sheet.gd

const MODELS := {
	"male": "res://assets/hero/male/Superhero_Male_FullBody.gltf",
	"female": "res://assets/hero/female/Superhero_Female_FullBody.gltf",
	"dummy": "res://assets/anims/Mannequin_F.glb",
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var names := OS.get_environment("ANIMS").split(",", false)
	var model := OS.get_environment("MODEL") if OS.get_environment("MODEL") != "" else "male"
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/sheet.png"
	var cols := int(OS.get_environment("COLS")) if OS.get_environment("COLS") != "" else 6
	var libn := OS.get_environment("LIB") if OS.get_environment("LIB") != "" else "mx"
	var front := OS.get_environment("FRONT") != ""
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * 200, names.size() * 240)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.86, 0.87, 0.9)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = names.size() * 2.4
	vp.add_child(cam)
	var w := cols * 2.0
	cam.position = Vector3(w * 0.5 - 1.0, -names.size() * 1.2 + 1.5, 10)
	var lib: AnimationLibrary = load("res://assets/anims/lib_%s_%s.res" % [libn, model] if libn != "" else "res://assets/anims/lib_%s.res" % model)
	for r in names.size():
		if not lib.has_animation(names[r]):
			print("absente ", names[r]); continue
		var a: Animation = lib.get_animation(names[r])
		for c in cols:
			var m: Node3D = load(MODELS[model]).instantiate()
			vp.add_child(m)
			m.position = Vector3(c * 2.0, -r * 2.4 - 0.2, 0)
			m.rotation.y = deg_to_rad(0 if front else 90)
			var ap := AnimationPlayer.new()
			m.add_child(ap)
			ap.root_node = NodePath("..")
			ap.add_animation_library("", lib)
			ap.play(names[r])
			ap.seek(a.length * c / float(cols - 1) * 0.999, true)
			ap.pause()
			var lab := Label3D.new()
			lab.text = "%.2f" % (a.length * c / float(cols - 1))
			lab.position = Vector3(c * 2.0, -r * 2.4 - 0.45, 0.6)
			lab.font_size = 36
			lab.modulate = Color(0.2, 0.2, 0.25)
			vp.add_child(lab)
		var lab := Label3D.new()
		lab.text = "%s (%.2f s)" % [names[r], a.length]
		lab.position = Vector3(-0.9, -r * 2.4 + 1.85, 0.5)
		lab.font_size = 44
		lab.modulate = Color.BLACK
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		vp.add_child(lab)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("ok ", out)
	quit()

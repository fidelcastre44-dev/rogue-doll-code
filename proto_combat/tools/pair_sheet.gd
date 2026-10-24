extends SceneTree
## Planche d'une animation à deux (v0.114) : attaquant (héros) et victime (mannequin) joués depuis la même origine, vus de dessus
## et de côté, à COLS instants entre T0 et T1.
## PAIR="grab__hell_slammer_a,grab__hell_slammer_b" T0=0 T1=7.5 COLS=8 OUT=/x.png xvfb-run godot --path . --rendering-driver opengl3 -s tools/pair_sheet.gd

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var pair := OS.get_environment("PAIR").split(",")
	var cols := int(OS.get_environment("COLS")) if OS.get_environment("COLS") != "" else 8
	var t0 := float(OS.get_environment("T0")) if OS.get_environment("T0") != "" else 0.0
	var t1 := float(OS.get_environment("T1")) if OS.get_environment("T1") != "" else -1.0
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/pair.png"
	var cell := 3.6
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * 260, 2 * 260)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.84, 0.88)
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	vp.add_child(sun)
	var hero_lib: AnimationLibrary = load("res://assets/anims/lib_mx_male.res")
	var dum_lib: AnimationLibrary = load("res://assets/anims/lib_mx_dummy.res")
	var a0: Animation = hero_lib.get_animation(pair[0])
	if t1 < 0:
		t1 = a0.length
	# deux rangées (vue de face, vue de dessus) : chaque instant est posé à part dans le monde
	for row in 2:
		for c in cols:
			var t := lerpf(t0, t1, c / float(maxi(cols - 1, 1)))
			var base := Vector3(c * 20.0, row * 50.0, 0)
			for k in pair.size():
				var path := "res://assets/hero/male/Superhero_Male_FullBody.gltf" if k == 0 else "res://assets/anims/Mannequin_F.glb"
				var m: Node3D = load(path).instantiate()
				vp.add_child(m)
				m.position = base
				var ap := AnimationPlayer.new()
				m.add_child(ap)
				ap.root_node = NodePath("..")
				ap.add_animation_library("", hero_lib if k == 0 else dum_lib)
				ap.play(pair[k])
				ap.seek(minf(t, ap.current_animation_length - 0.001), true)
				ap.pause()
			var lab := Label3D.new()
			lab.text = "%.2f s" % t
			lab.font_size = 64
			lab.modulate = Color.BLACK
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.position = base + Vector3(0, 2.6, 0)
			vp.add_child(lab)
	# rendu : une petite caméra par case, collée dans une image finale
	var img := Image.create(cols * 260, 2 * 260, false, Image.FORMAT_RGBA8)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cell
	vp.add_child(cam)
	vp.size = Vector2i(260, 260)
	for row in 2:
		for c in cols:
			var base := Vector3(c * 20.0, row * 50.0, 0)
			if row == 0:
				cam.position = base + Vector3(0, 1.0, 8)       # de face (regarde -Z)
				cam.rotation = Vector3.ZERO
			else:
				cam.position = base + Vector3(0, 8, 0)          # de dessus
				cam.rotation = Vector3(-PI / 2, 0, 0)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			img.blit_rect(_rgba(vp.get_texture().get_image()), Rect2i(0, 0, 260, 260), Vector2i(c * 260, row * 260))
	img.save_png(out)
	print("ok ", out)
	quit()


func _rgba(i: Image) -> Image:
	i.convert(Image.FORMAT_RGBA8)
	return i

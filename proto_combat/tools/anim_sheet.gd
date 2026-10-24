extends SceneTree
## Planche de contrôle : pour chaque animation demandée, 5 instants côte à côte (vue de côté), sur le modèle choisi.
## ANIMS="jab,cross" MODEL=male OUT=/chemin.png  xvfb-run godot --path . --rendering-driver opengl3 -s tools/anim_sheet.gd

const MODELS := {
	"male": ["res://assets/hero/male/Superhero_Male_FullBody.gltf", "res://assets/anims/lib_male.res"],
	"female": ["res://assets/hero/female/Superhero_Female_FullBody.gltf", "res://assets/anims/lib_female.res"],
	"dummy": ["res://assets/anims/Mannequin_F.glb", "res://assets/anims/lib_dummy.res"],
}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var names := OS.get_environment("ANIMS").split(",")
	var model := OS.get_environment("MODEL") if OS.get_environment("MODEL") != "" else "male"
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "/tmp/sheet.png"
	var cols := 5
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * 220, names.size() * 260)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.82, 0.84, 0.88)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = names.size() * 2.6
	vp.add_child(cam)
	var w := cols * 2.2
	cam.position = Vector3(w * 0.5 - 1.1, -names.size() * 1.3 + 1.3 + 0.0, 10)
	var lib: AnimationLibrary = load(MODELS[model][1])
	if OS.get_environment("CMULIB") != "":
		lib = load(MODELS[model][1].replace("lib_", "lib_cmu_"))
	var players := []
	for r in names.size():
		var a: Animation = lib.get_animation(names[r])
		for c in cols:
			var m: Node3D = load(MODELS[model][0]).instantiate()
			vp.add_child(m)
			m.position = Vector3(c * 2.2, -r * 2.6 - 0.2, 0)
			m.rotation.y = deg_to_rad(90)   # profil : il regarde vers +X
			var ap := AnimationPlayer.new()
			m.add_child(ap)
			ap.root_node = NodePath("..")
			ap.add_animation_library("", lib)
			ap.play(names[r])
			ap.seek(a.length * c / float(cols - 1) * 0.999, true)
			ap.pause()
			players.append(ap)
		var lab := Label3D.new()
		lab.text = names[r]
		lab.position = Vector3(-1.0, -r * 2.6 + 1.9, 0.5)
		lab.font_size = 48
		lab.modulate = Color.BLACK
		vp.add_child(lab)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("ok ", out)
	quit()

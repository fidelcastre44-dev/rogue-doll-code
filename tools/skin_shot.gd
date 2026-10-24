extends SceneTree
## Outil de rendu (pas un test) : SHOT_OUT=dossier ; garde de face et de profil, homme puis femme, dans le salon.
var lab; var f := 0; var p; var out := OS.get_environment("SHOT_OUT"); var cam: Camera3D
func _initialize():
	HeroSkin.look = "male"
	lab = load("res://hub.tscn").instantiate(); root.add_child(lab)
func _shot(n):
	for side in [0, 1]:
		cam.global_position = p.global_position + (Vector3(0, 1.1, -3.0) if side == 0 else Vector3(3.0, 1.1, -0.6)).rotated(Vector3.UP, p.rotation.y)
		cam.look_at(p.global_position + Vector3(0, 0.95, 0))
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("%s/%s_%d.png" % [out, n, side])
func _process(_d):
	f += 1
	if p == null:
		p = lab.find_children("*", "CharacterBody3D", true, false).filter(func(x): return x.has_method("apply_pose"))[0]
		cam = Camera3D.new(); root.add_child(cam); cam.current = true; cam.fov = 40
	if f == 40: _shot("male")
	if f == 60: HeroSkin.look = "female"; p._refresh_look()
	if f == 90: _shot("female")
	if f > 120: quit()
	return false

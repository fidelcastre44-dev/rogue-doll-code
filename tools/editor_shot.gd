extends SceneTree
## Outil : capture de l'éditeur d'animation (SHOT_OUT=fichier.png, ED_MOVE=id, ED_T=temps)
var ed
var f := 0
func _initialize():
	ed = load("res://anim_editor.tscn").instantiate()
	root.add_child(ed)
func _process(_d):
	f += 1
	if f == 5:
		var mv := OS.get_environment("ED_MOVE")
		if mv != "":
			ed.load_move(mv)
		ed.t = float(OS.get_environment("ED_T"))
		ed.select_joint("sh_r")
		if OS.get_environment("ED_3D") == "1":
			ed.toggle_view()
	if f == 12:
		root.get_texture().get_image().save_png(OS.get_environment("SHOT_OUT"))
		quit()
	return false

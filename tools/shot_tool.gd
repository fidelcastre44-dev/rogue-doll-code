extends SceneTree
## Outil de rendu (pas un test) : SHOT_ID=mseedNN SHOT_SEQ='[[k,"action","tap"],...]' SHOT_FRAMES='[..]' SHOT_OUT=dir
var lab
var f := 0
var k := -1
var seq := []
var frames := []
var out := ""
var p
var cam: Camera3D
var svp: SubViewport
var anchor = null

func _initialize():
	lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
	seq = JSON.parse_string(OS.get_environment("SHOT_SEQ"))
	frames = JSON.parse_string(OS.get_environment("SHOT_FRAMES"))
	out = OS.get_environment("SHOT_OUT")

func _process(_d):
	f += 1
	p = lab.player
	if f == 10:
		var id := OS.get_environment("SHOT_ID")
		for i in LaboCatalog.MOVES.size():
			if LaboCatalog.MOVES[i].id == id:
				lab.select(i)
		lab.set_menu(false)
		lab.mini.visible = false
		var v := OS.get_environment("SHOT_VAR")
		if v != "":
			var kv = JSON.parse_string(v)
			for key in kv: p.set(key, kv[key])
		k = 0
		return false
	if k < 0:
		return false
	k += 1
	if cam == null:
		svp = SubViewport.new()
		svp.size = Vector2i(960, 540)
		svp.world_3d = root.world_3d
		svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(svp)
		cam = Camera3D.new()
		cam.fov = 50
		svp.add_child(cam)
		cam.current = true
	var mode := OS.get_environment("SHOT_CAM")
	var fw := Vector3(1, 0, -1).normalized()
	var rt := fw.cross(Vector3.UP)
	if anchor == null:
		anchor = p.global_position + fw * 1.2
	var foc: Vector3 = anchor.lerp(p.global_position + fw * 0.6, 0.15)
	anchor = foc
	var off := rt * 4.2 + Vector3.UP * 1.0
	if mode == "front":
		off = -fw * 4.2 + rt * 1.2 + Vector3.UP * 1.3
	elif mode == "top":
		off = Vector3.UP * 5.0 - rt * 0.8 - fw * 0.3
	elif mode == "chase":
		off = -fw * 3.5 - rt * 0.6 + Vector3.UP * 1.6
	elif mode == "back":
		off = -rt * 4.2 + Vector3.UP * 1.0
	cam.global_position = foc + off
	cam.look_at(foc + Vector3.UP * 0.8)
	for st in seq:
		if int(st[0]) == k:
			match st[2]:
				"press": Input.action_press(st[1])
				"release": Input.action_release(st[1])
				"tap":
					Input.action_press(st[1])
					set_meta("rel_" + st[1], k + 2)
				"sprint": p.sprinting = true
				"over":
					var e = lab.main.enemies[0]
					p.global_position = Vector3(e.parts.pelvis.global_position.x, 0, e.parts.pelvis.global_position.z) + Vector3(0.3, 0, 0)
	for a in ["light", "heavy", "grab", "jump", "roll"]:
		if has_meta("rel_" + a) and get_meta("rel_" + a) == k:
			Input.action_release(a)
			remove_meta("rel_" + a)
	if float(k) in frames or k in frames:
		var img := svp.get_texture().get_image()
		img.save_png("%s/%04d.png" % [out, k])
		var e = lab.main.enemies[0]
		print("frame %d attack=%s t=%.2f pos=%s yaw=%.0f fwd=%s" % [k, p.attack, p.t, p.global_position, p.rotation_degrees.y, -p.global_basis.z])
	if k > frames.max():
		quit()
	return false

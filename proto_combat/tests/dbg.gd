extends SceneTree
var game; var inp; var fr := 0
func _initialize():
	game = load("res://main.tscn").instantiate(); root.add_child(game)
func _physics_process(_d):
	if inp == null:
		inp = root.get_node("Inputs"); inp.use_fake = true
	fr += 1
	if fr == 2: game.foe_count = 1; game.load_spot("centre")
	if fr == 10 or fr == 30: inp.press("heavy")
	if inp.held("heavy") and inp.held_time("heavy") > 0.02: inp.release("heavy")
	var e = game.enemies[0] if game.enemies.size() else null
	if e and fr > 40 and fr % 4 == 0 and fr < 170:
		var sk: Skeleton3D = e.rig.skel
		var b = sk.find_bone("spine_03")
		var g = sk.global_transform * sk.get_bone_global_pose(b)
		var up = g.basis.y.normalized()
		print(fr, " ", e.state, " rag=", e.rag.active, " pin=", e.rag.pinned, " tilt=%d°" % rad_to_deg(up.angle_to(Vector3.UP)), " pel(%.1f,%.1f,%.1f)" % [e.rag.pelvis_pos().x, e.rag.pelvis_pos().y, e.rag.pelvis_pos().z], " cap(%.1f,%.1f,%.1f)" % [e.global_position.x, e.global_position.y, e.global_position.z])
	return fr > 170

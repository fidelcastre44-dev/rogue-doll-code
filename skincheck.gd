extends SceneTree
## v0.22 : habillage 3D du héros (HeroSkin). Le modèle suit les cubes ; F4 change de look ; l'éditeur reste en cubes.
var lab
var f := 0
var p
var ok := true
var err := 0.0


func _initialize():
	HeroSkin.look = "male"
	lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)


func _check(c: bool, msg: String) -> void:
	print(("ok   " if c else "ECHEC ") + msg)
	ok = ok and c


func _bone(n: String) -> Vector3:
	var sk: Skeleton3D = p.skin.sk
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin


func _gap() -> float:
	p.skin._process(0.0)   # le modèle se met à jour juste avant l'affichage, après ce test : on le met à jour ici
	# poings et chevilles du modèle comparés aux cubes
	# (les bras du modèle sont un peu plus courts que ceux des cubes : marge plus grande aux poings)
	var g := 0.0
	for s in ["l", "r"]:
		g = maxf(g, _bone("hand_" + s).distance_to(p.j["fist_" + s].global_position) / 2.5)
		g = maxf(g, _bone("foot_" + s).distance_to(p.j["foot_" + s].global_position))
	return g


func _process(_d):
	f += 1
	if f == 5:
		p = lab.player
		lab.set_menu(false)
		_check(p.skin != null, "le héros a un habillage")
		var cubes_hidden := true
		for n in p.j:
			for c in p.j[n].get_children():
				if c is MeshInstance3D and c.visible:
					cubes_hidden = false
		_check(cubes_hidden, "cubes cachés")
	if f > 40 and f < 120:
		if f == 30:
			Input.action_press("light")
		if f == 32:
			Input.action_release("light")
		if f == 70:
			Input.action_press("heavy")
		if f == 72:
			Input.action_release("heavy")
		err = maxf(err, _gap())
	if f == 120:
		_check(err < 0.1, "le modèle suit poings et chevilles (écart max %.2f m)" % err)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F4
		ev.pressed = true
		p._input(ev)
	if f == 125:
		_check(HeroSkin.look == "female" and p.skin != null, "F4 : femme")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F4
		ev.pressed = true
		p._input(ev)
	if f == 130:
		_check(HeroSkin.look == "cubes" and p.skin == null and p.j.spine.get_child(0).visible, "F4 : cubes")
		HeroSkin.look = "male"
		p._refresh_look()
	if f == 135:
		p._ragdoll_on()
	if f == 160:
		_check(p.skin != null and p.rag.size() > 0, "plongeon pantin avec habillage")
		var pel: Vector3 = _bone("pelvis")
		_check(pel.distance_to(p.rag.hips.global_position) < 0.35, "le modèle suit le ragdoll")
		var ed = load("res://combat/anim_editor.gd").PLAYER.new()
		ed.skin_on = false
		root.add_child(ed)
		_check(ed.skin == null, "éditeur : héros en cubes")
		ed.queue_free()
	if f == 165:
		var c := ConfigFile.new()
		c.set_value("hero", "look", "male")
		c.save(HeroSkin.CFG)
		print("RESULTAT: OK" if ok else "RESULTAT: ECHEC")
		quit()
	return false

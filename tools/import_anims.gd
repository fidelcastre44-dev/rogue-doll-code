extends SceneTree
## Outil (pour Claude, sans écran) : intègre un fichier d'animations exporté par l'éditeur (F3) dans le projet.
## Pour chaque coup qui a une version cochée, elle devient l'animation officielle : ses poses vont dans moves/poses.tres
## (sous les noms <coup>_e1, <coup>_e2, …) et ses clés et durées dans moves/<coup>.tres.
##   ANIMS=/chemin/fichier.json ../godot --headless --path . -s tools/import_anims.gd
## ONLY=jab,kick (facultatif) : seulement ces coups.

func _initialize() -> void:
	MoveLibrary.skip_overrides = true
	var path := OS.get_environment("ANIMS")
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY or d.get("format", "") != AnimStore.FORMAT:
		print("ERREUR : fichier d'animations illisible : ", path)
		quit(1)
		return
	var only := OS.get_environment("ONLY").split(",", false)
	var ps := load("res://moves/poses.tres") as PoseSet
	var done := []
	for id in d.moves:
		if only.size() and not id in only:
			continue
		var vname: String = d.moves[id].get("chosen", "")
		if vname == "":
			continue
		var v := {}
		for x in d.moves[id].versions:
			if x.name == vname:
				v = x
		var mpath := "res://moves/%s.tres" % id
		if v.is_empty() or not ResourceLoader.exists(mpath):
			print("ignoré : ", id)
			continue
		var m := load(mpath) as MoveData
		var keys := []
		var n := 0
		for k in v.keys:
			var pname := "from"
			if typeof(k.pose) == TYPE_DICTIONARY:
				n += 1
				pname = "%s_e%d" % [id, n]
				ps.diffs[pname] = AnimStore.pose_from_json(k.pose)
			var key := [float(k.t), pname]
			if k.get("curve", "") != "":
				key.append(k.curve)
			keys.append(key)
		m.keys = keys
		m.active = float(v.active)
		m.cancel = float(v.cancel)
		m.end = float(v.end)
		m.notes = "%s\nAnimation retouchée dans l'éditeur : version « %s » (%s)." % [m.notes, vname, v.get("saved_at", "")]
		ResourceSaver.save(m, mpath)
		done.append("%s (« %s »)" % [id, vname])
	ResourceSaver.save(ps, "res://moves/poses.tres")
	print("intégrés : ", done.size(), "\n  ", "\n  ".join(done))
	quit()

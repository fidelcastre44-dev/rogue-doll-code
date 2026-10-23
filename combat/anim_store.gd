class_name AnimStore
extends RefCounted
## Animations retouchées dans l'éditeur (F3), enregistrées dans le dossier utilisateur du jeu (user://), donc aussi depuis
## la version Windows exportée (qui ne peut pas modifier les fichiers du projet).
##
## Pour chaque coup : plusieurs versions nommées, et une version « cochée » (chosen) : c'est celle que le jeu utilise.
## Au chargement, les versions cochées passent par-dessus les fiches d'origine (moves/*.tres) : apply() remplace, dans la table
## des coups du héros (MoveLibrary.table()), les clés et les durées. Les poses d'une version sont gardées ici (pose(nom)),
## jamais dans moves/poses.tres. Le fichier exporté (« Tout exporter ») a exactement le même format que user://anims.json.
##
## Format (JSON) :
## {"format": "rogue-doll-anims", "format_version": 1, "game": "0.2", "saved_at": "...",
##  "moves": {"jab": {"chosen": "rapide", "versions": [
##      {"name": "rapide", "saved_at": "...", "active": 0.07, "cancel": 0.11, "end": 0.24,
##       "keys": [{"t": 0.0, "pose": "from", "curve": ""}, {"t": 0.05, "pose": {"hips_pos": [0, -0.06, 0], "hips": [0, -30, 0], ...}, "curve": "in"}]}]}}}
## Une pose = position du bassin (décalage) + rotation de chaque articulation (degrés, Euler YXZ), jambes en angles (pas de pieds plantés).

const FORMAT := "rogue-doll-anims"
const JOINTS := ["hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r", "hip_l", "kn_l", "hip_r", "kn_r"]
## Courbes entre deux clés : [code, nom affiché]. Le code est celui que lit player.pose_at.
const CURVES := [["", "Amortie (départ sec)"], ["lin", "Linéaire"], ["in", "Accélère (ease in)"], ["inout", "Douce (ease in/out)"], ["step", "Tenue puis saut"]]

static var path := "user://anims.json"
static var data := {}              # contenu du fichier
static var _poses := {}            # "@coup@i" -> pose (format du héros : degrés, pieds à null)
static var _orig := {}             # coup -> {keys, active, cancel, end} d'origine (pour revenir à la fiche)
static var _loaded := false


static func load_file() -> void:
	_loaded = true
	data = {"format": FORMAT, "format_version": 1, "moves": {}}
	if not FileAccess.file_exists(path):
		return
	var txt := FileAccess.get_file_as_string(path)
	var d = JSON.parse_string(txt)
	if typeof(d) == TYPE_DICTIONARY and d.get("format", "") == FORMAT:
		data = d
		if not data.has("moves"):
			data.moves = {}


static func ensure() -> void:
	if not _loaded:
		load_file()


static func save_file() -> bool:
	ensure()
	data.format = FORMAT
	data.format_version = 1
	data.game = GameVersion.NUM
	data.saved_at = Time.get_datetime_string_from_system()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Impossible d'écrire " + path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


## Les versions enregistrées d'un coup (liste de dictionnaires).
static func versions(move_id: String) -> Array:
	ensure()
	return data.moves.get(move_id, {}).get("versions", [])


static func chosen(move_id: String) -> String:
	ensure()
	return data.moves.get(move_id, {}).get("chosen", "")


static func find_version(move_id: String, vname: String) -> Dictionary:
	for v in versions(move_id):
		if v.name == vname:
			return v
	return {}


## Ajoute ou remplace (même nom) une version.
static func put_version(move_id: String, v: Dictionary) -> void:
	ensure()
	if not data.moves.has(move_id):
		data.moves[move_id] = {"chosen": "", "versions": []}
	var list: Array = data.moves[move_id].versions
	for i in list.size():
		if list[i].name == v.name:
			list[i] = v
			return
	list.append(v)


static func delete_version(move_id: String, vname: String) -> void:
	ensure()
	if not data.moves.has(move_id):
		return
	var m: Dictionary = data.moves[move_id]
	m.versions = m.versions.filter(func(v): return v.name != vname)
	if m.chosen == vname:
		m.chosen = ""
	if m.versions.is_empty():
		data.moves.erase(move_id)


## Coche une version (vide = la fiche d'origine du jeu).
static func choose(move_id: String, vname: String) -> void:
	ensure()
	if data.moves.has(move_id):
		data.moves[move_id].chosen = vname


static func pose(pose_name: String) -> Dictionary:
	return _poses.get(pose_name, {})


## Pose JSON -> pose du héros (degrés en Vector3, pieds non plantés).
static func pose_from_json(j: Dictionary) -> Dictionary:
	var p := {"foot_l": null, "foot_r": null}
	var hp = j.get("hips_pos", [0, 0, 0])
	p.hips_pos = Vector3(hp[0], hp[1], hp[2])
	for n in JOINTS:
		var a = j.get(n, [0, 0, 0])
		p[n] = Vector3(a[0], a[1], a[2])
	return p


static func pose_to_json(p: Dictionary) -> Dictionary:
	var j := {}
	var hp: Vector3 = p.get("hips_pos", Vector3.ZERO)
	j.hips_pos = [snappedf(hp.x, 0.001), snappedf(hp.y, 0.001), snappedf(hp.z, 0.001)]
	for n in JOINTS:
		var a: Vector3 = p.get(n, Vector3.ZERO)
		j[n] = [snappedf(a.x, 0.1), snappedf(a.y, 0.1), snappedf(a.z, 0.1)]
	return j


## Met les versions cochées par-dessus les fiches d'origine, dans la table que lisent les héros (modifiée sur place :
## un héros déjà en jeu voit tout de suite la nouvelle animation).
static func apply(table: Dictionary) -> void:
	ensure()
	# D'abord, on remet les fiches d'origine de tout ce qui avait été remplacé.
	for id in _orig:
		if table.has(id):
			for k in _orig[id]:
				table[id][k] = _orig[id][k]
	_orig.clear()
	_poses.clear()
	for id in data.moves:
		var vname: String = data.moves[id].get("chosen", "")
		if vname == "" or not table.has(id):
			continue
		var v := find_version(id, vname)
		if v.is_empty():
			continue
		var a: Dictionary = table[id]
		_orig[id] = {"keys": a.keys, "active": a.active, "cancel": a.cancel, "end": a.end}
		var keys := []
		var i := 0
		for k in v.keys:
			var pname := "from"
			if typeof(k.pose) == TYPE_DICTIONARY:
				pname = "@%s@%d" % [id, i]
				_poses[pname] = pose_from_json(k.pose)
			var key := [float(k.t), pname]
			if k.get("curve", "") != "":
				key.append(k.curve)
			keys.append(key)
			i += 1
		a.keys = keys
		a.active = float(v.get("active", a.active))
		a.cancel = float(v.get("cancel", a.cancel))
		a.end = float(v.get("end", a.end))


## Recharge le fichier et réapplique (après un enregistrement dans l'éditeur).
static func refresh() -> void:
	load_file()
	apply(MoveLibrary.table())


## Toutes les animations modifiées, en un seul fichier (pour le déposer sur le site). Renvoie le chemin écrit.
static func export_all(dest_dir := "") -> String:
	ensure()
	var out := data.duplicate(true)
	out.format = FORMAT
	out.format_version = 1
	out.game = GameVersion.NUM
	out.exported_at = Time.get_datetime_string_from_system()
	if dest_dir == "":
		dest_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		if dest_dir == "" or not DirAccess.dir_exists_absolute(dest_dir):
			dest_dir = OS.get_user_data_dir()
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var p := dest_dir.path_join("RogueDoll-animations-%s.json" % stamp)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(out, "  "))
	f.close()
	return p

extends Node3D
## Décor généré au hasard à chaque pièce : murets autour, sol teinté, et des objets posés un peu partout
## (tables, poubelles, caisses, tonneaux, chaises, bancs, piliers).
## Les objets mobiles sont de vrais corps physiques (groupe "reactive", meta "kind") : plus tard, on pourra y fracasser
## les sbires, leur cogner la tête sur une table, les jeter dans une poubelle...

const WALL_H := 1.0          # murets bas : la caméra du dessus voit toujours l'action
const WALL_T := 0.4
const KEEP_CLEAR := 2.6      # aucun objet aussi près du centre (là où démarre le joueur)

var size := Vector2(18, 14)  # largeur (x), profondeur (z) de la pièce
var rng := RandomNumberGenerator.new()
var spots: Array[Vector3] = []   # objets déjà posés (pour ne pas les empiler)


## Nouvelle pièce. keep_free : positions à laisser libres (joueur, sbires).
func generate(seed_value: int = -1, keep_free: Array = []) -> void:
	for c in get_children():
		c.queue_free()
	spots.clear()
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	size = Vector2(rng.randf_range(14.0, 22.0), rng.randf_range(12.0, 18.0))
	var palette := [Color(0.42, 0.40, 0.38), Color(0.36, 0.40, 0.44), Color(0.45, 0.42, 0.34), Color(0.33, 0.36, 0.33), Color(0.40, 0.36, 0.40)]
	var floor_col: Color = palette[rng.randi() % palette.size()]
	_floor(floor_col)
	_walls(floor_col.darkened(0.35))
	for p in keep_free:
		spots.append(p)
	# Quelques piliers fixes, puis les objets mobiles.
	for i in rng.randi_range(0, 3):
		_place("pillar", 1.4)
	var kinds := ["table", "table", "trash", "trash", "trash", "crate", "crate", "barrel", "barrel", "chair", "chair", "bench"]
	for i in rng.randi_range(9, 16):
		_place(kinds[rng.randi() % kinds.size()], 1.3)


func _floor(col: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(size.x, 0.02, size.y)
	mi.mesh = m
	mi.material_override = _mat(col)
	mi.position.y = 0.011
	add_child(mi)
	# Un tapis ou une zone peinte, pour varier.
	if rng.randf() < 0.6:
		var rug := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(rng.randf_range(3.0, 6.0), 0.02, rng.randf_range(2.5, 5.0))
		rug.mesh = rm
		rug.material_override = _mat(Color.from_hsv(rng.randf(), 0.45, 0.45))
		rug.position = Vector3(rng.randf_range(-size.x * 0.25, size.x * 0.25), 0.022, rng.randf_range(-size.y * 0.25, size.y * 0.25))
		rug.rotation.y = rng.randf_range(-0.3, 0.3)
		add_child(rug)


func _walls(col: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	for w in [[Vector3(0, 0, -hz), Vector3(size.x + WALL_T, WALL_H, WALL_T)], [Vector3(0, 0, hz), Vector3(size.x + WALL_T, WALL_H, WALL_T)],
			[Vector3(-hx, 0, 0), Vector3(WALL_T, WALL_H, size.y)], [Vector3(hx, 0, 0), Vector3(WALL_T, WALL_H, size.y)]]:
		var b := StaticBody3D.new()
		b.collision_layer = 1
		b.add_to_group("walls")
		_box(b, w[1], Vector3(0, w[1].y * 0.5, 0), col)
		add_child(b)
		b.position = w[0]


## Pose un objet à un endroit libre de la pièce (quelques essais au hasard).
func _place(kind: String, gap: float) -> void:
	for attempt in 30:
		var p := Vector3(rng.randf_range(-size.x * 0.5 + 1.0, size.x * 0.5 - 1.0), 0, rng.randf_range(-size.y * 0.5 + 1.0, size.y * 0.5 - 1.0))
		if kind in ["trash", "barrel", "crate"] and rng.randf() < 0.5:   # souvent rangés contre un mur
			if rng.randf() < 0.5:
				p.x = signf(p.x) * (size.x * 0.5 - 0.7)
			else:
				p.z = signf(p.z) * (size.y * 0.5 - 0.7)
		if Vector2(p.x, p.z).length() < KEEP_CLEAR:
			continue
		var ok := true
		for s in spots:
			if Vector2(p.x - s.x, p.z - s.z).length() < gap:
				ok = false
				break
		if not ok:
			continue
		spots.append(p)
		var n := _make(kind)
		add_child(n)
		n.position = p
		n.rotation.y = rng.randf_range(0, TAU)
		return


func _make(kind: String) -> Node3D:
	if kind == "pillar":
		var s := StaticBody3D.new()
		s.collision_layer = 1
		_cyl(s, 0.4, 1.4, Vector3(0, 0.7, 0), Color(0.55, 0.53, 0.5))   # bas : ne cache pas la vue du dessus
		return s
	var b := RigidBody3D.new()
	b.collision_layer = 1           # même couche que le décor : joueur et corps des sbires s'y cognent
	b.collision_mask = 1 | 4 | 8    # sol/décor, joueur, sbires en ragdoll
	b.add_to_group("reactive")
	b.set_meta("kind", kind)
	match kind:
		"table":
			var wood := Color(0.55, 0.36, 0.2)
			_box(b, Vector3(1.6, 0.08, 0.9), Vector3(0, 0.76, 0), wood)
			for lx in [-0.7, 0.7]:
				for lz in [-0.35, 0.35]:
					_box(b, Vector3(0.08, 0.72, 0.08), Vector3(lx, 0.36, lz), wood.darkened(0.2))
			b.mass = 25.0
		"trash":
			var c := Color(0.25, 0.42, 0.3) if rng.randf() < 0.5 else Color(0.35, 0.36, 0.38)
			_cyl(b, 0.3, 0.8, Vector3(0, 0.4, 0), c)
			_cyl(b, 0.33, 0.06, Vector3(0, 0.83, 0), c.lightened(0.15))
			b.mass = 8.0
		"crate":
			var s := rng.randf_range(0.6, 0.9)
			_box(b, Vector3(s, s, s), Vector3(0, s * 0.5, 0), Color(0.62, 0.48, 0.28))
			b.mass = 15.0
		"barrel":
			_cyl(b, 0.35, 1.0, Vector3(0, 0.5, 0), Color(0.6, 0.18, 0.12) if rng.randf() < 0.5 else Color(0.2, 0.3, 0.55))
			b.mass = 20.0
		"chair":
			var c2 := Color(0.5, 0.33, 0.2)
			_box(b, Vector3(0.45, 0.06, 0.45), Vector3(0, 0.46, 0), c2)
			_box(b, Vector3(0.45, 0.5, 0.06), Vector3(0, 0.74, -0.2), c2)
			for lx in [-0.18, 0.18]:
				for lz in [-0.18, 0.18]:
					_box(b, Vector3(0.05, 0.44, 0.05), Vector3(lx, 0.22, lz), c2.darkened(0.2))
			b.mass = 5.0
		"bench":
			var c3 := Color(0.45, 0.3, 0.18)
			_box(b, Vector3(1.8, 0.08, 0.4), Vector3(0, 0.45, 0), c3)
			for lx in [-0.75, 0.75]:
				_box(b, Vector3(0.08, 0.42, 0.36), Vector3(lx, 0.21, 0), c3.darkened(0.2))
			b.mass = 18.0
	return b


func _box(parent: Node3D, s: Vector3, at: Vector3, col: Color) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = s
	cs.position = at
	parent.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = s
	mi.position = at
	mi.material_override = _mat(col)
	parent.add_child(mi)


func _cyl(parent: Node3D, r: float, h: float, at: Vector3, col: Color) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = CylinderShape3D.new()
	cs.shape.radius = r
	cs.shape.height = h
	cs.position = at
	parent.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = r
	mi.mesh.bottom_radius = r
	mi.mesh.height = h
	mi.position = at
	mi.material_override = _mat(col)
	parent.add_child(mi)


func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	return m

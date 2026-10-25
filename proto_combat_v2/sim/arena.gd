class_name Arena
## Le terrain d'essai : sol, murs d'enceinte, un mur long pour les coups qui projettent, quelques blocs et piliers.
## `BLOCKS` = liste de boîtes [centre, taille] : la simulation en fait les collisions, l'affichage en fait les meshes.

const SIZE := 44.0
const BLOCKS := [
	# mur long au nord (situation « mur »)
	[Vector3(0, 1.5, -11.0), Vector3(16, 3, 0.6)],
	# piliers
	[Vector3(7, 1.75, 6), Vector3(0.8, 3.5, 0.8)], [Vector3(-7, 1.75, 6), Vector3(0.8, 3.5, 0.8)],
	# blocs de hauteurs différentes (parcours, étape 6)
	[Vector3(12, 0.5, -4), Vector3(2.4, 1.0, 2.4)], [Vector3(12, 1.0, -7), Vector3(2.4, 2.0, 2.4)], [Vector3(12, 1.5, -10), Vector3(2.4, 3.0, 2.4)],
	# muret
	[Vector3(-12, 0.45, -4), Vector3(4.0, 0.9, 0.4)],
	# couloir pour la course au mur (plus tard)
	[Vector3(-14, 2.0, 8), Vector3(0.5, 4.0, 10)], [Vector3(-17.5, 2.0, 8), Vector3(0.5, 4.0, 10)],
]


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "Arena"
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	root.add_child(body)
	# sol
	var floor_shape := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(SIZE, 1.0, SIZE)
	floor_shape.shape = bx
	floor_shape.position.y = -0.5
	body.add_child(floor_shape)
	# enceinte
	for w in [[Vector3(0, 2, -SIZE * 0.5), Vector3(SIZE, 4, 1)], [Vector3(0, 2, SIZE * 0.5), Vector3(SIZE, 4, 1)],
		[Vector3(-SIZE * 0.5, 2, 0), Vector3(1, 4, SIZE)], [Vector3(SIZE * 0.5, 2, 0), Vector3(1, 4, SIZE)]]:
		_box(body, w[0], w[1])
	for b in BLOCKS:
		_box(body, b[0], b[1])
	return root


static func _box(body: StaticBody3D, c: Vector3, s: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = s
	cs.shape = sh
	cs.position = c
	body.add_child(cs)

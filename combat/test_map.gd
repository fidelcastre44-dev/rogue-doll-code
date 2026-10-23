class_name TestMap
extends Node3D
## « Terrain d'essai » (v0.212) : la carte du labo des coups et de la salle des paliers. Tout en blocs simples, comme le héros.
## Le centre (±6 m autour de l'origine) reste plat et vide : c'est là que se jouent les situations sans décor.
## « Devant » = vers le haut du stick = DIAG (la caméra regarde en diagonale) : les éléments à franchir sont tournés face à DIAG.
##
##   Nord-ouest : plateforme haute (2 m) avec un bord dégagé, grand escalier (10 marches) et rampe lisse qui y montent.
##   Nord-est   : blocs en escalier libre (0,4 / 1 / 2 / 3 m ; s'agripper au 3 m) et un bloc de 2 m seul (se hisser).
##   Est        : deux longs murs en L (3,5 m) : courses au mur, mur devant, mur sur le côté, coin (râpe à fromage).
##   Ouest      : muret (0,9 m), rambarde à barreaux (1,1 m), barrière haute à glisser dessous (0,8 m de vide).
##   Sud        : piliers, tables cassables, chaises, caisses, tonneaux.
##
## Collision des marches = une rampe lisse invisible (le héros et les sbires y marchent ; la glissade y descend) ;
## les marches ne sont que visuelles. Les « points » (anchors) donnent où placer héros et sbires pour chaque situation du labo.

const DIAG := Vector3(0.70710678, 0, -0.70710678)   # devant (stick vers le haut)
const SIDE := Vector3(0.70710678, 0, 0.70710678)    # sa droite
const LAYER := 1

var anchors := {}            # nom -> {"at": Vector3, "f": Vector3}
var breakables := []         # tables cassables
var props := []              # objets à ramasser posés par la carte
var mats := {}


func _ready() -> void:
	build()


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	mats[key] = m
	return m


## Un bloc plein (collision + rendu), par son centre et sa rotation (yaw).
func block(size: Vector3, center: Vector3, col: Color, yaw := 0.0, solid := true, visible_mesh := true) -> Node3D:
	var root: Node3D
	if solid:
		var sb := StaticBody3D.new()
		sb.collision_layer = LAYER
		sb.collision_mask = 0
		sb.add_to_group("walls")
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		cs.shape.size = size
		sb.add_child(cs)
		root = sb
	else:
		root = Node3D.new()
	if visible_mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.mesh.size = size
		mi.material_override = _mat(col)
		root.add_child(mi)
	add_child(root)
	root.position = center
	root.rotation.y = yaw
	return root


## Mur (ou muret) entre deux points au sol.
func wall(a: Vector3, b: Vector3, h: float, thick: float, col: Color, base := 0.0) -> Node3D:
	var d := b - a
	d.y = 0
	var yaw := atan2(d.x, d.z)
	return block(Vector3(thick, h, d.length()), (a + b) * 0.5 + Vector3.UP * (base + h * 0.5), col, yaw)


## Rampe pleine montant de `a` (bas, au sol) vers `b` (haut, à la hauteur h), largeur w.
func ramp(a: Vector3, b: Vector3, h: float, w: float, col: Color, visible_mesh := true) -> Node3D:
	var run := Vector2(b.x - a.x, b.z - a.z)
	var len := sqrt(run.length_squared() + h * h)
	var yaw := atan2(b.x - a.x, b.z - a.z)
	var pitch := atan2(h, run.length())
	var thick := 0.5
	var sb := StaticBody3D.new()
	sb.collision_layer = LAYER
	sb.collision_mask = 0
	sb.add_to_group("walls")
	sb.add_to_group("slopes")
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = Vector3(w, thick, len)
	sb.add_child(cs)
	if visible_mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.mesh.size = Vector3(w, thick, len)
		mi.material_override = _mat(col)
		sb.add_child(mi)
	add_child(sb)
	# Plan incliné : le dessus de la boîte passe par a (au sol) et b (à h).
	sb.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	var mid := (a + b) * 0.5 + Vector3.UP * h * 0.5
	sb.position = mid - sb.basis.y * thick * 0.5
	return sb


func _cyl(r: float, h: float, at: Vector3, col: Color) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = LAYER
	sb.collision_mask = 0
	sb.add_to_group("walls")
	var cs := CollisionShape3D.new()
	cs.shape = CylinderShape3D.new()
	cs.shape.radius = r
	cs.shape.height = h
	cs.position.y = h * 0.5
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = CylinderMesh.new()
	mi.mesh.top_radius = r
	mi.mesh.bottom_radius = r
	mi.mesh.height = h
	mi.position.y = h * 0.5
	mi.material_override = _mat(col)
	sb.add_child(mi)
	add_child(sb)
	sb.position = at
	return sb


func _label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.font_size = 40
	l.outline_size = 8
	l.modulate = Color(1, 1, 1, 0.8)
	add_child(l)
	l.position = at


func _anchor(name: String, at: Vector3, f := DIAG) -> void:
	anchors[name] = {"at": at, "f": f.normalized()}


func build() -> void:
	var ground := Color(0.47, 0.47, 0.45)
	var stone := Color(0.58, 0.55, 0.5)
	var dark := Color(0.36, 0.35, 0.38)
	var wallc := Color(0.5, 0.47, 0.55)
	var wood := Color(0.55, 0.36, 0.2)
	var metal := Color(0.32, 0.38, 0.45)

	# Sol (rendu seulement : le sol physique est celui de la scène de jeu) et zone centrale marquée.
	block(Vector3(44, 0.02, 44), Vector3(0, 0.011, 0), ground, 0.0, false)
	block(Vector3(12, 0.02, 12), Vector3(0, 0.022, 0), ground.lightened(0.08), PI / 4, false)

	# Bords : murs hauts au nord et à l'est (fond de l'écran), plinthes basses au sud et à l'ouest (côté caméra).
	wall(Vector3(-22, 0, -22), Vector3(22, 0, -22), 3.5, 0.5, wallc)
	wall(Vector3(22, 0, -22), Vector3(22, 0, 22), 3.5, 0.5, wallc)
	wall(Vector3(-22, 0, 22), Vector3(22, 0, 22), 0.5, 0.5, dark)
	wall(Vector3(-22, 0, -22), Vector3(-22, 0, 22), 0.5, 0.5, dark)

	# --- Nord-ouest : plateforme haute (2 m), escalier, rampe.
	var ph := 2.0
	block(Vector3(18, ph, 8), Vector3(-11, ph * 0.5, -18), stone)              # x -20..-2, z -22..-14
	for k in 6:   # rebord peint sur le bord dégagé
		block(Vector3(0.9, 0.03, 0.25), Vector3(-6.5 + k * 1.0, ph + 0.015, -14.15), Color(0.95, 0.8, 0.2), 0.0, false)
	# Escalier : 10 marches (0,2 m de haut, 0,5 m de profondeur), de z = -9 (bas) à z = -14 (haut), x -12..-7.
	for k in 10:
		var h := (k + 1) * 0.2
		block(Vector3(5, h, 0.5), Vector3(-9.5, h * 0.5, -9.25 - k * 0.5), stone.lightened(0.05 * (k % 2)), 0.0, false)
	ramp(Vector3(-9.5, 0, -9.0), Vector3(-9.5, 0, -14.0), ph, 5.0, stone, false)
	# Rampe lisse : x -19..-15, de z = -7 (sol) à z = -14 (2 m).
	ramp(Vector3(-17, 0, -7.0), Vector3(-17, 0, -14.0), ph, 4.0, Color(0.5, 0.52, 0.56))
	_label("Escalier", Vector3(-9.5, 1.8, -9.5))
	_label("Rampe", Vector3(-17, 1.6, -8))
	_label("Plateforme (2 m)", Vector3(-4.5, 3.1, -16))
	_anchor("stairs_top", Vector3(-9.5, ph, -15.0), Vector3(0, 0, 1))      # en haut, face à la descente
	_anchor("stairs_bottom", Vector3(-9.5, 0, -7.5), Vector3(0, 0, -1))
	_anchor("ramp_top", Vector3(-17, ph, -15.0), Vector3(0, 0, 1))
	_anchor("ramp_bottom", Vector3(-17, 0, -5.5), Vector3(0, 0, -1))
	_anchor("ledge", Vector3(-4.5, ph, -16.0), Vector3(0, 0, 1))            # au bord dégagé, face au vide
	_anchor("ledge_under", Vector3(-4.5, 0, -12.5), Vector3(0, 0, -1))

	# --- Nord-est : blocs en escalier libre, plus un bloc de 2 m seul.
	var hs := [0.4, 1.0, 2.0, 3.0]
	for k in 4:
		block(Vector3(2, hs[k], 4), Vector3(5 + k * 2, hs[k] * 0.5, -18), stone.darkened(0.04 * k))
		_label("%s m" % str(hs[k]).trim_suffix(".0"), Vector3(5 + k * 2, hs[k] + 0.4, -16))
	_anchor("blocks", Vector3(5, 0, -13.5), Vector3(0, 0, -1))
	block(Vector3(2.5, 2.0, 2.5), Vector3(14, 1.0, -12), stone)                 # bloc de 2 m seul
	block(Vector3(2.5, 1.0, 2.5), Vector3(14, 0.5, -16.5), stone.lightened(0.05))   # et un de 1 m derrière
	_label("Bloc 2 m", Vector3(14, 2.5, -12))
	_anchor("block2", Vector3(14, 0, -12) - DIAG * 2.4, DIAG)
	_anchor("step04", Vector3(5, 0, -14.6), Vector3(0, 0, -1))
	_anchor("block3", Vector3(11, 0, -14.6), Vector3(0, 0, -1))                 # devant le bloc de 3 m (s'agripper, v0.216)
	_anchor("block3_top", Vector3(11, 3.0, -17.4), Vector3(0, 0, 1))            # sur le bloc de 3 m, face au vide (grande chute)
	_anchor("block1", Vector3(7, 0, -14.6), Vector3(0, 0, -1))

	# --- Est : deux longs murs en L autour du coin K, tournés face au centre (murs de 3,5 m, 12 m de long).
	var K := Vector3(17, 0, 0)
	wall(K, K - SIDE * 12.0, 3.5, 0.5, wallc)    # mur A : perpendiculaire à DIAG (on le voit « devant » en poussant vers le haut)
	wall(K, K - DIAG * 12.0, 3.5, 0.5, wallc)    # mur B : le long de DIAG (sur la droite en montant)
	_label("Murs", K - SIDE * 5.0 - DIAG * 0.6 + Vector3.UP * 3.9)
	_anchor("wall_front", K - SIDE * 6.0 - DIAG * 1.4, DIAG)                 # mur juste devant
	_anchor("wall_far", K - SIDE * 6.0 - DIAG * 4.6, DIAG)                   # 4,6 m devant le mur (élan)
	_anchor("wall_side", K - DIAG * 7.0 - SIDE * 0.95, DIAG)                 # mur le long, sur la droite
	_anchor("corner", K - DIAG * 1.6 - SIDE * 1.6, DIAG)                     # dans le coin

	# --- Ouest : muret, rambarde, barrière haute (tous perpendiculaires à DIAG).
	var mc := Vector3(-12, 0, 3)
	wall(mc - SIDE * 3.0, mc + SIDE * 3.0, 0.9, 0.35, dark)
	_label("Muret 0,9 m", mc + Vector3.UP * 1.4)
	_anchor("muret", mc - DIAG * 3.0, DIAG)
	var rc := Vector3(-15, 0, 10)
	_railing(rc - SIDE * 3.0, rc + SIDE * 3.0, 1.1, metal)
	_label("Rambarde 1,1 m", rc + Vector3.UP * 1.6)
	_anchor("rambarde", rc - DIAG * 3.0, DIAG)
	var bc := Vector3(-6, 0, 12)
	for s in [-1.0, 1.0]:
		block(Vector3(0.25, 1.3, 0.25), bc + SIDE * 2.2 * s + Vector3.UP * 0.65, metal, atan2(SIDE.x, SIDE.z))
	wall(bc - SIDE * 2.3, bc + SIDE * 2.3, 0.5, 0.3, Color(0.85, 0.65, 0.15), 0.8)   # barre de 0,8 à 1,3 m
	_label("Glisse dessous", bc + Vector3.UP * 1.8)
	_anchor("low_bar", bc - DIAG * 4.5, DIAG)

	# --- Sud : piliers, tables cassables, objets à ramasser.
	for p in [Vector3(10, 0, 12), Vector3(14, 0, 16), Vector3(6, 0, 18), Vector3(16, 0, 9)]:
		_cyl(0.4, 3.0, p, Color(0.6, 0.58, 0.55))
	_anchor("pillars", Vector3(10, 0, 12) - DIAG * 2.5, DIAG)
	for p in [Vector3(1, 0, 15), Vector3(-2, 0, 18), K - DIAG * 4.0 - SIDE * 1.2]:
		breakables.append(_table(p))
	_anchor("table", Vector3(1, 0, 15) - DIAG * 3.2, DIAG)
	_anchor("table_near", Vector3(1, 0, 15) - DIAG * 1.6, DIAG)                 # tout près d'une table (l'enjamber, v0.216)
	_anchor("table_wall", K - DIAG * 9.0 - SIDE * 1.8, DIAG)
	var kinds := ["chair", "chair", "crate", "crate", "barrel", "barrel", "trash", "bench"]
	for i in kinds.size():
		var a := TAU * i / kinds.size()
		props.append(_prop(kinds[i], Vector3(-12, 0, 17) + Vector3(cos(a), 0, sin(a)) * 2.6))
	_anchor("center", Vector3.ZERO, DIAG)
	_anchor("props", Vector3(-12, 0, 17) - DIAG * 4.5, DIAG)                 # devant les objets à ramasser


## Hauteur du sol sous un point (depuis 2,5 m au-dessus).
func ground_y(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 4.0, at + Vector3.DOWN * 5.0, LAYER)   # 4 m : au-dessus du bloc de 3 m
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return at.y if r.is_empty() else r.position.y


## Rambarde : collision pleine (on ne passe pas entre les barreaux), rendu en barreaux + main courante.
func _railing(a: Vector3, b: Vector3, h: float, col: Color) -> void:
	var w := wall(a, b, h, 0.12, col)
	for c in w.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	var d := b - a
	var n := int(d.length() / 0.3)
	for k in n + 1:
		block(Vector3(0.06, h, 0.06), a + d * (float(k) / n) + Vector3.UP * h * 0.5, col, 0.0, false)
	block(Vector3(0.1, 0.08, d.length()), (a + b) * 0.5 + Vector3.UP * h, col.lightened(0.2), atan2(d.x, d.z), false)


func _table(at: Vector3) -> RigidBody3D:
	var b := _prop("table", at)
	b.set_meta("breakable", true)
	return b


## Objets mobiles : les mêmes que dans la run (room.gd), ramassables (groupe « reactive »).
func _prop(kind: String, at: Vector3) -> RigidBody3D:
	var r = preload("res://room.gd").new()
	var b: RigidBody3D = r._make(kind)
	r.free()
	add_child(b)
	b.position = at
	b.rotation.y = randf_range(0, TAU)
	return b


## Casse une table (ou tout objet marqué « breakable ») en morceaux physiques. Renvoie vrai si c'était cassable.
static func shatter(b: Node3D, push := Vector3.ZERO) -> bool:
	if b == null or not is_instance_valid(b) or not b.has_meta("breakable") or b.get_meta("broken", false):
		return false
	b.set_meta("broken", true)
	var parent := b.get_parent()
	var at := b.global_position
	for c in b.get_children():
		if not c is MeshInstance3D:
			continue
		var piece := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		var sz: Vector3 = (c.mesh as BoxMesh).size if c.mesh is BoxMesh else Vector3(0.2, 0.2, 0.2)
		# Le plateau se fend en deux.
		var parts := 2 if sz.x > 1.0 else 1
		for k in parts:
			var p2 := piece if k == 0 else RigidBody3D.new()
			var s2 := sz * Vector3(1.0 / parts, 1, 1)
			if k > 0:
				cs = CollisionShape3D.new()
				cs.shape = BoxShape3D.new()
			cs.shape.size = s2
			p2.add_child(cs)
			var mi := MeshInstance3D.new()
			mi.mesh = BoxMesh.new()
			mi.mesh.size = s2
			mi.material_override = c.material_override
			p2.add_child(mi)
			p2.collision_layer = 1
			p2.collision_mask = 1
			p2.mass = 1.0
			parent.add_child(p2)
			p2.global_transform = c.global_transform.translated(c.global_basis.x * (k - 0.5) * s2.x * (parts - 1))
			p2.linear_velocity = push * 0.6 + Vector3(randf_range(-2.5, 2.5), randf_range(2.0, 5.0), randf_range(-2.5, 2.5))
			p2.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
			p2.get_tree().create_timer(8.0).timeout.connect(p2.queue_free)
	b.queue_free()
	return true

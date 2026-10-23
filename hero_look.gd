extends RefCounted
## Look du héros : « Remontoir », un jouet de combat en fer-blanc des années 70 qui s'est remonté tout seul.
## Corps en tôle émaillée bleu-vert, plastron crème numéroté, casque arrondi à bandeau-visière noir et deux yeux jaunes,
## petite antenne à boule rouge, grosse clé de remontage en laiton dans le dos, gants rouges, pantalon marine, bottes orange.
## Chaque membre est construit à la place du bloc du squelette (mêmes pivots) : il marche tel quel avec le ragdoll.

const TEAL := Color(0.16, 0.55, 0.56)
const CREAM := Color(0.93, 0.86, 0.68)
const NAVY := Color(0.13, 0.16, 0.3)
const RED := Color(0.85, 0.16, 0.12)
const ORANGE := Color(0.95, 0.5, 0.1)
const BRASS := Color(0.85, 0.66, 0.25)
const BLACK := Color(0.06, 0.06, 0.07)
const EYE := Color(1.0, 0.85, 0.2)

static var _mats := {}


static func mat(c: Color, metal := 0.35, emit := false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), metal, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.45
	if emit:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
	_mats[key] = m
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, metal := 0.35) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = at
	mi.material_override = mat(c, metal)
	parent.add_child(mi)
	return mi


static func _ball(parent: Node3D, r: float, at: Vector3, c: Color, metal := 0.35, emit := false, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	mi.mesh = m
	mi.position = at
	mi.scale = sc
	mi.material_override = mat(c, metal, emit)
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r: float, h: float, at: Vector3, c: Color, metal := 0.35, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	mi.mesh = m
	mi.position = at
	mi.rotation_degrees = rot
	mi.material_override = mat(c, metal)
	parent.add_child(mi)
	return mi


## Habillage d'un membre (centré comme le bloc du squelette : `center` = centre du bloc, repère du pivot).
## Le héros regarde vers -Z.
static func part(name: String, center: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = "look_" + name
	var c := center
	match name:
		"hips":   # short marine, ceinture crème, boucle en laiton
			_box(n, Vector3(0.33, 0.2, 0.21), c, NAVY, 0.1)
			_box(n, Vector3(0.35, 0.06, 0.23), c + Vector3(0, 0.08, 0), CREAM)
			_box(n, Vector3(0.08, 0.06, 0.02), c + Vector3(0, 0.08, -0.125), BRASS, 0.8)
		"spine":   # buste en tôle émaillée, plastron crème avec numéro, épaulettes rondes, clé de remontage dans le dos
			_box(n, Vector3(0.38, 0.42, 0.22), c, TEAL)
			_box(n, Vector3(0.3, 0.26, 0.03), c + Vector3(0, 0.03, -0.12), CREAM)
			var num := Label3D.new()
			num.text = "07"
			num.font_size = 64
			num.pixel_size = 0.0022
			num.modulate = RED
			num.outline_size = 0
			num.position = c + Vector3(0, 0.03, -0.137)
			num.rotation_degrees = Vector3(0, 180, 0)
			n.add_child(num)
			_box(n, Vector3(0.4, 0.05, 0.23), c + Vector3(0, -0.19, 0), CREAM)   # liseré bas
			for sx in [-1.0, 1.0]:
				_ball(n, 0.1, c + Vector3(sx * 0.22, 0.17, 0), TEAL, 0.35, false, Vector3(1, 0.8, 1))
			var key := Node3D.new()
			key.name = "key"
			key.position = c + Vector3(0, 0.05, 0.11)
			n.add_child(key)
			_cyl(key, 0.025, 0.14, Vector3(0, 0, 0.07), BRASS, 0.8, Vector3(90, 0, 0))
			_ball(key, 0.09, Vector3(0.09, 0, 0.15), BRASS, 0.8, false, Vector3(1, 0.65, 0.25))
			_ball(key, 0.09, Vector3(-0.09, 0, 0.15), BRASS, 0.8, false, Vector3(1, 0.65, 0.25))
		"head":   # casque rond crème, bandeau-visière noir, deux yeux jaunes, antenne à boule rouge
			_ball(n, 0.15, c, CREAM, 0.3, false, Vector3(1, 1.05, 1))
			_box(n, Vector3(0.26, 0.075, 0.08), c + Vector3(0, 0.015, -0.11), BLACK, 0.6)
			for sx in [-1.0, 1.0]:
				_ball(n, 0.025, c + Vector3(sx * 0.06, 0.015, -0.152), EYE, 0.0, true)
			_box(n, Vector3(0.05, 0.03, 0.02), c + Vector3(0, -0.07, -0.135), BLACK, 0.6)   # bouche-grille
			_cyl(n, 0.012, 0.12, c + Vector3(0.05, 0.19, 0), BLACK, 0.6)
			_ball(n, 0.03, c + Vector3(0.05, 0.26, 0), RED, 0.2)
		"sh_l", "sh_r":   # haut de bras bleu-vert
			_box(n, Vector3(0.11, 0.3, 0.11), c, TEAL)
			_box(n, Vector3(0.12, 0.04, 0.12), c + Vector3(0, -0.13, 0), CREAM)
		"el_l", "el_r":   # avant-bras crème
			_box(n, Vector3(0.1, 0.27, 0.1), c, CREAM)
		"fist_l", "fist_r":   # gros gants rouges
			_ball(n, 0.085, c, RED, 0.15, false, Vector3(1, 1.1, 1.15))
		"hip_l", "hip_r":   # cuisse marine
			_box(n, Vector3(0.13, 0.42, 0.13), c, NAVY, 0.1)
		"kn_l", "kn_r":   # tibia marine, genouillère crème, botte orange
			_box(n, Vector3(0.11, 0.3, 0.11), c + Vector3(0, 0.07, 0), NAVY, 0.1)
			_ball(n, 0.065, c + Vector3(0, 0.2, -0.03), CREAM)
			_box(n, Vector3(0.15, 0.17, 0.15), c + Vector3(0, -0.15, 0), ORANGE, 0.2)
			_box(n, Vector3(0.15, 0.08, 0.22), c + Vector3(0, -0.2, -0.04), ORANGE, 0.2)
	return n

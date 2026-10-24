class_name Arena
extends Node3D
## Terrain d'essai du proto : un grand sol quadrillé (1 m / 5 m, pour juger les distances), une arène centrale, et autour
## des éléments utiles au combat : mur long (écrasés contre le mur), coin, plateforme de 1,6 m avec rampe et escalier
## (coups plongeants, chutes), piliers, murets. Les « situations » placent héros et mannequins.

const WALL := Color(0.86, 0.84, 0.8)
const ACCENT := Color(0.95, 0.55, 0.35)
var mats := {}
var spots := {}      # nom -> {hero: Vector3, face: Vector3, foes: [Vector3...]}


func _ready() -> void:
	_floor()
	_build()


func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		mats[k] = m
	return mats[k]


func _floor() -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120)
	cs.shape = bs
	cs.position.y = -0.5
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert;
uniform vec3 base : source_color = vec3(0.40, 0.43, 0.49);
uniform vec3 line : source_color = vec3(0.33, 0.36, 0.42);
uniform vec3 major : source_color = vec3(0.26, 0.29, 0.35);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
	float l = 1.0 - clamp(min(g.x, g.y) - 0.5, 0.0, 1.0);
	vec2 p5 = p / 5.0;
	vec2 g5 = abs(fract(p5 - 0.5) - 0.5) / fwidth(p5);
	float l5 = 1.0 - clamp(min(g5.x, g5.y) - 1.0, 0.0, 1.0);
	float r = length(p);
	float ring = 1.0 - clamp(abs(r - 7.0) / fwidth(r) - 1.5, 0.0, 1.0);
	vec3 c = mix(base, line, l * 0.8);
	c = mix(c, major, l5);
	c = mix(c, vec3(0.95, 0.6, 0.4), ring * 0.8);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	mi.material_override = m
	sb.add_child(mi)
	add_child(sb)


func block(size: Vector3, center: Vector3, col: Color, yaw := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(col)
	sb.add_child(mi)
	add_child(sb)
	sb.position = center
	sb.rotation.y = yaw
	sb.add_to_group("walls")
	return sb


## Rampe pleine de `a` (sol) à `b` (hauteur h), largeur w. Les marches d'escalier sont visuelles, la collision est une rampe.
func ramp(a: Vector3, b: Vector3, h: float, w: float, col: Color, steps := 0) -> void:
	var run := Vector2(b.x - a.x, b.z - a.z)
	var L := sqrt(run.length_squared() + h * h)
	var yaw := atan2(b.x - a.x, b.z - a.z)
	var pitch := atan2(h, run.length())
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 0.2, L)
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.position = (a + b) * 0.5 + Vector3.UP * (h * 0.5 - 0.1)
	sb.rotation = Vector3(-pitch, yaw, 0)
	if steps <= 0:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.2, L)
		mi.mesh = bm
		mi.material_override = _mat(col)
		sb.add_child(mi)
		# remplissage sous la rampe
		var fill := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(w, h, run.length())
		pm.left_to_right = 1.0
		fill.mesh = pm
		fill.material_override = _mat(col.darkened(0.15))
		add_child(fill)
		fill.position = (a + b) * 0.5 + Vector3.UP * h * 0.5
		fill.rotation.y = yaw + PI / 2
	else:
		var dir := Vector3(run.x, 0, run.y).normalized()
		var sl := run.length() / steps
		for i in steps:
			var sh := h * (i + 1) / steps
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w, sh, sl)
			mi.mesh = bm
			mi.material_override = _mat(col if i % 2 == 0 else col.darkened(0.08))
			add_child(mi)
			mi.position = a + dir * (sl * (i + 0.5)) + Vector3.UP * sh * 0.5
			mi.rotation.y = yaw


func pillar(at: Vector3, r: float, h: float, col: Color) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = r
	cy.height = h
	cs.shape = cy
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.material_override = _mat(col)
	sb.add_child(mi)
	add_child(sb)
	sb.position = at + Vector3.UP * h * 0.5
	sb.add_to_group("walls")


func label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = 0.01
	l.modulate = Color(1, 1, 1, 0.55)
	l.outline_size = 0
	l.rotation_degrees = Vector3(-90, 0, 0)
	add_child(l)
	l.position = at + Vector3.UP * 0.02


func _build() -> void:
	# Est : mur long (3,5 m) + coin -> écrasés contre le mur
	block(Vector3(0.8, 3.5, 22), Vector3(15, 1.75, -2), WALL)
	block(Vector3(10, 3.5, 0.8), Vector3(10.4, 1.75, -13), WALL)
	label("MUR", Vector3(12, 0, 2))
	# Nord-ouest : plateforme 1,6 m, rampe et escalier
	block(Vector3(9, 1.6, 7), Vector3(-12, 0.8, -12), Color(0.72, 0.7, 0.66))
	ramp(Vector3(-12, 0, -2.5), Vector3(-12, 0, -8.5), 1.6, 3.2, Color(0.8, 0.76, 0.7))
	ramp(Vector3(-3.0, 0, -10.0), Vector3(-7.5, 0, -10.0), 1.6, 3.0, Color(0.78, 0.74, 0.68), 7)
	label("PLATEFORME", Vector3(-12, 1.62, -12))
	# Ouest : murets et piliers
	block(Vector3(5, 0.9, 0.6), Vector3(-14, 0.45, 6), Color(0.7, 0.68, 0.64))
	block(Vector3(0.6, 0.9, 5), Vector3(-17, 0.45, 9), Color(0.7, 0.68, 0.64))
	for p in [Vector3(-8, 0, 12), Vector3(-4, 0, 15), Vector3(-11, 0, 17)]:
		pillar(p, 0.55, 3.2, Color(0.8, 0.78, 0.74))
	# Sud : bordure de l'aire de la ligne de mannequins
	label("LIGNE", Vector3(4, 0, 13))
	# Bords du terrain (on ne tombe pas du monde)
	for s in [Vector3(0, 1, -40), Vector3(0, 1, 40)]:
		block(Vector3(82, 2, 1), s, Color(0.6, 0.62, 0.66))
	for s in [Vector3(-40, 1, 0), Vector3(40, 1, 0)]:
		block(Vector3(1, 2, 82), s, Color(0.6, 0.62, 0.66))
	# Situations
	spots["centre"] = {"hero": Vector3(0, 0, 1.6), "face": Vector3(0, 0, -1), "foes": [Vector3(0, 0, -0.5), Vector3(-2.5, 0, -2.0), Vector3(2.5, 0, -2.0)]}
	spots["mur"] = {"hero": Vector3(8.5, 0, -2), "face": Vector3(1, 0, 0), "foes": [Vector3(11.5, 0, -2), Vector3(11.5, 0, 1.5), Vector3(11.5, 0, -5.5)]}
	spots["plateforme"] = {"hero": Vector3(-12, 1.65, -13.5), "face": Vector3(0, 0, 1), "foes": [Vector3(-12, 0, -6.5), Vector3(-9.5, 0, -6.5), Vector3(-14.5, 0, -6.5)]}
	spots["ligne"] = {"hero": Vector3(0, 0, 12), "face": Vector3(1, 0, 0), "foes": [Vector3(2.5, 0, 12), Vector3(4.0, 0, 12), Vector3(5.5, 0, 12), Vector3(7.0, 0, 12), Vector3(8.5, 0, 12)]}
	spots["foule"] = {"hero": Vector3(0, 0, 0), "face": Vector3(0, 0, -1), "foes": [Vector3(0, 0, -4), Vector3(3.5, 0, -2), Vector3(3.5, 0, 2.5), Vector3(-3.5, 0, 2.5), Vector3(-3.5, 0, -2), Vector3(0, 0, 4.5)]}

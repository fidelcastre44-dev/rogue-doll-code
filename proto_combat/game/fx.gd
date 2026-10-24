class_name Fx
extends Node3D
## Effets visuels d'impact : étincelles, éclair, onde de choc, poussière, textes qui montent.
## Tout est construit en code (pas d'images) : quads additifs + CPUParticles3D.

var _add_mat: StandardMaterial3D
var _dust_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _spark_mesh: QuadMesh
var _dust_mesh: SphereMesh


func _ready() -> void:
	_add_mat = StandardMaterial3D.new()
	_add_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_add_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_mat.vertex_color_use_as_albedo = true
	_add_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_add_mat.no_depth_test = true
	_add_mat.render_priority = 3
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.07, 0.42)
	_spark_mesh.material = _add_mat
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.vertex_color_use_as_albedo = true
	_dust_mesh = SphereMesh.new()
	_dust_mesh.radius = 0.18
	_dust_mesh.height = 0.36
	_dust_mesh.radial_segments = 8
	_dust_mesh.rings = 4
	_dust_mesh.material = _dust_mat
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _auto_free(n: Node, t: float) -> void:
	get_tree().create_timer(t, false, true).timeout.connect(n.queue_free)


## Étincelles d'impact : gerbe dans la direction du coup + éclair au centre.
func spark(at: Vector3, dir: Vector3, power := 1.0, col := Color(1, 0.92, 0.6)) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = at
	p.mesh = _spark_mesh
	p.amount = int(10 + 14 * power)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.22 + 0.1 * power
	p.direction = dir if dir.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 6.0 * (0.7 + power * 0.5)
	p.initial_velocity_max = 14.0 * (0.7 + power * 0.5)
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 12.0
	p.damping_max = 22.0
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4 + power * 0.4
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.3, col)
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g * 0.5, 0.1, 0.0))
	p.color_ramp = g
	p.emitting = true
	_auto_free(p, 1.0)
	_flash(at, 0.55 + 0.45 * power, col)


func _flash(at: Vector3, size: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	mat.render_priority = 4
	mat.albedo_texture = _star_tex()
	mat.albedo_color = Color(1, 1, 1, 1).lerp(col, 0.3)
	m.material_override = mat
	add_child(m)
	m.global_position = at
	var tw := create_tween()
	tw.set_parallel(true)
	m.scale = Vector3.ONE * 0.4
	tw.tween_property(m, "scale", Vector3.ONE * 1.25, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.12).set_delay(0.03)
	_auto_free(m, 0.3)


var _star: ImageTexture
func _star_tex() -> ImageTexture:
	if _star:
		return _star
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x - n * 0.5 + 0.5) / (n * 0.5)
			var v := (y - n * 0.5 + 0.5) / (n * 0.5)
			var r := sqrt(u * u + v * v)
			var cross := maxf(0.0, 1.0 - absf(u) * 9.0) * maxf(0.0, 1.0 - absf(v)) + maxf(0.0, 1.0 - absf(v) * 9.0) * maxf(0.0, 1.0 - absf(u))
			var a := clampf(pow(maxf(0.0, 1.0 - r), 2.2) * 1.4 + cross * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_star = ImageTexture.create_from_image(img)
	return _star


## Onde de choc : anneau qui s'élargit (au sol par défaut, ou face à `normal`).
func shockwave(at: Vector3, radius := 2.0, normal := Vector3.UP) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.95
	t.outer_radius = 1.0
	t.rings = 32
	t.ring_segments = 6
	m.mesh = t
	var mat := _ring_mat.duplicate()
	mat.albedo_color = Color(1, 0.8, 0.5, 0.35)
	m.material_override = mat
	add_child(m)
	m.global_position = at + normal * 0.05
	if normal != Vector3.UP:
		m.look_at(at + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
		m.rotate_object_local(Vector3.RIGHT, PI / 2)
	m.scale = Vector3(0.2, 0.2, 0.2)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3(radius, 0.15, radius), 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	_auto_free(m, 0.4)
	dust(at, radius * 0.6)


func dust(at: Vector3, size := 1.0) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = at + Vector3.UP * 0.1
	p.mesh = _dust_mesh
	p.amount = int(6 + 6 * size)
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.flatness = 0.7
	p.initial_velocity_min = 1.5 * size
	p.initial_velocity_max = 3.5 * size
	p.gravity = Vector3(0, 1.0, 0)
	p.damping_min = 6.0
	p.damping_max = 9.0
	p.scale_amount_min = 0.6 * size
	p.scale_amount_max = 1.3 * size
	var c := Curve.new()
	c.add_point(Vector2(0, 0.5))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = c
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.82, 0.78, 0.6))
	g.set_color(1, Color(0.85, 0.82, 0.78, 0.0))
	p.color_ramp = g
	p.emitting = true
	_auto_free(p, 1.0)


## Texte qui monte et disparaît (dégâts, CONTRE !, PARADE !).
func popup(at: Vector3, text: String, col := Color.WHITE, size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 14
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.pixel_size = 0.006
	add_child(l)
	l.global_position = at + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	l.scale = Vector3.ONE * 1.6
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position:y", at.y + 0.9, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.5)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.25).set_delay(0.5)
	_auto_free(l, 0.8)


## Traînée du coup (lisibilité) : arc horizontal, montant, descendant, ou trait droit (poings).
func slash(at: Vector3, fwd: Vector3, kind := "h", size := 1.0, col := Color(1, 1, 1)) -> void:
	if kind == "none":
		return
	var im := ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 1, 1, 0.75)
	mi.material_override = mat
	fwd.y = 0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		var a := lerpf(-1.1, 1.1, k)
		var p := Vector3.ZERO
		var w := 0.16 * size * sin(PI * k)
		var c := Color(col.r, col.g, col.b, sin(PI * k) * 0.9)
		var off := Vector3.UP * w
		match kind:
			"h":
				p = (fwd * cos(a) - side * sin(a)) * size
			"up":
				p = fwd * (0.45 + 0.35 * cos(a)) * size + Vector3.UP * (sin(a) * 0.8) * size
				off = side * w
			"down":
				p = fwd * (0.45 + 0.35 * cos(a)) * size - Vector3.UP * (sin(a) * 0.8) * size
				off = side * w
			"thrust":
				p = fwd * lerpf(0.25, 1.0, k) * size
				off = Vector3.UP * 0.06 * size * (1.0 - k)
		im.surface_set_color(c)
		im.surface_add_vertex(p - off)
		im.surface_set_color(c)
		im.surface_add_vertex(p + off)
	im.surface_end()
	add_child(mi)
	mi.global_position = at
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	_auto_free(mi, 0.25)

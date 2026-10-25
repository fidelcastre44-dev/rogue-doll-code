class_name GameView
extends Node3D
## L'AFFICHAGE du monde : un Puppet par combattant, la caméra, les effets, le décor, les barres. Écoute `SimWorld.stepped`
## et ne fait que montrer. Local chez chaque joueur (coop).

var world: SimWorld
var cam: Cam
var fx: Fx
var hud: Hud
var puppets := {}         # id -> Puppet
var show_hitboxes := false
var _hb_mesh: MeshInstance3D
var _im: ImmediateMesh
var ragdoll_on := true


func setup(w: SimWorld) -> void:
	world = w
	world.stepped.connect(_on_stepped)
	_lights()
	_arena()
	cam = Cam.new()
	cam.world = world
	add_child(cam)
	cam.current = true
	fx = Fx.new()
	add_child(fx)
	hud = Hud.new()
	hud.world = world
	hud.cam = cam
	add_child(hud)
	_im = ImmediateMesh.new()
	_hb_mesh = MeshInstance3D.new()
	_hb_mesh.mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.3, 0.2, 0.9)
	m.no_depth_test = true
	_hb_mesh.material_override = m
	add_child(_hb_mesh)


func _lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.1, 0.13)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.53, 0.62)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _arena() -> void:
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Arena.SIZE, Arena.SIZE)
	floor_m.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.27, 0.28, 0.32)
	mat.roughness = 0.95
	floor_m.material_override = mat
	add_child(floor_m)
	# damier léger pour lire les distances (1 m)
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var h := Arena.SIZE * 0.5
	var x := -h
	while x <= h:
		im.surface_add_vertex(Vector3(x, 0.01, -h))
		im.surface_add_vertex(Vector3(x, 0.01, h))
		im.surface_add_vertex(Vector3(-h, 0.01, x))
		im.surface_add_vertex(Vector3(h, 0.01, x))
		x += 2.0
	im.surface_end()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.36, 0.38, 0.43)
	grid.material_override = gm
	add_child(grid)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.55, 0.5, 0.45)
	for b in Arena.BLOCKS:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = b[1]
		mi.mesh = bx
		mi.position = b[0]
		mi.material_override = bm
		add_child(mi)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.3, 0.34)
	for w in [[Vector3(0, 2, -h), Vector3(Arena.SIZE, 4, 1)], [Vector3(0, 2, h), Vector3(Arena.SIZE, 4, 1)],
		[Vector3(-h, 2, 0), Vector3(1, 4, Arena.SIZE)], [Vector3(h, 2, 0), Vector3(1, 4, Arena.SIZE)]]:
		var mi := MeshInstance3D.new()
		var bx := BoxMesh.new()
		bx.size = w[1]
		mi.mesh = bx
		mi.position = w[0]
		mi.material_override = wm
		add_child(mi)


func puppet_of(fi: Fighter) -> Puppet:
	if fi == null:
		return null
	return puppets.get(fi.id)


func _sync_puppets() -> void:
	var seen := {}
	for fi in world.fighters:
		if not is_instance_valid(fi):
			continue
		seen[fi.id] = true
		if not puppets.has(fi.id):
			var p := Puppet.new()
			add_child(p)
			p.setup(fi)
			p.ragdoll_on = ragdoll_on
			puppets[fi.id] = p
	for id in puppets.keys():
		if not seen.has(id):
			puppets[id].queue_free()
			puppets.erase(id)
	cam.targets = world.players


func set_ragdoll(on: bool) -> void:
	ragdoll_on = on
	for id in puppets:
		puppets[id].ragdoll_on = on
		if not on:
			puppets[id].rag.stop()


func rebuild_puppet(fi: Fighter) -> void:
	if puppets.has(fi.id):
		puppets[fi.id].queue_free()
		puppets.erase(fi.id)
	_sync_puppets()


func _on_stepped(events: Array) -> void:
	_sync_puppets()
	for e in events:
		var p: Puppet = puppets.get(e.who)
		if p:
			p.on_event(e)
		match e.type:
			"hit_result":
				if e.result == "hit":
					var pw := clampf(float(e.shake) * 2.0, 0.3, 1.5)
					cam.add_trauma(float(e.shake) * 0.55)
					if float(e.shake) >= 0.4:
						cam.punch(float(e.shake))
					var target: Puppet = puppets.get(e.target)
					var dir := Vector3.UP
					if p and target:
						dir = (target.global_position - p.global_position).normalized()
					fx.spark(e.at, dir, pw, Color(1, 0.95, 0.5) if not e.crit else Color(1, 0.4, 0.3))
					if e.effect in ["knockdown", "launch", "spike"]:
						fx.dust(e.at - Vector3.UP * 0.5, 1.0)
					if e.crit:
						fx.popup(e.at + Vector3.UP * 0.6, "CRITIQUE", Color(1, 0.5, 0.3))
				elif e.result == "block":
					fx.spark(e.at, Vector3.UP, 0.4, Color(0.6, 0.8, 1.0))
					cam.add_trauma(0.08)
				elif e.result == "parry":
					fx.spark(e.at, Vector3.UP, 1.2, Color(1, 1, 0.5))
					fx.popup(e.at + Vector3.UP * 0.6, "PARADE", Color(1, 1, 0.5))
					cam.add_trauma(0.2)
				elif e.result == "armor":
					fx.popup(e.at + Vector3.UP * 0.6, "ARMURE", Color(0.9, 0.9, 0.9), 40)
			"slam_impact", "quake":
				cam.add_trauma(0.6)
				cam.punch(0.8)
				if p:
					fx.shockwave(p.global_position + p.global_transform.basis.z * 1.0 + Vector3.UP * 0.05, 2.4)
					fx.dust(p.global_position + p.global_transform.basis.z * 1.0, 1.4)
			"perfect_dodge":
				if p:
					fx.popup(p.global_position + Vector3.UP * 2.3, "ESQUIVE PARFAITE", Color(0.7, 1.0, 1.0))
			"guard_break":
				if p:
					fx.popup(p.global_position + Vector3.UP * 2.3, "GARDE BRISÉE", Color(1, 0.6, 0.4))
			"grab_escape":
				if p:
					fx.popup(p.global_position + Vector3.UP * 2.3, "IL SE DÉGAGE", Color(1, 0.6, 0.5))
			"land":
				if p and e.heavy:
					fx.dust(p.global_position, 1.0)
					cam.add_trauma(0.2)
			"down":
				if p:
					fx.dust(p.global_position, 0.8)
			"respawn":
				if p:
					fx.popup(p.global_position + Vector3.UP * 2.3, "REMIS À NEUF", Color(0.7, 0.9, 0.7), 36)
	if show_hitboxes:
		_draw_hitboxes()
	else:
		_im.clear_surfaces()


func _draw_hitboxes() -> void:
	_im.clear_surfaces()
	var any := false
	for fi in world.fighters:
		var s := fi.hit_sphere()
		if s.is_empty():
			continue
		if not any:
			_im.surface_begin(Mesh.PRIMITIVE_LINES)
			any = true
		var c: Vector3 = s[0]
		var r: float = s[1]
		if s[2] > 0.0:
			_im.surface_add_vertex(c)
			_im.surface_add_vertex(c - Vector3.UP * float(s[2]))
		for ring in 3:
			var prev := Vector3.ZERO
			for i in 25:
				var a := TAU * i / 24.0
				var p := c
				match ring:
					0: p += Vector3(cos(a), sin(a), 0) * r
					1: p += Vector3(cos(a), 0, sin(a)) * r
					2: p += Vector3(0, cos(a), sin(a)) * r
				if i > 0:
					_im.surface_add_vertex(prev)
					_im.surface_add_vertex(p)
				prev = p
	if any:
		_im.surface_end()

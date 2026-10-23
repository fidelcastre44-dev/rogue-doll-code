extends Node3D
## Boule d'énergie (coup lourd « hadoken ») : part tout droit, vite, et balaie tous les sbires sur son passage (chacun une fois).

const SPEED := 15.0
const LIFE := 1.2
const RADIUS := 0.65
const DMG := 14.0

var dir := Vector3.FORWARD
var force := 90.0
var owner_player: Node = null
var scale_base := 1.0
var life := LIFE
var mat := StandardMaterial3D.new()
var hits := {}   # sbires déjà touchés
var power := 1.0   # charge (0..1) : taille, portée de touche et dégâts


func _ready() -> void:
	scale_base = lerpf(0.45, 1.0, power)
	var core := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.32
	m.height = 0.64
	core.mesh = m
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.55, 0.85, 1.0)
	core.material_override = mat
	add_child(core)
	var glow := MeshInstance3D.new()
	var g := SphereMesh.new()
	g.radius = 0.55
	g.height = 1.1
	glow.mesh = g
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.4, 0.7, 1.0, 0.35)
	glow.material_override = gm
	add_child(glow)


func _physics_process(dt: float) -> void:
	life -= dt
	global_position += dir * SPEED * dt
	scale = Vector3.ONE * scale_base * (1.0 + 0.12 * sin(life * 40.0))   # elle pulse
	if life <= 0:
		queue_free()
		return
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = SphereShape3D.new()
	q.shape.radius = RADIUS * scale_base
	q.transform = Transform3D(Basis(), global_position)
	q.collision_mask = 2 | 8
	for r in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var victim = r.collider.get_parent()
		if not victim.has_method("hit") or hits.has(victim):
			continue
		hits[victim] = true
		var blocked: bool = victim.hit(r.collider, (dir + Vector3.UP * 0.35).normalized() * force, global_position, DMG * lerpf(0.4, 1.2, power), 1.0, power >= 0.99)
		if owner_player:
			if not blocked:
				owner_player._gain(DMG * 0.6)
			owner_player.get_parent().impact(0.07 if not blocked else 0.03, 0.7 if not blocked else 0.2)

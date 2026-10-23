class_name Projectile
extends Node3D
## Projectile (v0.212) : lancé par un sbire tireur du labo. Il touche le héros, sauf s'il est renvoyé (parade pile au bon moment,
## améliorations Renvoi), paré, ou encaissé par un bouclier (Défense). Renvoyé, il repart vers son tireur et frappe les sbires.

const SPEED := 11.0
const DMG := 10.0
const HIT_DMG := 14.0     # renvoyé : dégâts sur un sbire

var velocity := Vector3.ZERO
var shooter: Node3D = null
var hero: Node3D = null
var from_hero := false     # renvoyé par le héros
var life := 4.0
var mesh := MeshInstance3D.new()
var mat := StandardMaterial3D.new()
var result := ""           # (tests) "hit", "reflect", "absorb", "enemy", "wall"


func _ready() -> void:
	add_to_group("projectiles")
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radius = 0.16
	mesh.mesh.height = 0.32
	mat.albedo_color = Color(1.0, 0.55, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mesh.material_override = mat
	add_child(mesh)


func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	var a := global_position
	var b := a + velocity * dt
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		_end("wall")
		return
	global_position = b
	if not from_hero and hero and is_instance_valid(hero):
		var chest: Vector3 = hero.global_position + Vector3.UP * 1.1
		if chest.distance_to(b) < 0.75:
			if hero.is_invulnerable():
				return
			var res: String = hero.ups.deflect(self) if hero.get("ups") else ""
			if res == "reflect":
				_reflect()
			elif res == "absorb":
				hero.get_parent().impact(0.04, 0.3)
				_end("absorb")
			else:
				hero.take_hit(velocity.normalized(), DMG, shooter)
				_end("hit")
	elif from_hero:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.parts.is_empty() or e.state == "dead":
				continue
			var part: RigidBody3D = e.parts.chest
			if part.global_position.distance_to(b) < 0.7:
				e.hit(part, velocity.normalized() * 12.0 + Vector3.UP * 3.0, b, HIT_DMG, 1.0, true)
				if hero and hero.get("ups"):
					hero.ups.on_hit(e, "")
				if e.get_parent().has_method("impact"):
					e.get_parent().impact(0.08, 0.7)
				_end("enemy")
				return


func _reflect() -> void:
	from_hero = true
	result = "reflect"
	var to := (shooter.global_position + Vector3.UP * 1.2 - global_position) if shooter and is_instance_valid(shooter) and shooter.get("root") != null else -velocity
	if shooter and is_instance_valid(shooter) and not shooter.parts.is_empty():
		to = shooter.parts.chest.global_position - global_position
	velocity = to.normalized() * SPEED * 1.4
	mat.albedo_color = Color(0.4, 0.8, 1.0)
	mat.emission = Color(0.3, 0.7, 1.0)
	life = 3.0
	if hero:
		hero._flash(Color(0.6, 0.85, 1.0), 0.06)
		hero.get_parent().impact(0.06, 0.4)


func _end(why: String) -> void:
	result = why
	set_physics_process(false)
	visible = false
	get_tree().create_timer(0.5).timeout.connect(queue_free)

class_name Ragdoll
extends RefCounted
## Ragdoll VISUEL d'un perso (ne décide jamais du gameplay : la capsule du perso reste la vérité).
## Construit exactement comme le bouton « Create Physical Skeleton » de Godot (Skeleton3DEditor::create_physical_bone :
## capsule le long de l'os, body_offset = looking_at(os enfant), joint_offset au milieu) et réglé comme la démo officielle
## « Ragdoll Physics » (godot-demo-projects/3d/ragdoll_physics, même noms d'os UE) : ConeJoint swing 20° / twist 20°,
## bias 0.3, softness 0.8, relaxation 1, friction 0.6, rebond 0.8 ; mêmes rayons de capsule.
## Utilisation : start(impulsion) ; pin(cible) chaque image pour que le bassin suive la capsule (jongles) ;
## kick(impulsion, point) quand il reprend un coup ; blend_out(t) pour revenir à l'animation (influence 1 -> 0).

const LAYER := 8
# os -> [os enfant qui donne la longueur (ou "" = longueur fixe), rayon, longueur fixe]
const BONES := {
	"pelvis": ["spine_01", 0.15, 0.0],
	"spine_02": ["spine_03", 0.13, 0.0],
	"spine_03": ["neck_01", 0.15, 0.0],
	"Head": ["", 0.11, 0.22],
	"upperarm_l": ["lowerarm_l", 0.05, 0.0], "lowerarm_l": ["hand_l", 0.04, 0.0], "hand_l": ["", 0.04, 0.12],
	"upperarm_r": ["lowerarm_r", 0.05, 0.0], "lowerarm_r": ["hand_r", 0.04, 0.0], "hand_r": ["", 0.04, 0.12],
	"thigh_l": ["calf_l", 0.07, 0.0], "calf_l": ["foot_l", 0.05, 0.0], "foot_l": ["ball_l", 0.04, 0.0],
	"thigh_r": ["calf_r", 0.07, 0.0], "calf_r": ["foot_r", 0.05, 0.0], "foot_r": ["ball_r", 0.04, 0.0],
}
const NECK_SWING := 0.0

var skel: Skeleton3D
var sim: PhysicalBoneSimulator3D
var bones := {}          # nom -> PhysicalBone3D
var active := false
var pinned := false
var _tween: Tween
var _fwd_local := Vector3.FORWARD   # devant du perso exprimé dans le repère de spine_03 au repos
var _host: Node


func setup(sk: Skeleton3D, host: Node) -> void:
	skel = sk
	_host = host
	sim = PhysicalBoneSimulator3D.new()
	sim.name = "PhysicalBoneSimulator3D"
	skel.add_child(sim)
	for bn in BONES:
		var b := skel.find_bone(bn)
		if b < 0:
			continue
		var spec: Array = BONES[bn]
		var child_origin: Vector3
		if spec[0] != "" and skel.find_bone(spec[0]) >= 0:
			child_origin = skel.get_bone_rest(skel.find_bone(spec[0])).origin
		else:
			child_origin = Vector3(0, float(spec[2]), 0)
		var half := child_origin.length() * 0.5
		var cap := CapsuleShape3D.new()
		cap.height = maxf(half * 2.0, float(spec[1]) * 2.0 + 0.01)
		cap.radius = float(spec[1])
		var cs := CollisionShape3D.new()
		cs.shape = cap
		var ct := Transform3D()
		ct.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))   # rows (1,0,0) (0,0,1) (0,-1,0) de l'éditeur
		cs.transform = ct
		var up := Vector3.UP
		if up.cross(child_origin).is_zero_approx():
			up = Vector3(0, 0, 1)
		var body := Transform3D()
		body.basis = Basis.looking_at(child_origin, up)
		body.origin = body.basis * Vector3(0, 0, -half)
		var joint := Transform3D()
		joint.origin = Vector3(0, 0, half)
		var pb := PhysicalBone3D.new()
		pb.name = "Physical Bone " + bn
		pb.add_child(cs)
		sim.add_child(pb)
		pb.bone_name = bn
		pb.body_offset = body
		pb.joint_offset = joint
		pb.collision_layer = LAYER
		pb.collision_mask = 1
		pb.friction = 0.6
		pb.bounce = 0.8
		pb.mass = 3.0 if bn in ["pelvis", "spine_02", "spine_03"] else 1.0
		pb.linear_damp = 0.1
		pb.angular_damp = 0.8
		if bn != "pelvis":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", NECK_SWING if bn == "Head" else 20.0)
			pb.set("joint_constraints/twist_span", 20.0)
			pb.set("joint_constraints/bias", 0.3)
			pb.set("joint_constraints/softness", 0.8)
			pb.set("joint_constraints/relaxation", 1.0)
		bones[bn] = pb
	sim.influence = 1.0
	sim.active = false
	var s3 := skel.find_bone("spine_03")
	if s3 >= 0:
		var g := skel.get_bone_global_rest(s3)
		# devant du modèle (+Z) vu depuis l'os
		_fwd_local = (g.basis.inverse() * Vector3(0, 0, 1)).normalized()


## Passe en ragdoll en gardant la pose actuelle, avec une impulsion (m/s) sur tout le corps.
func start(vel: Vector3, pin := true) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	sim.influence = 1.0
	if not active:
		sim.active = true
		sim.physical_bones_start_simulation()
		active = true
	pinned = pin
	# bascule : le haut du corps part dans le sens du coup (ω = haut × direction), comme une vraie projection
	var flat := Vector3(vel.x, 0, vel.z)
	var spin := Vector3.UP.cross(flat.normalized()) * clampf(flat.length() * 0.9, 2.0, 9.0) if flat.length() > 0.1 else Vector3.ZERO
	for bn in bones:
		var pb: PhysicalBone3D = bones[bn]
		var h := pb.global_position.y - skel.global_position.y
		pb.linear_velocity = vel + spin.cross(Vector3.UP * (h - 0.95)) * 0.6
		pb.angular_velocity = spin + Vector3(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))


## Un coup pendant qu'il est en ragdoll : impulsion forte sur l'os le plus proche, plus faible sur le reste.
func kick(vel: Vector3, at: Vector3) -> void:
	if not active:
		return
	var best: PhysicalBone3D = null
	var bd := INF
	for bn in bones:
		var pb: PhysicalBone3D = bones[bn]
		var d := pb.global_position.distance_to(at)
		if d < bd:
			bd = d
			best = pb
	for bn in bones:
		var pb: PhysicalBone3D = bones[bn]
		pb.linear_velocity += vel * (1.0 if pb == best else 0.35)
	if best:
		best.angular_velocity += Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))


## Le bassin suit la capsule (cible monde) : le jeu garde la trajectoire du jongle, le corps ballotte autour.
func pin(target: Vector3, dt: float, stiffness := 22.0) -> void:
	if not active or not pinned:
		return
	var p: PhysicalBone3D = bones.get("pelvis")
	if not p:
		return
	var err := target - p.global_position
	if err.length() > 2.5:
		# trop loin (téléport, choc) : on recale tout le corps
		for bn in bones:
			(bones[bn] as PhysicalBone3D).global_position += err
		return
	var want := err * stiffness
	p.linear_velocity = p.linear_velocity.lerp(want, clampf(dt * 18.0, 0.0, 1.0))


## Retour à l'animation : l'influence du ragdoll descend à 0, puis la simulation s'arrête.
func blend_out(t := 0.3) -> void:
	if not active:
		return
	pinned = false
	if _tween:
		_tween.kill()
	_tween = _host.create_tween()
	_tween.tween_property(sim, "influence", 0.0, t)
	_tween.tween_callback(stop)


func stop() -> void:
	if active:
		sim.physical_bones_stop_simulation()
		sim.active = false
	active = false
	pinned = false
	sim.influence = 1.0


func pelvis_pos() -> Vector3:
	var p: PhysicalBone3D = bones.get("pelvis")
	return p.global_position if p else skel.global_position


func head_pos() -> Vector3:
	var h: PhysicalBone3D = bones.get("Head")
	return h.global_position if h else pelvis_pos() + Vector3.UP


func speed() -> float:
	var p: PhysicalBone3D = bones.get("pelvis")
	return p.linear_velocity.length() if p else 0.0


## Couché sur le dos ? (le devant du torse regarde vers le haut)
func face_up() -> bool:
	var b := skel.find_bone("spine_03")
	if b < 0:
		return true
	var g := skel.global_transform * skel.get_bone_global_pose(b)
	return (g.basis * _fwd_local).y > 0.0


var _held := {}
## Figé à l'impact : le ragdoll s'arrête aussi (vitesses mises de côté), puis repart.
func hold(on: bool) -> void:
	if not active:
		return
	if on and _held.is_empty():
		for bn in bones:
			var pb: PhysicalBone3D = bones[bn]
			_held[bn] = [pb.linear_velocity, pb.angular_velocity]
			pb.linear_velocity = Vector3.ZERO
			pb.angular_velocity = Vector3.ZERO
			pb.gravity_scale = 0.0
	elif on:
		for bn in bones:
			var pb: PhysicalBone3D = bones[bn]
			pb.linear_velocity = Vector3.ZERO
			pb.angular_velocity = Vector3.ZERO
	elif not _held.is_empty():
		for bn in bones:
			var pb: PhysicalBone3D = bones[bn]
			pb.gravity_scale = 1.0
			if _held.has(bn):
				pb.linear_velocity += _held[bn][0]
				pb.angular_velocity += _held[bn][1]
		_held.clear()


## Choc au sol : le corps perd une partie de son élan (sinon il glisse sur des mètres).
func damp(k: float) -> void:
	if not active:
		return
	for bn in bones:
		var pb: PhysicalBone3D = bones[bn]
		pb.linear_velocity = Vector3(pb.linear_velocity.x * k, pb.linear_velocity.y, pb.linear_velocity.z * k)

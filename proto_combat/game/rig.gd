class_name Rig
extends Node3D
## Le modèle 3D d'un perso (héros ou mannequin) et ses animations (Quaternius UAL + captures CMU, reprises sur son squelette).
## Le gameplay ne dépend jamais de l'animation : il donne les temps (frame data), l'animation suit.
## play(nom, fondu, vitesse) ; freeze() pour le figé à l'impact ; flash() blanc quand il est touché ;
## shake() petit recul visuel (le corps logique ne bouge pas).

const MODELS := {
	"male": ["res://assets/hero/male/Superhero_Male_FullBody.gltf", "male"],
	"female": ["res://assets/hero/female/Superhero_Female_FullBody.gltf", "female"],
	"dummy": ["res://assets/anims/Mannequin_F.glb", "dummy"],
}

var model: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var current := ""
var base_speed := 1.0
var frozen := 0.0
var meshes: Array[MeshInstance3D] = []
var flash_t := 0.0
var flash_col := Color.WHITE
var _flash_mat: StandardMaterial3D
var shake_t := 0.0
var shake_dir := Vector3.ZERO
var lean := Vector3.ZERO        # inclinaison visuelle (degrés) ajoutée par le jeu
var tint := Color(1, 1, 1, 0)   # teinte (mannequins : couleur du mode)
var kind := ""


func setup(which: String) -> void:
	kind = which
	model = load(MODELS[which][0]).instantiate()
	add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	ap = AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = NodePath("..")
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	ap.add_animation_library("", load("res://assets/anims/lib_%s.res" % MODELS[which][1]))
	var cmu := "res://assets/anims/lib_cmu_%s.res" % MODELS[which][1]
	if ResourceLoader.exists(cmu):
		ap.add_animation_library("cmu", load(cmu))
	for m in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if m.name == "Eyebrows":
			m.visible = false
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.0)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.no_depth_test = false
	for m in meshes:
		m.material_overlay = _flash_mat


func has(anim: String) -> bool:
	return ap.has_animation(anim)


## Joue une animation. blend = fondu (s) ; speed = vitesse ; from = départ (s) ; restart = relancer si déjà jouée.
func play(anim: String, blend := 0.1, speed := 1.0, from := 0.0, restart := true) -> void:
	if not ap.has_animation(anim):
		push_warning("animation absente : " + anim)
		return
	base_speed = speed
	if current == anim and not restart:
		ap.speed_scale = speed if frozen <= 0 else 0.0
		return
	current = anim
	ap.play(anim, blend, 1.0)
	if from > 0.0:
		ap.seek(from, true)
	ap.speed_scale = speed if frozen <= 0 else 0.0


func set_speed(s: float) -> void:
	base_speed = s
	if frozen <= 0:
		ap.speed_scale = s


func pos() -> float:
	return ap.current_animation_position


func length() -> float:
	return ap.current_animation_length if ap.current_animation != "" else 0.0


func freeze(t: float) -> void:
	frozen = maxf(frozen, t)
	ap.speed_scale = 0.0


func flash(t := 0.1, col := Color.WHITE) -> void:
	flash_t = t
	flash_col = col


func shake(t: float, dir: Vector3) -> void:
	shake_t = t
	shake_dir = dir


## Position monde d'un os (hitbox qui suit un membre, effets).
func bone_pos(bone: String) -> Vector3:
	var b := skel.find_bone(bone)
	if b < 0:
		return global_position
	return skel.global_transform * skel.get_bone_global_pose(b).origin


func tick(dt: float) -> void:
	if frozen > 0.0:
		frozen -= dt
		if frozen <= 0.0:
			ap.speed_scale = base_speed
	if flash_t > 0.0:
		flash_t -= dt
		_flash_mat.albedo_color = Color(flash_col.r, flash_col.g, flash_col.b, clampf(flash_t / 0.1, 0, 1) * 0.85)
	elif tint.a > 0.0:
		_flash_mat.albedo_color = tint
	else:
		_flash_mat.albedo_color.a = 0.0
	var off := Vector3.ZERO
	if shake_t > 0.0:
		shake_t -= dt
		var k := shake_t / 0.15
		off = shake_dir * 0.12 * k + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.035 * k
	model.position = off
	model.rotation_degrees = lean

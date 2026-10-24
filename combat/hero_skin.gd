extends Node3D
class_name HeroSkin
## Habillage 3D du héros (v0.22) : un modèle riggé (Superhero homme / femme) qui suit, à chaque image, le squelette en cubes
## de player.gd. Les cubes restent la vérité du jeu (coups, zones de frappe, éditeur d'animation, ragdoll) : ils sont seulement cachés.
## Principe : chaque os du modèle copie la rotation d'un bloc du héros. On calcule une fois la « pose zéro » du modèle (bras et
## jambes alignés vers le bas, buste vers le haut, comme le héros quand toutes ses articulations sont à 0), puis
## os = rotation du bloc × pose zéro. Rien à régler dans les animations.
## F4 (partout) : homme -> femme -> cubes. Le choix est gardé dans user://hero.cfg.

const LOOKS := ["male", "female", "cubes"]
const SCENES := {
	"male": "res://hero/male/Superhero_Male_FullBody.gltf",
	"female": "res://hero/female/Superhero_Female_FullBody.gltf",
}
const CFG := "user://hero.cfg"
const LEG := 0.88   # hanche -> cheville du héros en cubes (THIGH + SHIN)

# os du modèle -> [bloc du héros, 2e bloc (mélange), part du 2e bloc, direction de l'os en pose zéro (repère du héros, null = pas d'alignement)]
const MAP := {
	"pelvis": ["hips", "", 0.0, Vector3.UP],
	"spine_01": ["hips", "spine", 0.4, Vector3.UP],
	"spine_02": ["hips", "spine", 0.75, Vector3.UP],
	"spine_03": ["spine", "", 0.0, Vector3.UP],
	"neck_01": ["spine", "head", 0.5, Vector3.UP],
	"Head": ["head", "", 0.0, null],
	"clavicle_l": ["spine", "", 0.0, null],
	"clavicle_r": ["spine", "", 0.0, null],
	"upperarm_l": ["sh_l", "", 0.0, Vector3.DOWN],
	"lowerarm_l": ["el_l", "", 0.0, Vector3.DOWN],
	"hand_l": ["el_l", "", 0.0, Vector3.DOWN],
	"upperarm_r": ["sh_r", "", 0.0, Vector3.DOWN],
	"lowerarm_r": ["el_r", "", 0.0, Vector3.DOWN],
	"hand_r": ["el_r", "", 0.0, Vector3.DOWN],
	"thigh_l": ["hip_l", "", 0.0, Vector3.DOWN],
	"calf_l": ["kn_l", "", 0.0, Vector3.DOWN],
	"thigh_r": ["hip_r", "", 0.0, Vector3.DOWN],
	"calf_r": ["kn_r", "", 0.0, Vector3.DOWN],
}
const CURL := 75.0       # doigts repliés : poings fermés
const THUMB_CURL := 35.0

static var look := ""

var hero: Node3D
var sk: Skeleton3D
var order := []          # os, parents d'abord
var zero := {}           # os -> rotation en pose zéro (repère du squelette)
var zero_local := {}     # os -> rotation locale en pose zéro (os non pilotés)
var k := {}              # os -> Rps × pose zéro
var rps := Basis()       # rotation squelette -> héros
var pelvis_off := Vector3.ZERO
var pelvis := -1


static func current() -> String:
	if look == "":
		var c := ConfigFile.new()
		look = "male"
		if c.load(CFG) == OK:
			look = c.get_value("hero", "look", "male")
		if not look in LOOKS:
			look = "male"
	return look


static func cycle() -> String:
	look = LOOKS[(LOOKS.find(current()) + 1) % LOOKS.size()]
	var c := ConfigFile.new()
	c.set_value("hero", "look", look)
	c.save(CFG)
	return look


## Crée l'habillage choisi sur le héros (null = cubes).
static func attach(h: Node3D) -> HeroSkin:
	var l := current()
	if not SCENES.has(l):
		return null
	var ps: PackedScene = load(SCENES[l])
	if ps == null:
		return null
	var s := HeroSkin.new()
	s.name = "Skin"
	s.hero = h
	s.add_child(ps.instantiate())
	h.add_child(s)
	return s


func _ready() -> void:
	rotation_degrees.y = 180.0   # le modèle regarde vers +Z, le héros vers -Z
	sk = find_children("*", "Skeleton3D", true, false)[0]
	for m in find_children("*", "MeshInstance3D", true, false):
		if m.name.to_lower().contains("eyebrow"):
			m.visible = false   # sourcils : cartes sans transparence (textures sans alpha), plaques grises sinon
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sk.reset_bone_poses()
	# Mise à l'échelle : la jambe du modèle = celle du héros.
	var leg := sk.get_bone_global_rest(sk.find_bone("thigh_l")).origin.distance_to(sk.get_bone_global_rest(sk.find_bone("foot_l")).origin)
	scale = Vector3.ONE * LEG / leg
	pelvis = sk.find_bone("pelvis")
	for b in sk.get_parentless_bones():
		_walk(b)
	_build_zero()


func _walk(b: int) -> void:
	order.append(b)
	for c in sk.get_bone_children(b):
		_walk(c)


func _skel_to_hero() -> Transform3D:
	# repère du squelette dans celui du héros (sans compter le mouvement du héros)
	var t := Transform3D(Basis.from_euler(Vector3(0, PI, 0)).scaled(scale), Vector3.ZERO)
	var n: Node = sk
	var acc := Transform3D.IDENTITY
	while n != self:
		acc = (n as Node3D).transform * acc
		n = n.get_parent()
	return t * acc


func _build_zero() -> void:
	var sh := _skel_to_hero()
	rps = sh.basis.orthonormalized()
	# 1er passage : pose zéro sans les clavicules, pour savoir où tombent les hanches ; 2e : clavicules visées vers les épaules des cubes.
	var r := _zero_pass(sh, Vector3.ZERO, false)
	var gp: Dictionary = r[1]
	var mid: Vector3 = (sh * gp[sk.find_bone("thigh_l")] + sh * gp[sk.find_bone("thigh_r")]) * 0.5
	var shift := Vector3(0, 0.9, 0) - mid   # modèle recalé : milieu des hanches = pivots des hanches du héros
	r = _zero_pass(sh, shift, true)
	var g: Dictionary = r[0]
	# Poings fermés : chaque phalange se replie vers la paume.
	for b in order:
		var nm := sk.get_bone_name(b)
		if nm.contains("_0") and (nm.begins_with("index") or nm.begins_with("middle") or nm.begins_with("ring") or nm.begins_with("pinky") or nm.begins_with("thumb")) and not nm.contains("leaf"):
			var a := deg_to_rad(THUMB_CURL if nm.begins_with("thumb") else CURL)
			zero_local[b] = zero_local[b] * Quaternion(Vector3.RIGHT, a)
	for nm in MAP:
		var b := sk.find_bone(nm)
		if b >= 0:
			k[b] = rps * g[b]
	# Décalage du bassin du modèle par rapport au pivot du bassin du héros (repère du héros, pose zéro).
	pelvis_off = sh * gp[pelvis] + shift - Vector3(0, 0.9, 0)


## Pose zéro : chaque os piloté est tourné (au plus court) pour pointer dans la direction du bloc du héros au repos.
## Renvoie [rotations globales, positions globales] (repère du squelette).
func _zero_pass(sh: Transform3D, shift: Vector3, clav: bool) -> Array:
	var g := {}
	var gp := {}
	for b in order:
		var p := sk.get_bone_parent(b)
		var rest := sk.get_bone_rest(b)
		var pb: Basis = g[p] if p >= 0 else Basis()
		gp[b] = (gp[p] + pb * rest.origin) if p >= 0 else rest.origin
		var gb: Basis = pb * rest.basis.orthonormalized()
		var nm := sk.get_bone_name(b)
		var want := Vector3.ZERO
		var c := -1
		if MAP.has(nm) and MAP[nm][3] != null:
			want = rps.inverse() * MAP[nm][3]
			c = sk.get_bone_children(b)[0] if sk.get_bone_children(b).size() > 0 else -1
			if nm == "pelvis":
				c = sk.find_bone("spine_01")
			if nm.begins_with("hand"):
				c = sk.find_bone("middle_01_" + nm.right(1))
			if nm.begins_with("foot"):
				c = sk.find_bone("ball_" + nm.right(1))
		elif clav and nm.begins_with("clavicle"):
			var side := -1.0 if nm.ends_with("_l") else 1.0
			var target := Vector3(0.26 * side, 1.53, 0)   # pivot de l'épaule des cubes au repos
			var at: Vector3 = sh * gp[b] + shift
			want = rps.inverse() * (target - at)
			c = sk.find_bone("upperarm_" + nm.right(1))
		if c >= 0 and want != Vector3.ZERO:
			var cur: Vector3 = (gb * sk.get_bone_rest(c).origin).normalized()
			gb = Basis(Quaternion(cur, want.normalized())) * gb
		g[b] = gb
		zero_local[b] = (pb.inverse() * gb).get_rotation_quaternion()
	return [g, gp]


## Rotation monde d'un bloc du héros (ou du morceau de ragdoll quand il est en pantin).
func _drv(n: String) -> Quaternion:
	if hero.rag.has(n):
		return hero.rag[n].global_basis.get_rotation_quaternion()
	return hero.j[n].global_basis.get_rotation_quaternion()


func _process(_dt: float) -> void:
	if hero == null or sk == null:
		return
	var rsk_inv := sk.global_basis.orthonormalized().inverse()
	var want := {}   # os piloté -> rotation globale voulue (repère du squelette)
	for nm in MAP:
		var b := sk.find_bone(nm)
		if b < 0:
			continue
		var m: Array = MAP[nm]
		var q := _drv(m[0])
		if m[1] != "":
			q = q.slerp(_drv(m[1]), m[2])
		want[b] = rsk_inv * Basis(q) * k[b]
	var g := {}
	for b in order:
		var p := sk.get_bone_parent(b)
		var pg: Basis = g[p] if p >= 0 else Basis()
		var lq: Quaternion
		if want.has(b):
			lq = (pg.inverse() * want[b]).get_rotation_quaternion()
		else:
			lq = zero_local[b]
		sk.set_bone_pose_rotation(b, lq)
		g[b] = pg * Basis(lq)
	# Position du bassin : suit le pivot du bassin du héros.
	var hips_pos: Vector3
	var hb: Basis
	if hero.rag.has("hips"):
		hb = hero.rag.hips.global_basis.orthonormalized()
		hips_pos = hero.rag.hips.global_position - hb * Vector3(0, 0.1, 0)
	else:
		hb = hero.j.hips.global_basis.orthonormalized()
		hips_pos = hero.j.hips.global_position
	var world: Vector3 = hips_pos + hb * pelvis_off
	var sp := sk.global_transform.affine_inverse() * world
	var pp := sk.get_bone_parent(pelvis)
	var pgt := Transform3D.IDENTITY
	if pp >= 0:
		pgt = sk.get_bone_global_pose(pp)
	sk.set_bone_pose_position(pelvis, pgt.affine_inverse() * sp)


## Calque de flash (coups reçus, parade, charge) sur tout le modèle.
func set_overlay(m: Material) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m

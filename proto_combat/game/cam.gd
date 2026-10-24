class_name Cam
extends Camera3D
## Caméra vue de dessus façon Death's Door : angle fixe en diagonale, suit le héros en douceur avec une avance dans le sens
## du déplacement, se décale un peu vers le combat (ennemis proches), secousses « trauma » (Eiserloh : décalage = bruit × trauma²)
## et petit coup de zoom sur les gros impacts. Zoom réglable (menu).

var target: Node3D
var game: Node
var yaw := 0.0                # degrés (0 = la caméra regarde vers le nord, -Z = haut de l écran)
var pitch := 52.0
var dist := 16.0
var zoom := 1.0
var trauma := 0.0
var kick := 0.0               # coup de zoom (0-1)
var focus := Vector3.ZERO
var focus_y := 0.0
var noise := FastNoiseLite.new()
var t := 0.0


func _ready() -> void:
	fov = 34.0
	near = 0.5
	far = 200.0
	noise.frequency = 2.5
	noise.seed = 7
	process_mode = Node.PROCESS_MODE_ALWAYS


func snap() -> void:
	focus = target.global_position
	focus_y = focus.y
	_place(0.0)


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


func punch(a: float) -> void:
	kick = clampf(maxf(kick, a), 0.0, 1.0)


func _process(dt: float) -> void:
	if not target:
		return
	var rdt := dt / maxf(Engine.time_scale, 0.05) if get_tree().paused == false else 0.0
	t += rdt
	var want: Vector3 = target.global_position
	var hv: Vector3 = target.get("hvel") if target.get("hvel") != null else Vector3.ZERO
	want += hv.limit_length(10.0) * 0.16
	# se décale vers les ennemis proches (cadre le combat)
	if game:
		var sum := Vector3.ZERO
		var n := 0
		for e in game.enemies:
			var d: Vector3 = e.global_position - target.global_position
			if d.length() < 7.0:
				sum += d
				n += 1
		if n > 0:
			want += (sum / n).limit_length(3.0) * 0.25
	focus.x = lerpf(focus.x, want.x, 1.0 - exp(-7.0 * dt))
	focus.z = lerpf(focus.z, want.z, 1.0 - exp(-7.0 * dt))
	# en hauteur : plus lent (le saut ne fait pas tanguer l'image), sauf grosse chute
	var ky := 2.5 if absf(want.y - focus_y) < 3.0 else 8.0
	focus_y = lerpf(focus_y, want.y, 1.0 - exp(-ky * dt))
	trauma = maxf(trauma - 1.6 * rdt, 0.0)
	kick = maxf(kick - 4.0 * rdt, 0.0)
	_place(rdt)


func _place(_dt: float) -> void:
	var d := dist * zoom * (1.0 - kick * 0.06)
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(pitch)).rotated(Vector3.UP, deg_to_rad(yaw))
	var f := Vector3(focus.x, focus_y + 0.9, focus.z)
	global_position = f + dir * d
	look_at(f, Vector3.UP)
	var s := trauma * trauma
	if s > 0.0:
		var ox := noise.get_noise_2d(t * 60.0, 0.0) * 0.4 * s
		var oy := noise.get_noise_2d(0.0, t * 60.0) * 0.4 * s
		var rz := noise.get_noise_2d(t * 60.0, 100.0) * deg_to_rad(2.0) * s
		global_position += global_transform.basis.x * ox + global_transform.basis.y * oy
		rotate_object_local(Vector3.BACK, rz)


## Avant (sur le sol) et droite de la caméra : le stick est lu dans ce repère.
func flat_forward() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(yaw))


func flat_right() -> Vector3:
	return Vector3(1, 0, 0).rotated(Vector3.UP, deg_to_rad(yaw))

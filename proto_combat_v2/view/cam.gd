class_name Cam
extends Camera3D
## Caméra vue de dessus façon Death's Door : angle en diagonale, suit le ou les joueurs (coop locale : une caméra commune
## qui cadre les deux), légère avance dans le sens du déplacement, secousses « trauma » dosées, coup de zoom sur les gros
## impacts. Rotation 360°, inclinaison 25-65° et zoom réglables dans le menu (gardés dans les réglages).

var targets: Array = []       # Fighters
var world: SimWorld
var yaw := 0.0                # degrés (0 = la caméra regarde vers le nord, -Z = haut de l'écran)
var pitch := 42.0
var dist := 15.0
var zoom := 1.0
var trauma := 0.0
var kick := 0.0
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
	yaw = Tuning.v("cam_yaw")
	pitch = Tuning.v("cam_pitch")
	zoom = Tuning.v("cam_zoom")


func snap() -> void:
	if targets.is_empty():
		return
	focus = _want()
	focus_y = focus.y
	_place()


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a * Tuning.v("shake_scale"), 0.0, 1.0)


func punch(a: float) -> void:
	kick = clampf(maxf(kick, a), 0.0, 1.0)


func _want() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for tg in targets:
		if not is_instance_valid(tg):
			continue
		sum += tg.global_position + (tg.hvel as Vector3).limit_length(10.0) * 0.14
		n += 1
	if n == 0:
		return focus
	var want := sum / n
	# se décale un peu vers les ennemis proches (cadre le combat)
	if world and n == 1:
		var s2 := Vector3.ZERO
		var k := 0
		for e in world.foes:
			var d: Vector3 = e.global_position - want
			if d.length() < 7.0:
				s2 += d
				k += 1
		if k > 0:
			want += (s2 / k).limit_length(3.0) * 0.25
	return want


func _process(dt: float) -> void:
	if targets.is_empty():
		return
	t += dt
	var want := _want()
	# deux joueurs : on recule pour garder les deux dans le cadre
	var spread := 0.0
	if targets.size() > 1 and is_instance_valid(targets[0]) and is_instance_valid(targets[1]):
		spread = targets[0].global_position.distance_to(targets[1].global_position)
	focus.x = lerpf(focus.x, want.x, 1.0 - exp(-7.0 * dt))
	focus.z = lerpf(focus.z, want.z, 1.0 - exp(-7.0 * dt))
	var ky := 2.5 if absf(want.y - focus_y) < 3.0 else 8.0
	focus_y = lerpf(focus_y, want.y, 1.0 - exp(-ky * dt))
	trauma = maxf(trauma - 1.6 * dt, 0.0)
	kick = maxf(kick - 4.0 * dt, 0.0)
	_place(spread)


func _place(spread := 0.0) -> void:
	var d := dist * zoom * (1.0 - kick * 0.06) + maxf(spread - 4.0, 0.0) * 0.9
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


func yaw_rad() -> float:
	return deg_to_rad(yaw)

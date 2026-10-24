class_name Dummy
extends CharacterBody3D
## Mannequin d'entraînement (sbire). Les états de jeu restent lisibles comme dans un jeu de baston pro ; le ragdoll est
## seulement VISUEL (game/ragdoll.gd) : en l'air le bassin du pantin suit la capsule (la trajectoire du jongle reste celle
## du jeu), au sol il tombe librement, puis il se relève depuis la pose où il est tombé (sur le dos / à plat ventre).
## Modes : "passive" (encaisse), "guard" (garde de face, se fait briser par les coups lourds), "attack" (IA qui tourne autour
## du héros et frappe en prévenant : flash rouge = coup normal, orange = coup lourd imparable, à esquiver ou parer).
## États : idle, walk, windup, strike, recover, hurt, air (jonglé / projeté), down (à terre), getup, block, stagger, grabbed, splat.

const RADIUS := 0.35
const HEIGHT := 1.75
const GRAV := 26.0
const JUGGLE_GRAV := 21.0
const HP_MAX := 120.0

var game: Node
var rig: Rig
var mode := "passive"
var state := "idle"
var f := 0
var facing := Vector3(0, 0, 1)
var hvel := Vector3.ZERO
var hitstop := 0
var stun := 0
var hp := HP_MAX
var juggle := 0
var home := Vector3.ZERO
var atk := {}                 # coup en cours
var atk_cool := 1.0
var has_token := false
var strafe_dir := 1.0
var strafe_t := 0.0
var lean_v := Vector3.ZERO
var lean_target := Vector3.ZERO
var thrown_by: Node = null
var grabbed_by: Node = null
var last_hit_t := 0.0
var color := Color(0.62, 0.45, 1.0)
var ko := false
var down_from_air := false
var bar: Node3D
var bar_fill: MeshInstance3D
var bar_back: MeshInstance3D
var rag: Ragdoll
var ragdoll_on := true
var last_vy := 0.0              # vitesse verticale juste avant le dernier déplacement (le sol la remet à 0)
var slammed_by: Node = null     # v0.112 : éclaté au sol par une chope (rebond plus haut, impact signalé au héros)

const ATTACKS := {
	"light": {"anim": "cross", "from": 0.0, "hit": 0.283, "end": 0.7, "windup": 26, "active": 4, "recovery": 26, "reach": 1.5, "dmg": 8, "kb": 5.0, "heavy": false, "flash": Color(1, 0.15, 0.1)},
	"heavy": {"anim": "hook", "from": 0.0, "hit": 0.267, "end": 0.467, "windup": 38, "active": 5, "recovery": 34, "reach": 2.4, "dmg": 16, "kb": 9.0, "heavy": true, "lunge": 2.2, "flash": Color(1, 0.55, 0.0)},
	# v0.113 : coups de pied Mixamo (« Mma Low Kick » normal, « Mma Roundhouse Kick » lourd)
	"kick": {"anim": "mx/enemy__mma_low_kick", "from": 0.2, "hit": 0.5, "end": 0.9, "windup": 24, "active": 4, "recovery": 26, "reach": 1.7, "dmg": 9, "kb": 5.0, "heavy": false, "flash": Color(1, 0.15, 0.1)},
	"round": {"anim": "mx/enemy__mma_roundhouse", "from": 0.35, "hit": 0.75, "end": 1.1, "windup": 34, "active": 5, "recovery": 32, "reach": 2.0, "dmg": 15, "kb": 9.0, "heavy": true, "flash": Color(1, 0.55, 0.0)},
}

## Réactions aux coups (Mixamo, v0.113) : choisies selon le côté d'où vient le coup, sa hauteur et sa force, au hasard sans
## rejouer la même deux fois de suite.
const HIT_ANIMS := {
	"front_high": ["mx/hit__head_light_left", "mx/hit__head_light_right", "mx/hit__head_medium_straight"],
	"front_high_big": ["mx/hit__head_big_left", "mx/hit__head_big_right", "mx/hit__head_big_straight"],
	"front_low": ["mx/hit__stomach_hit", "mx/hit__punch_body"],
	"front_low_big": ["mx/hit__stomach_big", "mx/hit__punch_body"],
	"back": ["mx/hit__back_small"], "back_big": ["mx/hit__back_large", "mx/hit__back_small"],
	"left": ["mx/hit__side_left"], "right": ["mx/hit__side_right"],
}
var last_hit_anim := ""


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	rig = Rig.new()
	add_child(rig)
	rig.setup("dummy")
	rig.play("idle", 0.0)
	rag = Ragdoll.new()
	rag.setup(rig.skel, self)
	_make_bar()
	home = global_position
	set_mode(mode)


func _make_bar() -> void:
	bar = Node3D.new()
	add_child(bar)
	bar.position = Vector3(0, 2.15, 0)
	bar_back = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.09)
	bar_back.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 1
	bar_back.material_override = m
	bar.add_child(bar_back)
	bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.86, 0.06)
	bar_fill.mesh = q2
	var m2 := m.duplicate()
	m2.albedo_color = Color(1, 0.3, 0.35)
	m2.render_priority = 2
	bar_fill.material_override = m2
	bar.add_child(bar_fill)


func set_mode(m: String) -> void:
	mode = m
	match m:
		"passive": color = Color(0.62, 0.45, 1.0)
		"guard": color = Color(0.35, 0.6, 1.0)
		"attack": color = Color(1.0, 0.45, 0.4)
	rig.tint = Color(color.r, color.g, color.b, 0.22)
	if state in ["windup", "strike", "recover"]:
		_to_idle()


func reset_at(p: Vector3, face: Vector3) -> void:
	slammed_by = null
	grabbed_by = null
	global_position = p
	home = p
	facing = face
	velocity = Vector3.ZERO
	hvel = Vector3.ZERO
	hp = HP_MAX
	ko = false
	juggle = 0
	if rag:
		rag.stop()
	_to_idle()


# ------------------------------------------------------------------ boucle

func _physics_process(dt: float) -> void:
	_update_bar()
	if hitstop > 0:
		hitstop -= 1
		rag.hold(true)
		rig.tick(dt)
		return
	rag.hold(false)
	f += 1
	atk_cool -= dt
	last_hit_t += dt
	var on_floor := is_on_floor()
	match state:
		"idle", "walk": _st_idle(dt, on_floor)
		"windup", "strike", "recover": _st_attack(dt, on_floor)
		"hurt": _st_hurt(dt, on_floor)
		"block": _st_block(dt)
		"stagger": _st_stagger(dt)
		"air": _st_air(dt, on_floor)
		"down": _st_down(dt)
		"getup": _st_getup(dt)
		"grabbed": _st_grabbed()
		"taunt":
			hvel = hvel.move_toward(Vector3.ZERO, 20 * dt)
			velocity.y = -2.0
			if f >= 70:
				_to_idle()
		"splat": _st_splat(dt)
	if state != "grabbed":
		velocity.x = hvel.x
		velocity.z = hvel.z
		var pre := hvel
		last_vy = velocity.y
		move_and_slide()
		_check_wall(pre)
		hvel.x = velocity.x
		hvel.z = velocity.z
	_separate()
	if rag.active:
		if rag.pinned:
			rag.pin(global_position + Vector3.UP * 0.95, dt)
		elif state == "down":
			# couché : la capsule suit le corps (zone de frappe au sol = là où il est vraiment)
			var pp := rag.pelvis_pos()
			global_position.x = pp.x
			global_position.z = pp.z
			var hd := rag.head_pos() - pp
			hd.y = 0
			if hd.length() > 0.1:
				facing = -hd.normalized()
	rig.rotation.y = atan2(facing.x, facing.z)
	lean_v = lean_v.lerp(lean_target, 1.0 - exp(-18.0 * dt))
	lean_target = lean_target.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * dt))
	rig.lean = lean_v
	rig.tick(dt)
	if global_position.y < -20:
		reset_at(home + Vector3.UP, facing)
	if has_token and not state in ["windup", "strike", "recover", "idle", "walk"]:
		_drop_token()


func _update_bar() -> void:
	var k := clampf(hp / HP_MAX, 0, 1)
	bar_fill.scale.x = maxf(k, 0.001)
	bar_fill.position.x = -0.43 * (1.0 - k)
	bar.visible = last_hit_t < 4.0 or mode == "attack"


func _go(s: String) -> void:
	state = s
	f = 0


func _to_idle() -> void:
	_go("idle")
	rig.play("cmu/guard_idle" if mode != "passive" else "idle", 0.2)


func _hero() -> Node:
	return game.hero


func _face(dir: Vector3, dt: float, rate := 10.0) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	var a := facing.signed_angle_to(dir.normalized(), Vector3.UP)
	facing = facing.rotated(Vector3.UP, clampf(a, -rate * dt, rate * dt)).normalized()


## Ne pas se chevaucher : petite poussée entre persos (le héros est poussé par game).
func _separate() -> void:
	for o in game.enemies:
		if o == self:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0
		var l := d.length()
		if l < RADIUS * 2.0 and l > 0.001 and absf(global_position.y - o.global_position.y) < 1.2:
			global_position += d / l * (RADIUS * 2.0 - l) * 0.5


# ------------------------------------------------------------------ IA

func _st_idle(dt: float, on_floor: bool) -> void:
	velocity.y = -2.0 if on_floor else velocity.y - GRAV * dt
	var h := _hero()
	var to: Vector3 = h.global_position - global_position
	to.y = 0
	var dist := to.length()
	if mode == "passive" or mode == "guard":
		# revient doucement à sa place, face au héros
		var back := home - global_position
		back.y = 0
		if back.length() > 0.6 and last_hit_t > 1.5:
			hvel = hvel.move_toward(back.normalized() * 2.5, 20 * dt)
			_face(back, dt)
			rig.play("walk", 0.2, 1.4, 0.0, false)
		else:
			hvel = hvel.move_toward(Vector3.ZERO, 25 * dt)
			if dist < 8.0:
				_face(to, dt, 6.0)
			rig.play("cmu/guard_idle" if mode == "guard" else "idle", 0.25, 1.0, 0.0, false)
		return
	# mode attaque : approche, tourne autour, frappe quand il a le jeton d'attaque
	_face(to, dt, 9.0)
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_t = randf_range(0.8, 2.0)
		strafe_dir = -strafe_dir if randf() < 0.5 else strafe_dir
	var want := Vector3.ZERO
	var side := to.normalized().cross(Vector3.UP) * strafe_dir
	if dist > 3.2:
		want = to.normalized() * 3.6 + side * 0.8
	elif dist < 1.2:
		want = -to.normalized() * 2.0
	else:
		want = side * 1.6
	if not has_token and dist > 2.5 and dist < 6.0 and randf() < 0.004:
		# provocation de temps en temps (Mixamo « Boxing Taunt »)
		_go("taunt")
		rig.play("mx/enemy__boxing_taunt", 0.15, 1.3)
		return
	if atk_cool <= 0.0 and dist < 4.5 and game.take_token(self):
		has_token = true
		var r := randf()
		var kind := "light" if r < 0.4 else ("kick" if r < 0.65 else ("heavy" if r < 0.85 else "round"))
		if dist > 2.2 and not ATTACKS[kind].heavy:
			want = to.normalized() * 4.0
		else:
			_start_attack(kind)
			return
	hvel = hvel.move_toward(want, 18 * dt)
	var sp := hvel.length()
	if sp < 0.4:
		rig.play("cmu/guard_idle", 0.25, 1.0, 0.0, false)
	else:
		rig.play("walk", 0.2, clampf(sp / 1.5, 0.8, 1.7), 0.0, false)


func _start_attack(kind: String) -> void:
	atk = ATTACKS[kind].duplicate()
	atk.kind = kind
	_go("windup")
	var hit_t := float(atk.hit)
	rig.play(atk.anim, 0.1, (hit_t - float(atk.from)) / (int(atk.windup) / 60.0), float(atk.from))
	game.sfx.play("warn", global_position, 0.4)


func _st_attack(dt: float, on_floor: bool) -> void:
	velocity.y = -2.0 if on_floor else velocity.y - GRAV * dt
	var h := _hero()
	var to: Vector3 = h.global_position - global_position
	to.y = 0
	match state:
		"windup":
			# prévient : flash de couleur qui monte, se tourne vers le héros jusqu'aux dernières images
			var k := float(f) / int(atk.windup)
			rig.flash(0.05, atk.flash * (0.4 + 0.6 * k))
			if f < int(atk.windup) - 8:
				_face(to, dt, 8.0)
			hvel = hvel.move_toward(Vector3.ZERO, 30 * dt)
			if f >= int(atk.windup):
				_go("strike")
				rig.set_speed((float(atk.end) - float(atk.hit)) / ((int(atk.active) + int(atk.recovery)) / 60.0))
		"strike":
			if atk.has("lunge") and f <= int(atk.active):
				hvel = facing * float(atk.lunge) / (int(atk.active) / 60.0) * 0.5
			else:
				hvel = hvel.move_toward(Vector3.ZERO, 30 * dt)
			if not atk.get("done", false):
				var d: Vector3 = h.global_position - (global_position + facing * float(atk.reach) * 0.55)
				var ok := Vector2(d.x, d.z).length() < float(atk.reach) * 0.6 + 0.4 and absf(d.y) < 1.3
				if ok:
					atk.done = true
					var heavy := bool(atk.heavy)
					var res: String = h.receive(self, float(atk.dmg), facing * float(atk.kb), heavy)
					game.enemy_hit_result(self, res, heavy)
					if res == "parry":
						return
			if f >= int(atk.active):
				_go("recover")
		"recover":
			hvel = hvel.move_toward(Vector3.ZERO, 30 * dt)
			if f >= int(atk.recovery):
				atk_cool = randf_range(1.0, 2.2)
				_drop_token()
				_to_idle()


## Frames avant que son coup touche (pour l'esquive parfaite), ou -1.
func threat_frames() -> int:
	if state == "windup":
		return int(atk.windup) - f
	if state == "strike" and not atk.get("done", false):
		return 0
	return -1


func threat_reach() -> float:
	return float(atk.get("reach", 1.5)) + 0.6


func _drop_token() -> void:
	if has_token:
		has_token = false
		game.give_token(self)


# ------------------------------------------------------------------ encaisser

func hittable() -> bool:
	return not ko or state != "getup"


func targetable() -> bool:
	return state != "grabbed" and not (state == "getup" and f < 10)


func grabbable() -> bool:
	return state in ["idle", "walk", "hurt", "windup", "recover", "block", "stagger"] and is_on_floor()


func capsule_hit(c: Vector3, r: float) -> bool:
	if state == "down" or (state == "getup" and f < 20):
		# couché : capsule à plat
		var a := global_position + Vector3.UP * 0.2 - facing * 0.8
		var b := global_position + Vector3.UP * 0.2 + facing * 0.3
		return Geometry3D.get_closest_point_to_segment(c, a, b).distance_to(c) < r + RADIUS
	var a2 := global_position + Vector3.UP * RADIUS
	var b2 := global_position + Vector3.UP * (HEIGHT - RADIUS)
	return Geometry3D.get_closest_point_to_segment(c, a2, b2).distance_to(c) < r + RADIUS


## Reçoit un coup. Retourne "hit", "counter", "block", "none".
func take_hit(attacker: Node, m: Dictionary, dir: Vector3) -> String:
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else -facing
	var effect: String = m.get("effect", "")
	var lying := state == "down" or (state == "getup" and f < 20)
	if lying and not (m.get("low", false) or effect == "spike" or effect == "launch"):
		return "none"
	if state == "getup" and f >= 20:
		return "none"   # relevé invulnérable (pas de piège au sol)
	# garde
	var front := facing.dot(-dir) > 0.25
	var guarding := (mode == "guard" and state in ["idle", "walk", "block"]) or state == "block"
	if guarding and front and not lying:
		if m.get("guard_break", false):
			_guard_break(dir)
			game.hit_fx(self, attacker, m, "break")
			return "hit"
		_go("block")
		stun = 14
		hvel = dir * 3.0
		hitstop = maxi(int(m.get("hitstop", 4)) / 2, 3)
		rig.play("block", 0.03, 2.0, 0.15)
		rig.freeze(hitstop / 60.0)
		rig.shake(0.1, dir)
		game.hit_fx(self, attacker, m, "block")
		return "block"
	var counter: bool = state == "windup" or (state == "strike" and not atk.get("done", false))
	var res := "counter" if counter else "hit"
	if has_token:
		_drop_token()
	last_hit_t = 0.0
	hp -= float(m.get("dmg", 5))
	var stun_f := int(m.get("stun", 20))
	if counter:
		stun_f = int(stun_f * 1.5)
	hitstop = int(m.get("hitstop", 5)) + (6 if counter else 0)
	rig.freeze(hitstop / 60.0)
	rig.flash(0.1, Color(1, 1, 1) if not m.get("crit", false) else Color(1, 0.85, 0.3))
	var kb: Array = m.get("kb", [2.0, 0.0])
	var airborne := not is_on_floor() or state == "air"
	if hp <= 0.0 and not ko:
		ko = true
		effect = "knockdown"
		kb = [maxf(float(kb[0]), 8.0), maxf(float(kb[1]), 4.5)]
	# en l'air : on reste en l'air (jonglage) tant qu'on frappe
	if airborne and effect in ["", "juggle", "stagger"]:
		effect = "juggle"
	match effect:
		"launch", "juggle", "knockdown", "spike":
			_launch(dir, kb, effect, stun_f)
		"stagger":
			_go("hurt")
			stun = stun_f
			hvel = dir * float(kb[0])
			rig.play(_pick_hit_anim(dir, {"dmg": 14, "box": m.get("box", [0, 1.3])}), 0.02, 1.1, 0.05)
			lean_target = Vector3(-35, 0, 0)
		_:
			_go("hurt")
			stun = stun_f
			hvel = dir * float(kb[0])
			rig.play(_pick_hit_anim(dir, m), 0.03, 1.5, 0.08)
			lean_target = Vector3(-14, randf_range(-8, 8), randf_range(-6, 6))
	facing = -dir if not effect in ["juggle"] else facing
	rig.shake(0.15, dir)
	# réaction physique partielle (buste, tête, bras) par-dessus l'animation, dans le sens du coup
	if ragdoll_on and state in ["hurt"] and not rag.active:
		var pw := clampf(float(m.get("dmg", 5)) / 14.0, 0.2, 1.0)
		rag.react(dir * (2.5 + 3.5 * pw) + Vector3.UP * 0.6, global_position + Vector3.UP * float((m.get("box", [0, 1.3]) as Array)[1]), pw)
	game.hit_fx(self, attacker, m, res)
	return res


func _pick_hit_anim(dir: Vector3, m: Dictionary) -> String:
	var from := -dir      # d'où vient le coup, vu du mannequin
	var fw := facing.dot(from)
	var rt := facing.cross(Vector3.UP).dot(from)
	var big := float(m.get("dmg", 5)) >= 8.0
	var high := float((m.get("box", [0, 1.3]) as Array)[1]) >= 1.2
	var key := ""
	if fw > 0.45:
		key = ("front_high" if high else "front_low") + ("_big" if big else "")
	elif fw < -0.45:
		key = "back_big" if big else "back"
	else:
		key = "right" if rt > 0 else "left"
	var pool: Array = HIT_ANIMS[key].filter(func(a): return a != last_hit_anim and rig.has(a))
	if pool.is_empty():
		pool = HIT_ANIMS[key].filter(func(a): return rig.has(a))
	if pool.is_empty():
		return "hit_chest"
	last_hit_anim = pool[randi() % pool.size()]
	return last_hit_anim


func _launch(dir: Vector3, kb: Array, effect: String, stun_f: int) -> void:
	var was_air := state == "air"
	_go("air")
	stun = stun_f
	down_from_air = true
	if effect == "juggle" or (was_air and effect == "launch"):
		juggle += 1
	elif not was_air:
		juggle = 0
	var decay := pow(0.88, juggle)     # plus on jongle, moins ça remonte (pas de combo infini)
	hvel = dir * float(kb[0])
	velocity.y = float(kb[1]) * (decay if float(kb[1]) > 0 else 1.0)
	if effect == "spike":
		velocity.y = float(kb[1])
	rig.play("knockback", 0.03, 1.0, 0.06)
	atk = {}
	_rag_hit(Vector3(hvel.x, velocity.y, hvel.z))


## Ragdoll visuel : il part (ou reprend un coup) dans le sens du coup ; le bassin restera épinglé à la capsule.
func _rag_hit(vel: Vector3) -> void:
	if not ragdoll_on:
		return
	if rag.active:
		rag.pinned = true
		rag.kick(vel * 0.6, global_position + Vector3.UP * 1.2)
	else:
		rag.start(Vector3(vel.x, vel.y * 0.5, vel.z) * 0.7, true)


func _guard_break(dir: Vector3) -> void:
	_go("stagger")
	stun = 70
	hvel = dir * 4.0
	hitstop = 12
	rig.freeze(0.2)
	rig.play("mx/hit__rocked_uppercut", 0.03, 1.3, 0.1)
	game.sfx.play("break", global_position, 0.9)
	game.popup(global_position + Vector3.UP * 2.2, "GARDE BRISÉE", Color(1, 0.8, 0.2))


## Parade du héros : il titube longtemps, riposte garantie.
func parried() -> void:
	_drop_token()
	_go("stagger")
	stun = 75
	hvel = facing * -3.5
	rig.play("mx/hit__rocked_uppercut", 0.03, 1.2, 0.1)
	atk = {}


func _st_hurt(dt: float, on_floor: bool) -> void:
	velocity.y = -2.0 if on_floor else velocity.y - GRAV * dt
	hvel = hvel.move_toward(Vector3.ZERO, 22 * dt)
	if not on_floor:
		_go("air")
		return
	if f >= stun:
		_to_idle()


func _st_block(dt: float) -> void:
	hvel = hvel.move_toward(Vector3.ZERO, 25 * dt)
	velocity.y = -2.0
	if f >= stun:
		_to_idle()


func _st_stagger(dt: float) -> void:
	hvel = hvel.move_toward(Vector3.ZERO, 12 * dt)
	velocity.y = -2.0
	if f % 10 == 0:
		lean_target = Vector3(-12, 0, 14 if (f / 10) % 2 == 0 else -14)
	if f >= stun:
		_to_idle()


func _st_air(dt: float, on_floor: bool) -> void:
	var g := JUGGLE_GRAV * (1.0 + 0.12 * juggle)
	velocity.y -= g * dt
	velocity.y = maxf(velocity.y, -32.0)
	hvel = hvel.move_toward(Vector3.ZERO, 2.0 * dt)
	# pose : bascule en arrière au sommet
	if rig.pos() > 0.28 and velocity.y > -6.0:
		rig.set_speed(0.0)
	elif velocity.y <= -6.0:
		rig.set_speed(1.0)
	if thrown_by:
		_bowl()
	if on_floor and velocity.y <= 0.0 and f > 2:
		if minf(velocity.y, last_vy) < -14.0 and juggle < 8:
			# rebond au sol (écrasé)
			velocity.y = 5.5
			game.fx.dust(global_position, 1.2)
			game.shake(0.25)
			game.sfx.play("land", global_position, 0.9)
			juggle += 2
			if slammed_by:
				# éclaté au sol par la chope : gros impact, il rebondit haut (jonglable)
				velocity.y = Moves.GRAB.slam_bounce
				juggle = 0
				stun = 60
				hitstop = 10
				rig.freeze(10 / 60.0)
				game.fx.shockwave(global_position + Vector3.UP * 0.05, 2.4)
				game.fx.dust(global_position, 1.8)
				game.shake(0.6)
				game.cam.punch(0.9)
				game.sfx.play("big", global_position, 1.0)
				game.popup(global_position + Vector3.UP * 2.0, "ÉCLATÉ !", Color(1, 0.7, 0.3))
				game.popup(global_position + Vector3.UP * 1.4, str(int(Moves.GRAB.slam_dmg)), Color.WHITE)
				hp -= float(Moves.GRAB.slam_dmg)
				last_hit_t = 0.0
				if is_instance_valid(slammed_by):
					slammed_by.slam_landed(self)
				slammed_by = null
				if rag.active:
					rag.kick(Vector3.UP * 6.0, global_position + Vector3.UP * 0.9)
			return
		thrown_by = null
		_go("down")
		hvel *= 0.3
		if rag.active:
			rag.pinned = false   # il s'écrase librement
			rag.damp(0.4)
		else:
			rig.play("knockback", 0.08, 1.4, 0.42)
		game.fx.dust(global_position, 1.0)
		game.sfx.play("thud", global_position, 0.7)


func _st_down(dt: float) -> void:
	hvel = hvel.move_toward(Vector3.ZERO, 18 * dt)
	velocity.y = -2.0 if is_on_floor() else velocity.y - GRAV * dt
	var wait := 50 if not ko else 90
	if f >= wait:
		_go("getup")
		juggle = 0
		if rag.active:
			# relevé depuis la pose du ragdoll : sur le dos = LayToIdle (Quaternius), à plat ventre = capture CMU 139_16
			var fit := rig.getup_fit(rag, "getup", 0.0, "cmu/getup_front", 0.0)
			facing = fit.facing
			global_position = Vector3(fit.pos.x, global_position.y, fit.pos.z)
			rig.rotation.y = atan2(facing.x, facing.z)
			rig.play(fit.anim, 0.0, 1.6 if fit.up else 1.5, fit.from)
			rag.blend_out(0.22)
		else:
			rig.play("getup", 0.15, 2.0, 0.55)
		if ko:
			hp = HP_MAX
			ko = false


func _st_getup(dt: float) -> void:
	hvel = hvel.move_toward(Vector3.ZERO, 18 * dt)
	velocity.y = -2.0
	if f >= 56:
		_to_idle()


func _st_splat(dt: float) -> void:
	hvel = Vector3.ZERO
	velocity.y = 0.0 if f < 24 else velocity.y - GRAV * dt
	if f >= 24 and (is_on_floor() or f > 60):
		_go("down")
		if rag.active:
			rag.pinned = false
		else:
			rig.play("knockback", 0.1, 1.2, 0.42)


## Projeté fort contre un mur : il s'y écrase (wall splat), puis glisse au sol.
func _check_wall(pre: Vector3) -> void:
	if state != "air" or Vector2(pre.x, pre.z).length() < 7.0:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) < 0.5 and n.dot(-pre.normalized()) > 0.5:
			_go("splat")
			hitstop = 8
			rig.freeze(0.14)
			facing = n
			lean_target = Vector3(25, 0, 0)
			global_position += n * 0.05
			game.fx.shockwave(global_position + Vector3.UP * 1.0 - n * 0.3, 1.0, n)
			game.shake(0.4)
			game.sfx.play("big", global_position, 0.9)
			game.popup(global_position + Vector3.UP * 2.2, "MUR !", Color(1, 0.9, 0.5))
			hp -= 6.0
			if rag.active:
				rag.kick(-n * 4.0, global_position + Vector3.UP * 1.0)
			return


# ------------------------------------------------------------------ chope

func grab_by(h: Node) -> void:
	_drop_token()
	grabbed_by = h
	_go("grabbed")
	rag.stop()
	rig.play("mx/hit__punch_body", 0.05, 0.0, 0.35)
	lean_target = Vector3(-20, 0, 0)
	atk = {}


## Tenu : il se débat de plus en plus (le héros le place chaque image).
func _st_grabbed() -> void:
	velocity = Vector3.ZERO
	hvel = Vector3.ZERO
	var k := clampf(float(f) / Moves.GRAB.hold_max, 0.0, 1.0)
	var per := int(lerpf(26, 9, k))
	if f % per == 0:
		lean_target = Vector3(-20 + randf_range(-10, 10) * (0.5 + k), randf_range(-25, 25) * (0.4 + k), randf_range(-14, 14) * (0.4 + k))
		rig.shake(0.08, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized())


func pummeled(attacker: Node, dmg: float) -> void:
	hp -= dmg
	last_hit_t = 0.0
	hitstop = 4
	rig.freeze(4 / 60.0)
	rig.flash(0.08)
	lean_target = Vector3(-35, 0, 0)
	game.popup(global_position + Vector3.UP * 2.0, str(int(dmg)), Color.WHITE)


## Tenu trop longtemps : il se dégage en repoussant le héros.
func escape_grab(hero_facing: Vector3) -> void:
	grabbed_by = null
	global_position += hero_facing * 0.3
	_go("hurt")
	stun = 10
	hvel = hero_facing * 3.0
	rig.play("shield_break", 0.05, 1.6)
	game.sfx.play("block", global_position, 0.6)


## Chope + Y : soulevé puis écrasé au sol devant le héros (le rebond est géré dans _st_air).
func slam_by(h: Node, at: Vector3) -> void:
	grabbed_by = null
	slammed_by = h
	thrown_by = null
	global_position = Vector3(at.x, global_position.y, at.z)
	_go("air")
	juggle = 0
	hvel = Vector3.ZERO
	velocity.y = -26.0
	stun = 60
	rig.play("knockback", 0.03, 1.2, 0.06)
	rig.flash(0.1)
	lean_target = Vector3(50, 0, 0)
	_rag_hit(Vector3(0, -12, 0))


func release_grab(v: Vector3) -> void:
	grabbed_by = null
	if v.length() < 0.1:
		_to_idle()
		return
	thrown_by = game.hero
	hp -= Moves.GRAB.dmg
	last_hit_t = 0.0
	_go("air")
	juggle = 0
	hvel = Vector3(v.x, 0, v.z)
	velocity.y = v.y
	facing = -Vector3(v.x, 0, v.z).normalized()
	rig.play("knockback", 0.03, 1.0, 0.06)
	rig.flash(0.1)
	_rag_hit(v)


## Projeté : il renverse les autres sbires qu'il percute (boule de bowling).
func _bowl() -> void:
	for o in game.enemies:
		if o == self or o.state in ["air", "down", "grabbed"]:
			continue
		var d: Vector3 = o.global_position - global_position
		if d.length() < RADIUS * 2.6:
			var dir := Vector3(hvel.x, 0, hvel.z).normalized()
			o.take_hit(game.hero, {"dmg": 8, "stun": 30, "kb": [7.0, 5.0], "effect": "knockdown", "hitstop": 7, "shake": 0.3, "sfx": "heavy"}, dir)
			hvel *= 0.6

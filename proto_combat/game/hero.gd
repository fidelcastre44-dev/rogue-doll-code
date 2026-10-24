class_name Hero
extends CharacterBody3D
## Le héros. Toute la logique est en images (60 / s), à la manière d'un jeu de combat ; l'animation ne fait que suivre.
##
## États : move (au sol, déplacement libre), air (en l'air), attack, dodge, airdash, guard, grab, hurt, down (à terre), charge.
## Principes « pro » :
##  - tampon d'entrées (Inputs.BUFFER) : un appui un peu en avance part à la première image possible ;
##  - annulations : enchaînement ouvert dès `chain_from`, esquive qui coupe selon le coup (dodge = always / active / hit) ;
##  - figé à l'impact (hitstop) sur l'attaquant ET la cible, secousse caméra dosée par le coup ;
##  - accélération / freinage très vifs, demi-tour quasi instantané ; élan des coups calculé (pas de root motion) ;
##  - aide à la visée réglable (0 = aucune) : oriente le coup vers l'ennemi le plus pertinent dans un cône et règle l'élan ;
##  - rien de spammable : esquives limitées (2 puis petite recharge), les finisseurs ont une vraie récupération.

signal hit_landed(target, move_id, result)

const RUN := 6.8              # m/s
const SPRINT := 9.8
const WALK := 2.6             # stick à moitié
const GUARD_WALK := 2.2
const ACCEL := 75.0           # m/s²
const DECEL := 95.0
const AIR_ACCEL := 32.0
const TURN := 40.0            # rad/s (demi-tour en ~5 images)
const JUMP_V := 8.2
const GRAV_UP := 24.0
const GRAV_DOWN := 40.0
const COYOTE := 6             # images
const DODGE_F := 24           # durée de la roulade (images)
const DODGE_DIST := 4.6
const DODGE_IFRAMES := Vector2i(1, 15)
const DODGE_ATTACK_F := 11    # dès cette image, un X / Y bufferisé part en attaque de roulade
const DODGE_CHAIN := 2        # esquives d'affilée avant la recharge
const DODGE_COOL := 0.4       # s
const AIRDASH_F := 14
const AIRDASH_DIST := 3.4
const PARRY_F := 8            # parade : L1 dans les 8 premières images avant le coup
const RIPOSTE_WIN := 0.7      # s pour riposter (X) après une parade
const CHARGE_MIN := 0.2       # s de maintien de Y pour charger
const CHARGE_MAX := 1.0
const LAND_LAG := 3
const HEAVY_LAND_LAG := 9

var game: Node                 # main.gd
var rig: Rig
var look := "male"
var state := "move"
var f := 0                     # image courante dans l'état
var facing := Vector3(0, 0, -1)
var hvel := Vector3.ZERO       # vitesse horizontale
var coyote := 0
var hitstop := 0               # images de figé
var move_id := ""
var mv: Dictionary = {}
var hit_list := []
var has_hit := false
var lunge_dir := Vector3.ZERO
var lunge_dist := 0.0
var lunge_frames := 1
var chain_req := ""
var dodge_dir := Vector3.ZERO
var dodges := 0
var dodge_cool := 0.0
var air_dash_used := false
var air_attacks := 0
var guard_f := 0
var riposte_t := 0.0
var perfect_t := 0.0           # esquive parfaite : bonus de la prochaine attaque
var charge_t := 0.0
var grabbed: Node = null
var stun := 0
var down_f := 0
var invuln := 0
var land_lag := 0
var sprinting := false
var in_combat_t := 0.0
var fall_peak := 0.0
var assist := 0.65             # aide à la visée (menu)
var aim_target: Node = null
var last_ground_y := 0.0
var hp := 100.0
var combo := 0
var combo_t := 0.0
var hurt_count := 0
var guard_cool := 0.0          # parade pas spammable : re-garder trop vite = pas de fenêtre de parade


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(48)
	floor_snap_length = 0.35
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	set_look(look)


func set_look(l: String) -> void:
	look = l
	if rig:
		rig.queue_free()
	rig = Rig.new()
	add_child(rig)
	rig.setup(l)
	rig.play("cmu/guard_idle", 0.0)
	_face_rig()


func _face_rig() -> void:
	rig.rotation.y = atan2(facing.x, facing.z)


# ------------------------------------------------------------------ boucle

func _physics_process(dt: float) -> void:
	if hitstop > 0:
		hitstop -= 1
		rig.tick(dt)
		return
	if dodge_cool > 0.0:
		dodge_cool -= dt
		if dodge_cool <= 0.0:
			dodges = 0
	riposte_t = maxf(riposte_t - dt, 0.0)
	guard_cool = maxf(guard_cool - dt, 0.0)
	perfect_t = maxf(perfect_t - dt, 0.0)
	in_combat_t = maxf(in_combat_t - dt, 0.0)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	if invuln > 0:
		invuln -= 1
	f += 1
	var on_floor := is_on_floor()
	if on_floor:
		coyote = COYOTE
		air_dash_used = false
		air_attacks = 0
		last_ground_y = global_position.y
	elif coyote > 0:
		coyote -= 1
	match state:
		"move": _st_move(dt, on_floor)
		"air": _st_air(dt, on_floor)
		"attack": _st_attack(dt, on_floor)
		"charge": _st_charge(dt)
		"dodge": _st_dodge(dt)
		"airdash": _st_airdash(dt)
		"guard": _st_guard(dt)
		"grab": _st_grab(dt)
		"hurt": _st_hurt(dt)
		"down": _st_down(dt)
	velocity.x = hvel.x
	velocity.z = hvel.z
	move_and_slide()
	hvel.x = velocity.x
	hvel.z = velocity.z
	_face_rig()
	rig.tick(dt)
	if global_position.y < -20.0:
		game.respawn_hero()


func stick_world() -> Vector3:
	var s := Inputs.stick()
	if s.length() < 0.05:
		return Vector3.ZERO
	var fw: Vector3 = game.cam_forward()
	var rt: Vector3 = game.cam_right()
	var d := rt * s.x - fw * s.y
	return d.normalized() * minf(s.length(), 1.0)


func _go(st: String) -> void:
	state = st
	f = 0


func _gravity(dt: float, mult := 1.0) -> void:
	# montée : gravité douce si A est tenu (ou au tout début du saut : un appui bref donne quand même un vrai saut)
	var g := GRAV_UP if velocity.y > 0.0 and (Inputs.held("jump") or (state == "air" and f < 12)) else GRAV_DOWN
	velocity.y -= g * mult * dt
	velocity.y = maxf(velocity.y, -30.0)


func _turn_to(dir: Vector3, dt: float, rate := TURN) -> void:
	if dir.length() < 0.01:
		return
	var a := facing.signed_angle_to(dir.normalized(), Vector3.UP)
	var step := clampf(a, -rate * dt, rate * dt)
	facing = facing.rotated(Vector3.UP, step).normalized()


# ------------------------------------------------------------------ déplacement

func _st_move(dt: float, on_floor: bool) -> void:
	if land_lag > 0:
		land_lag -= 1
		hvel = hvel.move_toward(Vector3.ZERO, DECEL * dt)
		velocity.y = -1.0
		return
	if not on_floor and coyote <= 0:
		_go("air")
		rig.play("ninja_loop", 0.15)
		return
	var d := stick_world()
	sprinting = (Inputs.held("sprint") or Inputs.sprint_tap or (sprinting and d.length() > 0.5)) and d.length() > 0.5
	var top := RUN if d.length() > 0.55 else WALK
	if sprinting:
		top = SPRINT
	var target := d.normalized() * top if d.length() > 0.05 else Vector3.ZERO
	var rate := ACCEL if target.length() > hvel.length() else DECEL
	# demi-tour net : on garde la vitesse acquise, seulement réorientée
	if target.length() > 0.1 and hvel.length() > 0.5 and hvel.normalized().dot(target.normalized()) < -0.2:
		hvel = hvel.normalized().slerp(target.normalized(), 0.6) * hvel.length() * 0.5
	hvel = hvel.move_toward(target, rate * dt)
	_turn_to(d, dt)
	velocity.y = -2.0 if on_floor else velocity.y - GRAV_DOWN * dt
	_loco_anim()
	_neutral_actions(on_floor)


## Actions possibles depuis le neutre (au sol). Ordre = priorités.
func _neutral_actions(on_floor: bool) -> bool:
	if Inputs.buffered("dodge"):
		return _start_dodge()
	if Inputs.buffered("jump"):
		_jump()
		return true
	if Inputs.held("guard"):
		_start_guard()
		return true
	if Inputs.buffered("grab"):
		_start_grab()
		return true
	if Inputs.buffered("attack"):
		if riposte_t > 0.0:
			_start_attack("riposte")
		elif sprinting:
			_start_attack("slide")
		else:
			_start_attack("jab")
		return true
	if Inputs.buffered("heavy", false, CHARGE_MIN + 0.1):
		if sprinting:
			Inputs.clear("heavy")
			_start_attack("flying_hook")
			return true
		if riposte_t > 0.0:
			Inputs.clear("heavy")
			_start_attack("riposte")
			return true
		# Y : on attend de savoir si c'est un appui court (coup de pied) ou maintenu (charge)
		if not Inputs.held("heavy") or Inputs.held_time("heavy") >= CHARGE_MIN:
			Inputs.clear("heavy")
			if Inputs.held("heavy"):
				_start_charge()
			else:
				_start_attack("push_kick")
			return true
	return false


func _loco_anim() -> void:
	var sp := Vector2(hvel.x, hvel.z).length()
	if sp < 0.35:
		var idle := "cmu/guard_idle" if in_combat_t > 0.0 else "idle"
		rig.play(idle, 0.18, 1.0, 0.0, false)
	elif sp < 3.2:
		rig.play("walk", 0.15, clampf(sp / 1.6, 0.8, 1.8), 0.0, false)
	elif sp < 8.0:
		rig.play("jog", 0.12, clampf(sp / 4.6, 0.9, 1.6), 0.0, false)
	else:
		rig.play("sprint", 0.12, clampf(sp / 7.2, 1.0, 1.6), 0.0, false)


func _jump() -> void:
	velocity.y = JUMP_V
	coyote = 0
	land_lag = 0
	_go("air")
	rig.play("ninja_start", 0.05, 1.6, 0.22)
	game.fx.dust(global_position, 0.6)
	game.sfx.play("jump", global_position, 0.6)


# ------------------------------------------------------------------ en l'air

func _st_air(dt: float, on_floor: bool) -> void:
	if on_floor and velocity.y <= 0.0:
		_land()
		return
	var d := stick_world()
	var top := maxf(RUN, Vector2(hvel.x, hvel.z).length())
	hvel = hvel.move_toward(d * top, AIR_ACCEL * dt)
	_turn_to(d, dt, TURN * 0.6)
	_gravity(dt)
	fall_peak = maxf(fall_peak, global_position.y)
	if f > 12 and rig.current == "ninja_start":
		rig.play("ninja_loop", 0.2)
	if coyote > 0 and Inputs.buffered("jump"):
		_jump()
		return
	if Inputs.buffered("dodge") and not air_dash_used:
		_start_airdash()
		return
	if Inputs.buffered("attack") and air_attacks < 4:
		_start_attack("air_jab")
		return
	if Inputs.buffered("heavy"):
		_start_attack("air_spike")
		return
	if Inputs.buffered("grab"):
		pass


func _land() -> void:
	var drop := fall_peak - global_position.y
	fall_peak = global_position.y
	_go("move")
	land_lag = HEAVY_LAND_LAG if drop > 3.5 else LAND_LAG
	if hvel.length() > 3.0:
		land_lag = 1
	rig.play("ninja_land", 0.06, 1.8, 0.12)
	game.fx.dust(global_position, 0.8 if drop < 3.5 else 1.4)
	game.sfx.play("land", global_position, 0.5)
	if drop > 3.5:
		game.shake(0.25)


# ------------------------------------------------------------------ attaques

func _start_attack(id: String) -> void:
	move_id = id
	mv = Moves.M[id]
	hit_list = []
	has_hit = false
	chain_req = ""
	sprinting = false
	in_combat_t = 4.0
	_go("attack")
	if mv.get("air", false):
		air_attacks += 1
	# orientation : stick, sinon devant ; aide à la visée vers l'ennemi le plus pertinent
	var want := stick_world()
	if want.length() < 0.2:
		want = facing
	want = want.normalized()
	aim_target = _pick_target(want, float(mv.box[0]) + float(mv.lunge) + 1.6)
	var dist := float(mv.lunge)
	if aim_target and assist > 0.0:
		var to: Vector3 = aim_target.global_position - global_position
		to.y = 0
		var ang := want.angle_to(to.normalized())
		want = want.slerp(to.normalized(), clampf(assist * 1.4, 0.0, 1.0)).normalized()
		# l'élan s'arrête au contact (ne traverse pas, n'est pas trop court)
		var need := to.length() - float(mv.box[0]) * 0.85
		dist = lerpf(dist, clampf(need, 0.0, float(mv.lunge) * 1.6 + 0.6), assist)
	facing = want
	lunge_dir = want
	lunge_dist = maxf(dist, 0.0)
	lunge_frames = int(mv.startup) + int(mv.active)
	hvel = hvel * 0.25 if not mv.get("air", false) else hvel * 0.5
	_anim_phase(0)
	game.sfx.play("whoosh_heavy" if mv.sfx in ["heavy", "big"] else "whoosh", global_position, 0.5)
	if mv.get("air", false):
		velocity.y = maxf(velocity.y, float(mv.get("hang", 0.0)))
	if mv.get("dive", false):
		velocity.y = 3.0


## Cale la vitesse de l'animation sur les images du coup : phase 0 = armé (jusqu'à l'impact), 1 = actif + récupération.
func _anim_phase(ph: int) -> void:
	var start := float(mv.from)
	var hit_t := float(mv.hit)
	var end_t := float(mv.end)
	if ph == 0:
		var dur := maxf(int(mv.startup) / 60.0, 1.0 / 60.0)
		rig.play(mv.anim, 0.04 if f == 0 else 0.0, maxf((hit_t - start) / dur, 0.05), start)
	else:
		var dur2 := (int(mv.active) + int(mv.recovery)) / 60.0
		rig.set_speed(maxf((end_t - hit_t) / dur2, 0.05))


func _st_attack(dt: float, on_floor: bool) -> void:
	var su := int(mv.startup)
	var ac := int(mv.active)
	var tot := Moves.total(mv)
	var air := bool(mv.get("air", false))
	if f == su:
		_anim_phase(1)
		var kind: String = mv.get("slash", "")
		if kind == "":
			kind = "thrust" if move_id in ["jab", "cross", "air_jab", "air_cross", "dash_punch"] else ("up" if move_id in ["launcher", "riposte"] else ("none" if move_id == "slide" else "h"))
		game.fx.slash(global_position + Vector3.UP * float(mv.box[1]), facing, kind, float(mv.box[0]) * 1.05,
			Color(1, 0.8, 0.45) if mv.sfx in ["heavy", "big"] else Color(0.85, 0.92, 1.0))
	# élan : vitesse décroissante, fort au début
	if f < lunge_frames and lunge_dist > 0.0:
		var T := lunge_frames / 60.0
		var t := f / 60.0
		var v := 2.0 * lunge_dist / T * (1.0 - t / T)
		hvel = lunge_dir * v
	else:
		hvel = hvel.move_toward(Vector3.ZERO, (DECEL if not air else AIR_ACCEL) * dt)
	# vertical
	if mv.get("dive", false):
		if f >= su:
			velocity.y = -22.0
			hvel = lunge_dir * 3.0
		else:
			velocity.y = move_toward(velocity.y, 0.0, 30 * dt)
		if f >= su and on_floor:
			_dive_land()
			return
	elif air:
		velocity.y -= GRAV_DOWN * 0.35 * dt
		if on_floor and f > 2 and f > su + ac:
			_land()
			return
	else:
		velocity.y = -2.0 if on_floor else velocity.y - GRAV_DOWN * dt
	# frappe
	if f >= su and f < su + ac:
		_check_hits()
	# enchaînements (tampon) : on retient la demande dès l'image 0, elle part à `chain_from`
	for b in mv.chain:
		if Inputs.buffered(b, false):
			chain_req = b
	var from := int(mv.get("chain_from", su))
	if chain_req != "" and f >= from and f >= su + ac:
		var nxt: String = mv.chain[chain_req]
		Inputs.clear(chain_req)
		chain_req = ""
		if air and not nxt.begins_with("air"):
			pass
		else:
			_start_attack(nxt)
			return
	# esquive qui coupe le coup
	var dc: String = mv.get("dodge", "active")
	if Inputs.buffered("dodge", false):
		var ok := dc == "always" or (dc == "active" and f >= su + ac) or (dc == "hit" and has_hit and f >= su + ac)
		if ok:
			Inputs.clear("dodge")
			if air:
				if not air_dash_used:
					_start_airdash()
					return
			else:
				_start_dodge()
				return
	# saut sur coup qui touche (lanceur)
	if mv.get("jump_cancel", false) and has_hit and f >= su + ac and Inputs.buffered("jump"):
		# saut de poursuite : il part vers l'ennemi envoyé en l'air pour arriver sous lui
		var tgt: Node = hit_list[0] if hit_list.size() else null
		_jump()
		velocity.y = JUMP_V * 1.12
		if tgt and is_instance_valid(tgt):
			var to: Vector3 = tgt.global_position - global_position
			to.y = 0
			var need := maxf(to.length() - 0.7, 0.0)
			hvel = to.normalized() * minf(need / 0.3, 9.0) if to.length() > 0.05 else Vector3.ZERO
			if to.length() > 0.05:
				facing = to.normalized()
		return
	if f >= tot:
		if air:
			_go("air")
			rig.play("ninja_loop", 0.2)
		else:
			_go("move")
			if mv.has("then"):
				rig.play(mv.then, 0.1, 1.6)
	elif f == su + ac + 2 and mv.has("then"):
		rig.play(mv.then, 0.12, 1.4)


func _dive_land() -> void:
	game.fx.shockwave(global_position, 2.2)
	game.shake(0.45)
	game.sfx.play("big", global_position, 0.8)
	# onde au sol : tout ennemi proche est fauché
	for e in game.enemies:
		if e in hit_list:
			continue
		var d: Vector3 = e.global_position - global_position
		if Vector2(d.x, d.z).length() < 2.2 and absf(d.y) < 1.0:
			var dir := Vector3(d.x, 0, d.z).normalized() if d.length() > 0.1 else facing
			var r: String = e.take_hit(self, {"dmg": 6, "stun": 30, "kb": [6.0, 6.0], "effect": "launch", "hitstop": 6, "sfx": "heavy", "shake": 0.2}, dir)
			hit_list.append(e)
			if r == "hit":
				_on_hit(e, "shock", r, 6)
	_go("move")
	land_lag = 10
	rig.play("ninja_land", 0.05, 1.4, 0.1)


func _check_hits() -> void:
	var b: Array = mv.box
	var fwd := float(b[0])
	if mv.get("sweep", false):
		fwd *= 0.7 + 0.6 * float(f - int(mv.startup)) / maxf(int(mv.active), 1)
	var c := global_position + facing * fwd + Vector3.UP * float(b[1])
	var r := float(b[2])
	if perfect_t > 0.0:
		r *= 1.2
	game.debug_box(c, r)
	for e in game.enemies:
		if e in hit_list or not e.hittable():
			continue
		if e.capsule_hit(c, r):
			hit_list.append(e)
			var dir := facing
			var m2 := mv.duplicate()
			if perfect_t > 0.0 or mv.get("crit", false):
				m2.dmg = int(m2.dmg * 1.5)
				m2.stun = int(m2.stun * 1.4)
				m2.crit = true
			var res: String = e.take_hit(self, m2, dir)
			_on_hit(e, move_id, res, int(m2.hitstop))
	if has_hit and perfect_t > 0.0:
		perfect_t = 0.0


func _on_hit(e, id: String, res: String, hs: int) -> void:
	if res == "dodged" or res == "none":
		return
	has_hit = true
	in_combat_t = 4.0
	var hs2 := hs
	if res == "block":
		hs2 = maxi(hs / 2, 3)
		hvel = -facing * 3.0
	elif res == "counter":
		hs2 = hs + 6
	hitstop = hs2
	rig.freeze(hs2 / 60.0)
	if res in ["hit", "counter", "armor"]:
		combo += 1
		combo_t = 1.2
	hit_landed.emit(e, id, res)


func _start_charge() -> void:
	_go("charge")
	charge_t = 0.0
	in_combat_t = 4.0
	var want := stick_world()
	if want.length() > 0.2:
		facing = want.normalized()
	rig.play("hook", 0.08, 0.0, 0.05)
	rig.set_speed(0.12)
	game.sfx.play("charge", global_position, 0.6)


func _st_charge(dt: float) -> void:
	charge_t += dt
	hvel = hvel.move_toward(Vector3.ZERO, DECEL * dt)
	velocity.y = -2.0
	_turn_to(stick_world(), dt, 8.0)
	if rig.pos() > 0.14:
		rig.set_speed(0.0)
	rig.flash(0.05, Color(1.0, 0.75, 0.2) * clampf(charge_t / CHARGE_MAX, 0.2, 1.0))
	if Inputs.buffered("dodge"):
		_start_dodge()
		return
	if not Inputs.held("heavy") or charge_t >= CHARGE_MAX:
		var lvl := clampf(charge_t / CHARGE_MAX, 0.0, 1.0)
		_start_attack("charged")
		var m2: Dictionary = mv.duplicate()
		m2.dmg = int(lerpf(14, 26, lvl))
		m2.kb = [lerpf(11.0, 18.0, lvl), lerpf(4.0, 6.0, lvl)]
		m2.lunge = lerpf(1.5, 3.4, lvl)
		m2.shake = lerpf(0.5, 0.85, lvl)
		mv = m2
		lunge_dist = maxf(lunge_dist, float(m2.lunge) * (0.6 if aim_target else 1.0))


# ------------------------------------------------------------------ esquive

func _start_dodge() -> bool:
	if dodges >= DODGE_CHAIN and dodge_cool > 0.0:
		return false
	dodges += 1
	dodge_cool = DODGE_COOL + 0.3
	var d := stick_world()
	dodge_dir = d.normalized() if d.length() > 0.2 else facing
	facing = dodge_dir
	sprinting = false
	_go("dodge")
	invuln = 0
	rig.play("roll", 0.03, 2.9, 0.16)
	game.sfx.play("roll", global_position, 0.5)
	game.fx.dust(global_position, 0.7)
	# esquive parfaite : un coup ennemi allait toucher
	if game.enemy_threat(self, 0.18):
		perfect_t = 1.2
		game.perfect_dodge(self)
	return true


func iframes() -> bool:
	return (state == "dodge" and f >= DODGE_IFRAMES.x and f <= DODGE_IFRAMES.y) or invuln > 0 or (state == "airdash" and f < 8)


func _st_dodge(dt: float) -> void:
	var T := DODGE_F / 60.0
	var t := f / 60.0
	# vitesse : départ franc, fin amortie (aire = DODGE_DIST)
	var v := DODGE_DIST / T * 1.6 * (1.0 - pow(t / T, 1.6))
	hvel = dodge_dir * maxf(v, 0.0)
	velocity.y = -2.0 if is_on_floor() else velocity.y - GRAV_DOWN * dt
	if f >= DODGE_ATTACK_F:
		if Inputs.buffered("attack"):
			_start_attack("dash_punch")
			return
		if Inputs.buffered("heavy"):
			_start_attack("slide")
			return
	if f >= DODGE_F - 4:
		if Inputs.buffered("dodge", false) and dodges < DODGE_CHAIN:
			Inputs.clear("dodge")
			_start_dodge()
			return
		if Inputs.buffered("jump"):
			_jump()
			return
	if f >= DODGE_F:
		_go("move")
		hvel = dodge_dir * RUN * 0.6
		if stick_world().length() > 0.5 and Inputs.held("dodge"):
			sprinting = true


func _start_airdash() -> void:
	air_dash_used = true
	var d := stick_world()
	dodge_dir = d.normalized() if d.length() > 0.2 else facing
	facing = dodge_dir
	_go("airdash")
	rig.play("dash", 0.04, 1.8, 0.05)
	game.sfx.play("roll", global_position, 0.5)


func _st_airdash(_dt: float) -> void:
	var T := AIRDASH_F / 60.0
	hvel = dodge_dir * (AIRDASH_DIST / T * 1.5 * (1.0 - float(f) / AIRDASH_F))
	velocity.y = 0.0
	if f >= 6 and Inputs.buffered("attack") and air_attacks < 4:
		_start_attack("air_jab")
		return
	if f >= 6 and Inputs.buffered("heavy"):
		_start_attack("air_spike")
		return
	if f >= AIRDASH_F:
		_go("air")
		rig.play("ninja_loop", 0.15)


# ------------------------------------------------------------------ garde / parade

func _start_guard() -> void:
	_go("guard")
	guard_f = 0 if guard_cool <= 0.0 else PARRY_F + 1
	in_combat_t = 4.0
	rig.play("cmu/guard_idle", 0.06, 1.3)
	rig.flash(0.06, Color(0.4, 0.7, 1.0))


func parrying() -> bool:
	return state == "guard" and guard_f <= PARRY_F


func _st_guard(dt: float) -> void:
	guard_f += 1
	var d := stick_world()
	hvel = hvel.move_toward(d * GUARD_WALK, ACCEL * dt)
	velocity.y = -2.0
	if not Inputs.held("guard"):
		guard_cool = 0.35
		_go("move")
		return
	if Inputs.buffered("dodge"):
		_start_dodge()
		return
	if riposte_t > 0.0 and (Inputs.buffered("attack") or Inputs.buffered("heavy")):
		_start_attack("riposte")
		return
	if Inputs.buffered("grab"):
		_start_grab()


## Appelé par un ennemi qui frappe le héros. Retourne "parry", "block", "dodged" ou "hit".
func receive(attacker, dmg: float, kb: Vector3, heavy: bool) -> String:
	if iframes() or state == "down":
		return "dodged"
	var front := facing.dot((attacker.global_position - global_position).normalized()) > 0.0
	if state == "guard" and front:
		if parrying():
			riposte_t = RIPOSTE_WIN
			game.parry(self, attacker)
			return "parry"
		hvel = kb.normalized() * 4.0
		hitstop = 5
		rig.freeze(5 / 60.0)
		rig.flash(0.08, Color(0.4, 0.7, 1.0))
		game.sfx.play("block", global_position, 0.7)
		return "block"
	if state == "charge" or (state == "attack" and mv.get("armor", false) and f < int(mv.startup)):
		rig.flash(0.08, Color(1, 0.5, 0.2))
		hp -= dmg * 0.5
		return "armor"
	hp -= dmg
	hurt_count += 1
	if hp <= 0:
		hp = 100.0
	combo = 0
	sprinting = false
	if grabbed:
		grabbed.release_grab(Vector3.ZERO)
		grabbed = null
	if heavy:
		_go("down")
		down_f = 0
		hvel = kb
		velocity.y = 4.0
		rig.play("knockback", 0.03, 1.4)
	else:
		_go("hurt")
		stun = 18
		hvel = kb
		rig.play("hit_chest", 0.02, 1.6)
		rig.shake(0.15, kb.normalized())
	rig.flash(0.1, Color(1, 0.3, 0.3))
	hitstop = 6
	rig.freeze(0.1)
	return "hit"


func _st_hurt(dt: float) -> void:
	hvel = hvel.move_toward(Vector3.ZERO, 30 * dt)
	velocity.y = -2.0 if is_on_floor() else velocity.y - GRAV_DOWN * dt
	if f >= stun:
		_go("move")
	elif f > stun - 6 and Inputs.buffered("dodge", false):
		Inputs.clear("dodge")
		_start_dodge()


func _st_down(dt: float) -> void:
	down_f += 1
	hvel = hvel.move_toward(Vector3.ZERO, 14 * dt)
	velocity.y -= GRAV_DOWN * dt if not is_on_floor() else 0.0
	if down_f == 40:
		rig.play("getup", 0.15, 2.4, 0.5)
		invuln = 40
	# relevé rapide : B ou A au sol
	if down_f > 22 and down_f < 40 and (Inputs.buffered("dodge") or Inputs.buffered("jump")):
		invuln = 20
		_start_dodge()
		return
	if down_f >= 75:
		_go("move")


# ------------------------------------------------------------------ chope

func _start_grab() -> void:
	_go("grab")
	grabbed = null
	in_combat_t = 4.0
	var want := stick_world()
	if want.length() > 0.2:
		facing = want.normalized()
	rig.play("throw", 0.05, 1.4, 0.02)
	rig.set_speed(1.0)


func _st_grab(dt: float) -> void:
	var g := Moves.GRAB
	hvel = hvel.move_toward(Vector3.ZERO, DECEL * dt)
	velocity.y = -2.0
	if grabbed == null:
		if f == int(g.startup):
			var t = _pick_target(facing, float(g.reach), 0.9)
			if t and t.grabbable():
				var to: Vector3 = t.global_position - global_position
				to.y = 0
				if to.length() < float(g.reach):
					facing = to.normalized()
					grabbed = t
					t.grab_by(self)
					f = 0
					rig.play("throw", 0.05, 0.9, 0.12)
					game.sfx.play("grab", global_position, 0.7)
					hitstop = 4
					return
		if f >= int(g.startup) + int(g.whiff):
			_go("move")
		return
	# tenu : il est dans les mains, puis lancé
	grabbed.global_position = global_position + facing * 0.75 + Vector3.UP * 0.25
	if f == int(g.hold):
		rig.set_speed(1.9)
	if f == int(g.hold) + int(g.throw_f):
		var kb: Array = g.kb
		var dir := facing
		var s2 := stick_world()
		if s2.length() > 0.5:
			dir = s2.normalized()
		grabbed.release_grab(dir * float(kb[0]) + Vector3.UP * float(kb[1]))
		_on_hit(grabbed, "throw", "hit", 8)
		game.shake(0.35)
		game.sfx.play("heavy", global_position, 0.8)
		grabbed = null
		f = 100
	if f >= 100 + int(g.recovery):
		_go("move")


# ------------------------------------------------------------------ cibles

## Ennemi le plus pertinent : dans un cône autour de `dir`, à portée ; on préfère l'aligné au proche.
func _pick_target(dir: Vector3, reach: float, cone := 1.2) -> Node:
	var best: Node = null
	var best_s := INF
	for e in game.enemies:
		if not e.targetable():
			continue
		var to: Vector3 = e.global_position - global_position
		var dy := to.y
		to.y = 0
		var dist := to.length()
		if dist > reach or absf(dy) > 2.2:
			continue
		var ang := dir.angle_to(to.normalized()) if dist > 0.05 else 0.0
		if ang > cone:
			continue
		var s := ang * 2.2 + dist * 0.35
		if s < best_s:
			best_s = s
			best = e
	return best


## Phase actuelle (affichage de la frise) : "startup", "active", "recovery" ou "".
func phase() -> String:
	if state != "attack":
		return ""
	if f < int(mv.startup):
		return "startup"
	if f < int(mv.startup) + int(mv.active):
		return "active"
	return "recovery"

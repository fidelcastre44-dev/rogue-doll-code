class_name DummyBrain
extends RefCounted
## Cerveau des mannequins : passif (sac de frappe), en garde (bloque de face, brisé par les coups lourds), attaquant
## (tourne autour du joueur, 2 attaquants à la fois au plus, coups annoncés par un flash rouge = bloquable / orange = à
## esquiver ou parer). Philosophie (Thibaud) : faciles à toucher, mais ils font mal.

const ATTACKS_LIGHT := ["e_cross", "e_lowkick"]
const ATTACKS_HEAVY := ["e_hook", "e_bigkick"]

var me: Fighter
var mode := "passive"         # passive | guard | attack
var think := 0
var token := false
var want_attack := 0
var strafe_dir := 1.0
var cooldown := 0
var telegraph := 0            # images de flash restantes avant le coup
var next_move := ""
var angle_off := 0.0


func _init(f: Fighter) -> void:
	me = f
	angle_off = 0.0
	strafe_dir = 1.0


func set_mode(m: String) -> void:
	mode = m
	me.guarding = m == "guard"
	if me.state in ["guard", "idle", "run"]:
		me.go("guard" if m == "guard" else "idle")


func note(_cmd) -> void:
	pass


func tick(cmd) -> void:
	if me.tick_hurt():
		_drop_token()
		return
	if cooldown > 0:
		cooldown -= 1
	match me.state:
		"held":
			_held()
		"attack":
			_attack()
		"guard":
			me.brake(40.0)
			if mode != "guard":
				me.go("idle")
			else:
				var h := me.world.nearest_player(me)
				if h:
					me.turn_towards((h.global_position - me.global_position), 8.0)
		_:
			match mode:
				"passive": _passive()
				"guard": me.go("guard")
				"attack": _hunt()


func _held() -> void:
	var g := me.grabbed_by
	if not is_instance_valid(g) or g.holding != me:
		me.grabbed_by = null
		me.go("idle")
		return
	me.global_position = g.global_position + g.facing * 0.95
	me.facing = -g.facing
	me.hvel = Vector3.ZERO
	me.velocity = Vector3.ZERO


func _passive() -> void:
	me.brake(40.0)
	var h := me.world.nearest_player(me)
	if h and me.state == "idle":
		me.turn_towards((h.global_position - me.global_position), 6.0)
	_separate()
	if me.state == "run":
		me.go("idle")


func _separate() -> void:
	# ne pas rester dans un autre sbire
	for o in me.world.fighters:
		if o == me or o.team != me.team or not o.targetable():
			continue
		var d := me.global_position - o.global_position
		d.y = 0
		if d.length() < 0.9:
			me.hvel += (d.normalized() if d.length() > 0.01 else Vector3(1, 0, 0)) * 0.5


func _hunt() -> void:
	var h := me.world.nearest_player(me)
	if not h:
		_passive()
		return
	var to := h.global_position - me.global_position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else me.facing
	me.turn_towards(dir, 12.0)
	think += 1
	if think % 90 == 0 and me.world.rand() < 0.3:
		strafe_dir = -strafe_dir
	var ring := Tuning.v("foe_ring")
	var want := Vector3.ZERO
	if token:
		# attaquant : va au contact puis frappe
		if dist > 1.35:
			want = dir * Tuning.v("foe_speed") * 1.3
		elif cooldown <= 0 and me.world.can_attack_now(me):
			_start_attack(dist)
	else:
		# les autres tournent autour à distance
		if dist > ring + 0.6:
			want = dir * Tuning.v("foe_speed")
		elif dist < ring - 0.5:
			want = -dir * Tuning.v("foe_speed") * 0.6
		else:
			want = dir.cross(Vector3.UP) * strafe_dir * Tuning.v("foe_speed") * 0.5
		if cooldown <= 0 and me.world.request_token(me):
			token = true
	_separate()
	me.drive(want)
	if me.state == "idle" and me.hvel.length() > 0.5:
		me.go("run")
	elif me.state == "run" and me.hvel.length() <= 0.5:
		me.go("idle")


func _start_attack(dist: float) -> void:
	var heavy := me.world.rand() < 0.3
	var idm: String = (ATTACKS_HEAVY if heavy else ATTACKS_LIGHT)[me.world.randi_n(2)]
	me.start_move(idm)
	me.emit("telegraph", {"color": Moves.M[idm].telegraph, "frames": int(Moves.M[idm].startup)})
	cooldown = 70 + me.world.randi_n(50)


func _attack() -> void:
	if me.move_phase() == "recovery":
		me.brake(30.0)
	elif me.move_phase() == "startup":
		var h := me.world.nearest_player(me)
		if h:
			me.turn_towards(h.global_position - me.global_position, 5.0)
	if me.move_done():
		me.go("idle")
		_drop_token()


func _drop_token() -> void:
	if token:
		token = false
		me.world.release_token(me)


func on_incoming(attacker: Fighter, m: Dictionary, dir: Vector3) -> String:
	if me.state == "guard" and dir.dot(me.facing) < 0.3 and not m.get("low", false):
		return "block"
	return ""


func on_parried(by: Fighter) -> void:
	me.go("stagger")
	me.stun = 36
	me.hvel = -me.facing * 3.0
	_drop_token()


func on_hit_landed(target: Fighter, m: Dictionary) -> void:
	pass

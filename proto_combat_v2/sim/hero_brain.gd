class_name HeroBrain
extends RefCounted
## Le cerveau du héros : lit la commande de l'image (stick + boutons) et pilote le Fighter.
## Logique du proto v0.1 (tampon de 150 ms, annulations, coups maintenus, esquive parfaite, parade / riposte, saut de
## poursuite) avec les corrections de Thibaud. Les chiffres viennent de data/tuning.gd et data/moves.gd.

var me: Fighter
var buf := {}                 # bouton -> images restantes dans le tampon
var hold_t := {}              # bouton -> images maintenues
var sprint := false
var stick_full := 0           # images stick poussé à fond
var sprinting_now := false
var roll_cd := 0
var parry_cd := 0
var parry_win := 0            # images restantes de parade ouverte
var riposte_win := 0
var dodge_ok_win := 0         # images restantes pendant lesquelles un coup aurait touché (esquive parfaite)
var jumps := 0
var air_dash_used := false
var air_combo := 0
var land_f := 0
var charge_f := 0
var pursuit_target: Fighter = null
var pursuit_win := 0
var last_stick := Vector3.ZERO
var guard_held := false
var grab_f := 0
var grab_phase := ""          # "" | catch | hold | slam | whiff
var pummel_cd := 0
var slam_hit := false
var combo_x := 0              # jabs enchaînés (le lanceur demande 2 X)
var move_start_cmd := Vector3.ZERO
var wall_run := 0
var hold_done := false        # le maintien a déjà transformé ce coup


func _init(f: Fighter) -> void:
	me = f


func stick3(cmd) -> Vector3:
	return Vector3(cmd.stick.x, 0, cmd.stick.y)


func press(b: String) -> void:
	buf[b] = Tuning.vi("buffer")


func buffered(b: String, consume := true) -> bool:
	if buf.get(b, 0) > 0:
		if consume:
			buf.erase(b)
		return true
	return false


func clear(b: String) -> void:
	buf.erase(b)


## Image figée (hitstop) : on note quand même les appuis et les maintiens.
func note(cmd) -> void:
	if cmd == null:
		return
	for b in InputSource.BUTTONS:
		if cmd.pressed(b):
			press(b)
		if cmd.down(b):
			hold_t[b] = hold_t.get(b, 0) + 1
		else:
			hold_t.erase(b)


func tick(cmd) -> void:
	# 1. tampon et maintiens
	note(cmd)
	for b in buf.keys():
		buf[b] -= 1
		if buf[b] <= 0:
			buf.erase(b)
	for k in ["roll_cd", "parry_cd", "parry_win", "riposte_win", "dodge_ok_win", "pursuit_win", "pummel_cd", "land_f"]:
		if get(k) > 0:
			set(k, get(k) - 1)
	var s := stick3(cmd)
	if s.length() > 0.95:
		stick_full += 1
	else:
		stick_full = 0
	if cmd.pressed("sprint"):
		sprint = true
	if s.length() < 0.3:
		sprint = false
	sprinting_now = (sprint or stick_full >= int(Tuning.v("sprint_hold") * 60.0)) and s.length() > 0.6
	if cmd.pressed("reset"):
		me.emit("reset", {})
	# 2. états subis
	if me.tick_hurt():
		if me.state == "air_hit" and me.grounded == false:
			pass
		return
	if me.grounded:
		jumps = 0
		air_dash_used = false
	match me.state:
		"idle", "run", "sprint":
			_ground(cmd, s)
		"roll":
			_roll(cmd, s)
		"air":
			_air(cmd, s)
		"air_dash":
			_air_dash(cmd, s)
		"attack":
			_attack(cmd, s)
		"guard", "parry":
			_guard(cmd, s)
		"land":
			me.brake()
			land_f -= 1
			if land_f <= 0:
				me.go("idle")
			else:
				_try_actions(cmd, s, true)
		"grab", "hold":
			_grab(cmd, s)
		"charge":
			_charge(cmd, s)


# ------------------------------------------------------------------ au sol
func _ground(cmd, s: Vector3) -> void:
	if _try_actions(cmd, s):
		return
	var want := Vector3.ZERO
	if s.length() > 0.05:
		var sp := Tuning.v("walk_speed") if s.length() < 0.5 else Tuning.v("run_speed")
		if sprinting_now:
			sp = Tuning.v("sprint_speed")
		want = s.normalized() * sp
		me.turn_towards(s)
	me.drive(want)
	var st := "idle"
	if me.hvel.length() > 0.5:
		st = "sprint" if sprinting_now and me.hvel.length() > Tuning.v("run_speed") + 0.3 else "run"
	if me.state != st:
		me.go(st)
	if not me.grounded:
		off_floor += 1
		if off_floor >= 2:
			me.go("air")
			land_f = 0
			coyote = Tuning.vi("coyote")
	else:
		off_floor = 0


var coyote := 0
var off_floor := 0


## Actions possibles depuis le sol (ou la fin d'un coup). Renvoie vrai si une action a démarré.
func _try_actions(cmd, s: Vector3, from_recovery := false) -> bool:
	if riposte_win > 0 and buffered("attack"):
		_begin_move("riposte", s)
		riposte_win = 0
		return true
	if buffered("dodge") and roll_cd <= 0:
		_begin_roll(s)
		return true
	if buffered("jump") and (me.grounded or coyote > 0):
		_jump(s)
		return true
	if buffered("grab"):
		_begin_grab(s)
		return true
	if buffered("attack"):
		if sprinting_now and me.state == "sprint":
			_begin_move("slide_kick", s)
		else:
			_begin_move("jab", s)
			combo_x = 1
		return true
	if buffered("heavy"):
		if sprinting_now and me.state == "sprint":
			_begin_move("big_kick", s)
		else:
			_begin_move("push_kick", s)
		return true
	if cmd.down("guard") and parry_cd <= 0 and me.state != "guard":
		me.go("parry")
		parry_win = Tuning.vi("parry_window")
		me.guarding = true
		clear("guard")
		return true
	return false


func _begin_move(idm: String, s: Vector3) -> void:
	var m := Moves.get_move(idm)
	if s.length() > 0.3 and not m.get("air", false):
		me.face_to(s)
	var lunge := -1.0
	# aide à la visée : oriente vers l'ennemi le plus pertinent du cône du stick, règle l'élan pour arriver au contact
	var assist := Tuning.v("assist")
	if assist > 0.0:
		var t := me.world.best_target(me, s if s.length() > 0.3 else me.facing, Tuning.v("assist_range"), Tuning.v("assist_cone"))
		if t:
			var d: Vector3 = t.global_position - me.global_position
			d.y = 0
			var dist := d.length()
			var want_dir := d.normalized()
			var a := me.facing.signed_angle_to(want_dir, Vector3.UP)
			me.facing = me.facing.rotated(Vector3.UP, a * assist).normalized()
			var need := dist - float(m.box[0]) - Fighter.RADIUS * 0.5
			lunge = lerpf(float(m.get("lunge", 0.0)) * Tuning.v("lunge_scale"), clampf(need, 0.0, 4.5), assist)
	me.start_move(idm, lunge)
	charge_f = 0
	hold_done = false
	move_start_cmd = s


func _begin_roll(s: Vector3) -> void:
	if s.length() > 0.3:
		me.face_to(s)
	me.go("roll")
	roll_cd = Tuning.vi("roll_frames") + Tuning.vi("roll_cooldown")
	me.hvel = me.facing * (Tuning.v("roll_dist") / (Tuning.vi("roll_frames") / 60.0))
	me.invincible = true
	me.emit("roll", {"perfect": dodge_ok_win > 0})
	if dodge_ok_win > 0:
		me.crit_next = true
		me.slow = 36
		me.emit("perfect_dodge", {})
		dodge_ok_win = 0


func _roll(cmd, s: Vector3) -> void:
	var n := Tuning.vi("roll_frames")
	me.invincible = me.f >= Tuning.vi("roll_inv_from") and me.f <= Tuning.vi("roll_inv_to")
	if me.f >= Tuning.vi("roll_attack_from"):
		if buffered("attack"):
			me.invincible = false
			_begin_move("dash_punch", s)
			return
		if buffered("heavy"):
			me.invincible = false
			_begin_move("slide", s)
			return
	if me.f >= n:
		me.invincible = false
		me.go("idle")
		return
	# la roulade garde sa vitesse puis freine sur la fin
	if me.f > n * 0.7:
		me.brake(60.0)


func _jump(s: Vector3) -> void:
	me.velocity.y = Tuning.v("jump_speed")
	me.grounded = false
	coyote = 0
	jumps = 1
	air_combo = 0
	if s.length() > 0.3:
		me.face_to(s)
		if me.hvel.length() < 2.0:
			me.hvel = s.normalized() * 2.5
	me.go("air")
	if pursuit_win > 0 and is_instance_valid(pursuit_target):
		# saut de poursuite : monte à la hauteur où l'ennemi a été envoyé
		# sommet de la trajectoire de l'ennemi : on saute juste en dessous
		var tv: float = maxf(pursuit_target.velocity.y, 0.0)
		var apex: float = pursuit_target.global_position.y + tv * tv / (2.0 * Tuning.v("juggle_grav"))
		var h := clampf(apex - 0.4, 1.4, 5.0)
		me.velocity.y = sqrt(2.0 * Tuning.v("grav_up") * h)
		me.hvel = (pursuit_target.global_position - me.global_position) * Vector3(1, 0, 1) * 1.5
		me.emit("pursuit", {})
		pursuit_win = 0
	me.emit("jump", {})


func _air(cmd, s: Vector3) -> void:
	if coyote > 0:
		coyote -= 1
	if me.grounded and me.velocity.y <= 0.0:
		_landed(false)
		return
	# contrôle en l'air : léger
	if s.length() > 0.1:
		me.hvel = me.hvel.move_toward(s.normalized() * Tuning.v("run_speed"), 18.0 / 60.0)
		me.turn_towards(s, 14.0)
	if buffered("jump") and jumps < 2:
		jumps = 2
		me.velocity.y = Tuning.v("double_jump")
		if s.length() > 0.3:
			me.face_to(s)
		me.emit("double_jump", {})
		return
	if buffered("dodge") and not air_dash_used:
		air_dash_used = true
		if s.length() > 0.3:
			me.face_to(s)
		me.go("air_dash")
		me.invincible = true
		me.hvel = me.facing * (Tuning.v("air_dash_dist") / (Tuning.vi("air_dash_frames") / 60.0))
		me.velocity.y = 0.0
		me.emit("air_dash", {})
		return
	if buffered("attack"):
		_begin_move("air_jab" if air_combo == 0 else ("air_kick" if air_combo == 1 else "air_heel"), s)
		air_combo += 1
		me.velocity.y = maxf(me.velocity.y, me.hang)
		return
	if buffered("heavy"):
		_begin_move("air_knee", s)
		me.velocity.y = maxf(me.velocity.y, me.hang)
		return


func _air_dash(cmd, s: Vector3) -> void:
	if me.f >= Tuning.vi("air_dash_frames"):
		me.invincible = false
		me.hvel *= 0.4
		me.go("air")
		return
	me.velocity.y = 0.0


func _landed(heavy: bool) -> void:
	me.go("land")
	land_f = Tuning.vi("land_heavy_frames") if heavy else Tuning.vi("land_frames")
	me.hvel *= 0.3
	me.emit("land", {"heavy": heavy})
	air_combo = 0


# ------------------------------------------------------------------ coups
func _attack(cmd, s: Vector3) -> void:
	var m := me.mv
	var phase := me.move_phase()
	var air: bool = m.get("air", false)
	# coups maintenus : l'appui court est déjà parti, le maintien transforme le coup en cours
	if m.has("hold"):
		var hb := "attack" if me.move_id in ["jab", "air_jab"] else "heavy"
		var need := Tuning.vi("hold_sweep") if m.hold == "sweep" else (Tuning.vi("hold_dive") if m.hold == "dive_kick" else int(Tuning.v("charge_min") * 60.0))
		if hold_t.get(hb, 0) >= need and not hold_done:
			hold_done = true
			if m.hold == "charged":
				me.go("charge")
				charge_f = 0
				me.armor = true
				return
			_begin_move(m.hold, s)
			return
	if air:
		if me.grounded and me.velocity.y <= 0.0 and not m.get("dive", false):
			_landed(bool(m.get("heavy_land", false)))
			return
		if m.get("dive", false):
			me.velocity.y = minf(me.velocity.y, -14.0)
			me.hvel = me.facing * 6.0
			if me.grounded:
				me.emit("quake", {"radius": 2.6, "dmg": float(m.get("quake", 0))})
				me.world.quake(me, 2.6, float(m.get("quake", 0)))
				_landed(true)
				return
	else:
		if phase == "recovery":
			me.brake(60.0)
	# esquive qui coupe le coup
	var dodge_rule: String = m.get("dodge", "always")
	var can_dodge := dodge_rule == "always" or (dodge_rule == "active" and phase == "recovery") or (dodge_rule == "hit" and me.hit_landed and phase != "startup")
	if can_dodge and buffered("dodge", false):
		if air:
			if not air_dash_used:
				buffered("dodge")
				air_dash_used = true
				me.go("air_dash")
				me.invincible = true
				if s.length() > 0.3:
					me.face_to(s)
				me.hvel = me.facing * (Tuning.v("air_dash_dist") / (Tuning.vi("air_dash_frames") / 60.0))
				return
		elif roll_cd <= 0:
			buffered("dodge")
			_begin_roll(s)
			return
	# saut qui annule (lanceur / glissade qui a touché)
	if m.get("jump_cancel", false) and me.hit_landed and buffered("jump") and phase != "startup":
		_jump(s)
		return
	# enchaînements
	if me.f >= int(m.get("chain_from", 999)):
		var ch: Dictionary = m.get("chain", {})
		for b in ["attack", "heavy"]:
			if ch.has(b) and buffered(b, false):
				var nxt: String = ch[b]
				if nxt == "launcher" and combo_x < 2:
					nxt = "push_kick"
				buffered(b)
				if b == "attack" and not air:
					combo_x += 1
				_begin_move(nxt, s)
				return
	if me.move_done():
		me.armor = false
		if air:
			me.go("air")
		else:
			me.go("idle")
			combo_x = 0
			_try_actions(cmd, s)


func _charge(cmd, s: Vector3) -> void:
	charge_f += 1
	me.brake(20.0)
	if s.length() > 0.3:
		me.turn_towards(s, 6.0)
	var maxf_ := int(Tuning.v("charge_max") * 60.0)
	if not cmd.down("heavy") or charge_f >= maxf_:
		me.armor = false
		_begin_move("charged", s)
		var k := clampf(float(charge_f) / float(maxf_), 0.0, 1.0)
		me.mv = me.mv.duplicate()
		me.mv.dmg = lerpf(14.0, float(Moves.M.charged.dmg), k)
		me.mv.kb = [lerpf(11.0, 16.0, k), lerpf(4.0, 5.0, k)]
		me.emit("charge_release", {"k": k})


# ------------------------------------------------------------------ garde / parade
func _guard(cmd, s: Vector3) -> void:
	me.brake(50.0)
	if me.state == "parry":
		if me.f > Tuning.vi("parry_window"):
			me.go("guard")
	if s.length() > 0.3:
		me.turn_towards(s, 10.0)
		me.drive(s.normalized() * Tuning.v("guard_speed"))
	if not cmd.down("guard"):
		me.guarding = false
		parry_cd = Tuning.vi("parry_cooldown")
		me.go("idle")
		return
	if buffered("attack") and riposte_win > 0:
		me.guarding = false
		_begin_move("riposte", s)
		riposte_win = 0
		return
	if buffered("dodge") and roll_cd <= 0:
		me.guarding = false
		_begin_roll(s)
		return
	if buffered("jump"):
		me.guarding = false
		_jump(s)


## Appelé par Fighter.take_hit : parade si la fenêtre est ouverte, garde si de face.
func on_incoming(attacker: Fighter, m: Dictionary, dir: Vector3) -> String:
	if me.state == "parry" and me.f <= Tuning.vi("parry_window"):
		riposte_win = Tuning.vi("riposte_frames")
		me.go("guard")
		attacker.parried_by(me)
		return "parry"
	if me.state in ["guard", "parry"] and dir.dot(me.facing) < 0.3 and not m.get("low", false):
		return "block"
	return ""


# ------------------------------------------------------------------ chope
func _begin_grab(s: Vector3) -> void:
	if s.length() > 0.3:
		me.face_to(s)
	var t: Fighter = me.world.best_target(me, me.facing, Tuning.v("grab_reach") + 0.5, 90.0, true)
	if t:
		var d := t.global_position - me.global_position
		d.y = 0
		me.face_to(d)
	me.go("grab")
	grab_phase = "startup"
	grab_f = 0
	me.emit("grab_try", {})


func _grab(cmd, s: Vector3) -> void:
	grab_f += 1
	me.brake(40.0)
	match grab_phase:
		"startup":
			if grab_f >= Tuning.vi("grab_startup"):
				var t: Fighter = me.world.best_target(me, me.facing, Tuning.v("grab_reach"), 80.0, true)
				if t and t.grabbable():
					_catch(t)
				else:
					grab_phase = "whiff"
					grab_f = 0
					me.emit("grab_whiff", {})
		"whiff":
			if grab_f >= Tuning.vi("grab_whiff"):
				me.go("idle")
				grab_phase = ""
		"catch":
			var g: Dictionary = Moves.GRAB.catch
			if grab_f >= int((g.to - g["from"]) / g.speed * 60.0):
				grab_phase = "hold"
				grab_f = 0
				me.emit("grab_hold", {})
		"hold":
			var v := me.holding
			if not is_instance_valid(v):
				me.go("idle"); grab_phase = ""; return
			if buffered("grab") or buffered("heavy"):
				grab_phase = "slam"
				grab_f = 0
				slam_hit = false
				me.emit("grab_slam", {})
				return
			if buffered("dodge"):
				me.release_hold()
				me.go("idle"); grab_phase = ""
				return
			if buffered("attack") and pummel_cd <= 0:
				pummel_cd = Tuning.vi("grab_pummel_every")
				v.hp -= Tuning.v("grab_pummel_dmg")
				v.freeze = maxi(v.freeze, 3)
				me.emit("pummel", {"target": v.id})
				v.emit("pummeled", {})
			if grab_f >= Tuning.vi("grab_hold_max"):
				# trop long : il se dégage (règle de Smash Bros)
				var push := -me.facing * float(Moves.GRAB.escape.push)
				v.grabbed_by = null
				v.go("stagger"); v.stun = 10; v.hvel = me.facing * 3.0
				me.holding = null
				me.go("stagger"); me.stun = int(Moves.GRAB.escape.stun); me.hvel = push
				grab_phase = ""
				me.emit("grab_escape", {})
		"slam":
			var g: Dictionary = Moves.GRAB.slam
			var impact_f := int((g.impact - g["from"]) / g.speed * 60.0)
			var end_f := int((g.to - g["from"]) / g.speed * 60.0)
			var v := me.holding
			if grab_f >= impact_f and not slam_hit and is_instance_valid(v):
				slam_hit = true
				v.grabbed_by = null
				me.holding = null
				var m := {"dmg": Tuning.v("grab_slam_dmg"), "hitstop": 10, "stun": 50, "kb": [1.0, -12.0], "effect": "spike", "box": [0.9, 0.3, 0.6],
					"shake": 0.7, "sweep_dir": 0}
				v.state = "idle"
				v.grounded = false
				v.global_position = me.global_position + me.facing * 1.1 + Vector3.UP * 0.6
				v.take_hit(me, m, me.facing)
				me.world.on_hit(me, v, m, "hit", true)
				me.emit("slam_impact", {})
			if grab_f >= end_f:
				me.go("idle")
				grab_phase = ""


func _catch(t: Fighter) -> void:
	grab_phase = "catch"
	grab_f = 0
	me.go("hold")
	me.holding = t
	t.grabbed_by = me
	t.go("held")
	t.hvel = Vector3.ZERO
	t.velocity = Vector3.ZERO
	t.mv = {}
	t.move_id = ""
	t.stun = 0
	t.emit("held", {"by": me.id})
	me.emit("grab_catch", {"target": t.id})


## Notre coup a été paré : étourdi, le parieur peut riposter.
func on_parried(by: Fighter) -> void:
	me.go("stagger")
	me.stun = 30
	me.hvel = -me.facing * 3.0


## Appelé par le monde quand un de nos coups touche.
func on_hit_landed(target: Fighter, m: Dictionary) -> void:
	if m.get("effect", "") == "launch" or me.move_id == "slide":
		pursuit_target = target
		pursuit_win = 50
	me.crit_next = false

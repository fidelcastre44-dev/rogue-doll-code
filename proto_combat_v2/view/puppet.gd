class_name Puppet
extends Node3D
## AFFICHAGE d'un combattant : lit l'état du Fighter (simulation) à chaque image et joue l'animation qui le montre.
## Jamais l'inverse : rien ici ne change la simulation. Coups : l'animation part à `from`, son instant de contact `hit`
## tombe sur la 1re image active, puis elle file jusqu'à `end` pendant la récupération (vitesse recalculée, jamais le
## début accéléré au-delà du raisonnable : on coupe le début). Réactions choisies selon le sens, la hauteur et la force du
## coup (tirage partagé dans l'événement). Ragdoll visuel (chute, K.O.) qui ne touche jamais la capsule.

const REACT := {
	# clé -> animations (bibliothèque mx/) ; « right » = la tête part vers la droite du perso
	"front_high": ["mx/h_light_straight", "mx/h_med_straight"], "front_high_right": ["mx/h_light_right", "mx/h_med_right"],
	"front_high_left": ["mx/h_light_left", "mx/h_med_left"],
	"front_high_big": ["mx/h_big_straight"], "front_high_big_right": ["mx/h_big_right"], "front_high_big_left": ["mx/h_big_left"],
	"front_low": ["mx/b_light", "mx/b_straight"], "front_low_big": ["mx/b_big", "mx/b_straight"],
	"back": ["mx/r_back_small"], "back_big": ["mx/r_back_big", "mx/r_back_small"],
	"left": ["mx/r_left_small"], "right": ["mx/r_right_small"], "left_big": ["mx/r_left_big"], "right_big": ["mx/r_right_big"],
	"launch": ["mx/r_uppercut_big", "mx/r_uppercut"], "juggle": ["mx/h_big_straight", "mx/h_big_left", "mx/h_big_right"],
	"stagger": ["mx/stumble", "mx/r_back_big"],
}
const GETUP := {"back": ["mx/getup_back", 4.9, 1.6], "front": ["mx/getup_3", 0.2, 1.4]}

var fi: Fighter
var rig: Rig
var rag: Ragdoll
var ragdoll_on := true
var _anim_phase := ""
var _hit_t := 0.0
var _move_anim := ""
var _last_state := ""
var _last_move_f := -1
var _air_started := false
var _tele_t := 0.0
var _tele_col := Color.RED
var _down_rag := false
var _getup_glide := false
var _getup_done := false
var _hold_dir := 1.0
var _grab_phase_seen := ""
var pair_origin := Transform3D()
var paired := false
var held_anim := ""
var _flat_until := 0.0
var _lean := Vector3.ZERO
var shake_cb: Callable


func setup(f: Fighter) -> void:
	fi = f
	rig = Rig.new()
	add_child(rig)
	rig.setup(f.model)
	rag = Ragdoll.new()
	rag.setup(rig.skel, self)
	rig.play("mx/idle", 0.0)
	if f.kind == "dummy":
		rig.tint = Color(0.5, 0.3, 0.9, 0.0)


func _process(dt: float) -> void:
	if not is_instance_valid(fi):
		return
	# position et orientation = la capsule (vérité), sauf pendant une animation à deux
	if not paired:
		global_position = fi.global_position
		var fw := fi.facing
		if fw.length() > 0.01:
			rotation.y = atan2(fw.x, fw.z)
	# figé à l'impact : l'animation (et le ragdoll) s'arrêtent avec le perso
	var frozen := fi.freeze > 0
	rag.hold(frozen)
	rig.tick(dt)
	if not frozen:
		_update_anim(dt)
	rig.ap.speed_scale = 0.0 if frozen else rig.base_speed
	_update_rag(dt)
	if _tele_t > 0.0:
		_tele_t -= dt
		rig.tint = _tele_col if fmod(_tele_t, 0.12) < 0.06 else Color(_tele_col.r, _tele_col.g, _tele_col.b, 0.0)
		if _tele_t <= 0.0:
			rig.tint = Color(0.5, 0.3, 0.9, 0.0) if fi.kind == "dummy" else Color(1, 1, 1, 0)
	rig.lean = _lean
	_lean = _lean.lerp(Vector3.ZERO, minf(1.0, dt * 10.0))
	_last_state = fi.state


## Vitesse de lecture : on garde la vitesse réelle (lenteur = ralenti par perso) mais le ralenti global du labo est déjà
## dans le temps du moteur.
func _slow_factor() -> float:
	return 0.5 if fi.slow > 0 else 1.0


func _update_anim(_dt: float) -> void:
	var st := fi.state
	var changed := st != _last_state
	match st:
		"idle":
			if changed or rig.current not in ["mx/idle"]:
				rig.play("mx/idle", 0.25, 1.0, 0.0, false)
			rig.set_speed(1.0)
		"run", "sprint":
			var sp := fi.hvel.length()
			if sp < 3.2:
				rig.play("mx/walk_fwd", 0.2, 1.0, 0.0, false)
				rig.set_speed(clampf(sp / 2.6, 0.6, 1.4))
			elif st == "sprint":
				rig.play("mx/sprint", 0.15, 1.0, 0.0, false)
				rig.set_speed(clampf(sp / 7.8, 0.8, 1.3))
			else:
				rig.play("mx/run", 0.15, 1.0, 0.0, false)
				rig.set_speed(clampf(sp / 6.1, 0.7, 1.3))
		"roll":
			if changed:
				# la roulade dure 20 images : on coupe le début et on garde une lecture vive (geste de déplacement, pas une frappe)
				rig.play("mx/roll", 0.05, 2.0, 0.28)
		"air":
			if changed:
				if _last_state in ["idle", "run", "sprint", "land", "guard", "roll", "attack"] and fi.velocity.y > 1.0:
					rig.play("mx/jump_up", 0.08, 1.4, 0.0)
					_air_started = true
				else:
					rig.play("mx/fall_idle", 0.15, 1.0, 0.0, false)
			elif _air_started and rig.current == "mx/jump_up" and rig.pos() >= rig.length() - 0.03:
				rig.play("mx/fall_idle", 0.25, 1.0, 0.0, false)
			elif rig.current == "mx/flip" and rig.pos() >= 1.35:
				rig.play("mx/fall_idle", 0.25, 1.0, 0.0, false)
		"air_dash":
			if changed:
				rig.play("mx/dodge_fwd", 0.05, 2.2, 0.6)
		"land":
			if changed:
				rig.play("mx/land", 0.06, 1.6, 0.3)
		"attack":
			_anim_attack(changed)
		"charge":
			if changed:
				var m: Dictionary = Moves.M.charged
				rig.play(m.charge_anim, 0.1, 1.0, float(m.charge_t))
				rig.set_speed(0.0)
			_lean.z = sin(Time.get_ticks_msec() * 0.03) * 1.5
		"guard":
			if changed or rig.current != "mx/block_idle":
				rig.play("mx/block_idle", 0.12, 1.0, 0.0, false)
		"parry":
			if changed:
				rig.play("mx/block_in", 0.05, 1.5, 0.25)
		"hurt":
			if changed:
				var a := _pick_react(false)
				rig.play(a, 0.03, 1.3, 0.0)
		"stagger":
			if changed:
				rig.play(_pick("stagger"), 0.05, 1.2, 0.1)
		"air_hit":
			if changed:
				var eff: String = fi.last_hit.get("effect", "")
				if eff == "launch":
					rig.play(_pick("launch"), 0.04, 0.9, 0.55)
				elif eff == "spike":
					rig.play("mx/fall_idle", 0.05, 1.0, 0.0, false)
				elif eff == "knockdown":
					rig.play("mx/flip_back_hit", 0.04, 1.1, 0.3)
				else:
					rig.play(_pick("juggle"), 0.03, 1.1, 0.1)
			elif rig.pos() >= rig.length() - 0.02 and rig.current != "mx/fall_idle":
				rig.play("mx/fall_idle", 0.2, 1.0, 0.0, false)
			# en l'air : le corps part en arrière, un peu plus à chaque coup (lisible, contrôlé ; le ragdoll ne vient qu'à la chute)
			_lean.x = clampf(-18.0 - fi.juggle * 10.0 + fi.velocity.y * 1.5, -70.0, 10.0)
		"down":
			if changed:
				_begin_down()
		"getup":
			if changed:
				_getup_glide = ragdoll_on and rag.active
				_getup_done = false
				if not _getup_glide:
					_play_getup()
			elif _getup_glide and _getup_done == false:
				pass
		"grab":
			var gb: HeroBrain = fi.brain
			if changed:
				_grab_phase_seen = "startup"
				rig.play(Moves.GRAB.pair[0], 0.06, 1.8, float(Moves.GRAB.catch["from"]) - 0.3)
			elif gb.grab_phase == "whiff" and _grab_phase_seen != "whiff":
				_grab_phase_seen = "whiff"
				rig.set_speed(0.5)     # dans le vide : le geste s'étire, puis retour à la garde
		"hold":
			_anim_hold(changed)
		"held":
			_anim_held(changed)


func _anim_attack(changed: bool) -> void:
	var m := fi.mv
	if m.is_empty():
		return
	if changed or _move_anim != fi.move_id or fi.f < _last_move_f:
		_move_anim = fi.move_id
		_anim_phase = "startup"
		var from := Moves.from_time(m)
		var hit := float(m.hit)
		var su := maxf(float(m.startup), 1.0) / 60.0
		var sp := clampf((hit - from) / su, 0.5, 1.6)
		rig.play(m.anim, 0.05, sp * _slow_factor(), from)
		_hit_t = hit
	_last_move_f = fi.f
	var phase := fi.move_phase()
	if phase != "startup" and _anim_phase == "startup":
		_anim_phase = "active"
		# recalage exact sur le contact, puis vitesse pour arriver à `end` à la fin du coup
		var left := float(int(m.active) + int(m.recovery)) / 60.0
		var sp := clampf((float(m.end) - _hit_t) / maxf(left, 0.02), 0.5, 2.2)
		rig.ap.seek(_hit_t, true)
		rig.set_speed(sp * _slow_factor())
	if m.get("dive", false):
		_lean.x = -35.0


func _pick(key: String) -> String:
	var pool: Array = REACT[key]
	var r: float = fi.last_hit.get("roll", 0.0)
	var a: String = pool[int(r * pool.size()) % pool.size()]
	if not rig.has(a):
		return "mx/h_light_straight"
	return a


## Réaction selon le côté d'où vient le coup, sa hauteur, sa force et le sens du geste (la tête part dans le sens du poing).
func _pick_react(big: bool) -> String:
	var h: Dictionary = fi.last_hit
	var dir: Vector3 = h.get("dir", -fi.facing)
	var local := dir.dot(fi.facing)      # < 0 : coup qui vient de devant (il est poussé vers l'arrière)
	var side := dir.dot(fi.facing.cross(Vector3.UP))   # > 0 : poussé vers sa droite
	var strong := big or float(h.get("dmg", 0)) >= 8.0
	var key := ""
	if local < -0.5:
		if float(h.get("height", 1.2)) < 0.9:
			key = "front_low_big" if strong else "front_low"
		else:
			key = "front_high_big" if strong else "front_high"
			var sw := int(h.get("sweep_dir", 0))
			if sw != 0:
				key += "_right" if sw > 0 else "_left"
	elif local > 0.5:
		key = "back_big" if strong else "back"
	else:
		key = ("right" if side > 0 else "left") + ("_big" if strong else "")
	if not REACT.has(key):
		key = "front_high"
	return _pick(key)


func _begin_down() -> void:
	var face_up: bool = fi.last_hit.get("effect", "") != "juggle" or fi.fall_up
	face_up = fi.fall_up
	if ragdoll_on:
		if not rag.active:
			var v := Vector3(fi.hvel.x, maxf(fi.velocity.y, -2.0), fi.hvel.z)
			if v.length() < 1.0:
				v = -fi.facing * 2.5 if face_up else fi.facing * 2.5
			rag.start(v, false)
		_down_rag = true
		rag.damp(0.5)
	else:
		rig.play("mx/ko_back" if face_up else "mx/ko_front", 0.08, 1.4, 1.2)
		rig.set_speed(1.4)


func _play_getup() -> void:
	var g: Array = GETUP["back" if fi.fall_up else "front"]
	rig.play(g[0], 0.15, float(g[2]), float(g[1]))
	_getup_done = true


func _update_rag(dt: float) -> void:
	if not rag.active:
		return
	match fi.state:
		"down":
			rag.tether(fi.global_position + Vector3.UP * 0.3, dt, 0.25, Tuning.v("rag_damp") * 2.0)
		"getup":
			if _getup_glide:
				var g: Array = GETUP["back" if fi.fall_up else "front"]
				var target: Vector3 = rig.getup_start(fi.fall_up, GETUP.back[0], float(GETUP.back[1]), GETUP.front[0], float(GETUP.front[1])).pelvis
				if rag.glide(target, dt, 14.0) or fi.stun < 10:
					_getup_glide = false
					_play_getup()
					rag.blend_out(0.25)
		"air_hit":
			rag.pin(fi.global_position + Vector3.UP * 0.95, dt)
		_:
			rag.blend_out(0.2)


# ------------------------------------------------------------------ chope : animations à deux depuis une même origine

## Le repère de la paire : posé pour que l'attaquant soit sur sa capsule et la victime devant lui.
func start_pair(victim: Puppet, anim_a: String, anim_b: String, t: float, speed: float) -> void:
	var pa: Vector3 = (rig.pose_at(anim_a, t)["pelvis"] as Transform3D).origin
	var pb: Vector3 = (rig.pose_at(anim_b, t)["pelvis"] as Transform3D).origin
	var d := Vector3(pb.x - pa.x, 0, pb.z - pa.z)
	var yaw := atan2(fi.facing.x, fi.facing.z) - atan2(d.x, d.z)
	var xf := Transform3D(Basis(Vector3.UP, yaw), fi.global_position - Basis(Vector3.UP, yaw) * Vector3(pa.x, 0, pa.z))
	pair_origin = xf
	paired = true
	global_transform = xf
	rig.play(anim_a, 0.1, speed, t)
	if victim:
		victim.pair_origin = xf
		victim.paired = true
		victim.global_transform = xf
		victim.rig.play(anim_b, 0.1, speed, t)
		victim.held_anim = anim_b


func end_pair(victim: Puppet) -> void:
	paired = false
	if victim:
		victim.paired = false


func _anim_hold(changed: bool) -> void:
	var b: HeroBrain = fi.brain
	var victim: Puppet = get_parent().puppet_of(fi.holding) if is_instance_valid(fi.holding) else null
	var g := Moves.GRAB
	var phase: String = b.grab_phase
	var entered := phase != _grab_phase_seen or changed
	_grab_phase_seen = phase
	match phase:
		"catch":
			if entered:
				start_pair(victim, g.pair[0], g.pair[1], float(g.catch["from"]), float(g.catch.speed))
		"hold":
			if entered:
				rig.play(g.pair[0], 0.15, float(g.hold.speed), float(g.hold.at))
				if victim:
					victim.rig.play(g.pair[1], 0.15, float(g.hold.speed), float(g.hold.at))
				_hold_dir = 1.0
			# aller-retour lent sur le passage du tenu
			var p := rig.pos()
			if p >= float(g.hold.to) and _hold_dir > 0:
				_hold_dir = -1.0
			elif p <= float(g.hold.at) and _hold_dir < 0:
				_hold_dir = 1.0
			rig.set_speed(float(g.hold.speed) * _hold_dir)
			if victim:
				victim.rig.set_speed(float(g.hold.speed) * _hold_dir)
		"slam":
			if entered:
				rig.play(g.pair[0], 0.08, float(g.slam.speed), float(g.slam["from"]))
				if victim:
					victim.rig.play(g.pair[1], 0.08, float(g.slam.speed), float(g.slam["from"]))
			rig.set_speed(float(g.slam.speed))
			if victim:
				victim.rig.set_speed(float(g.slam.speed))
	if phase == "":
		end_pair(victim)


func _anim_held(changed: bool) -> void:
	# l'animation est pilotée par le puppet de l'attaquant (même origine, même temps)
	if fi.grabbed_by == null and paired:
		paired = false


# ------------------------------------------------------------------ événements de la simulation
func on_event(e: Dictionary) -> void:
	match e.type:
		"telegraph":
			_tele_t = float(e.frames) / 60.0
			_tele_col = Color(1, 0.15, 0.1) if e.color == "red" else Color(1, 0.6, 0.1)
		"hit":
			rig.flash(0.1, Color(1, 0.9, 0.8))
			if rag.active:
				rag.kick(Vector3(e.get("dir", Vector3.ZERO)) * 4.0 + Vector3.UP * 2.0, fi.centre())
			elif ragdoll_on and fi.state in ["hurt", "stagger"] and not e.get("armor", false):
				rag.react(Vector3(e.dir) * 3.0, fi.centre() + Vector3.UP * 0.3, 0.45)
		"pummeled":
			rig.flash(0.08, Color(1, 0.9, 0.8))
			_lean.x = 12.0
		"block":
			rig.flash(0.08, Color(0.6, 0.8, 1.0))
		"parry":
			rig.flash(0.12, Color(1, 1, 0.4))
		"down":
			if not _down_rag and fi.state == "down":
				_begin_down()
		"bounce":
			if rag.active:
				rag.kick(Vector3.UP * 5.0, fi.centre())
		"respawn", "reset_done":
			rag.stop()
			_down_rag = false
			paired = false
			rig.play("mx/idle", 0.1)
		"double_jump":
			rig.play("mx/flip", 0.06, 1.6, 0.38)
		"state":
			if e.to in ["idle", "run", "sprint", "attack", "roll", "guard"] and e.from in ["getup", "down"]:
				_down_rag = false
				rag.blend_out(0.2)
			if e.from == "held" and paired and e.to != "held":
				paired = false
				global_position = fi.global_position

class_name Hero
extends CharacterBody3D
## Le héros. Toute la logique est en images (60 / s), à la manière d'un jeu de combat ; l'animation ne fait que suivre.
##
## États : move (au sol, déplacement libre), air (en l'air), attack, dodge, airdash, guard, grab, hurt, down (à terre), charge,
##  + v0.112 : hang (agrippé à un rebord), climb (se hisser / enjamber), wallrun (course sur le mur).
## v0.112 :
##  - ARMES (game/weapons.gd) : RB devant le mur d'armes = prendre / raccrocher ; chaque arme a ses coups (moves.gd sw_, ka_, ax_, bt_)
##    et sa zone de frappe suit la lame (balayage entre deux images) ;
##  - CHOPE tenue jusqu'à 3 s : X = coups, Y = l'éclater au sol (il rebondit, jonglable), R1 = le lancer ; sinon il se dégage ;
##  - REBORDS d'après Climbing Physics Prototype (teitasan, MIT : détection mur + dessus par rayons, agrippe, déplacement le long,
##    se hisser en deux temps, lâcher) ; COURSE AU MUR d'après godot-wall-running (Garbaj, MIT : mur détecté sur le côté, gravité
##    coupée) et les réglages de Vigilante (madebynova : 1,2 s, saut mur à mur de 2 à 3,5 m).
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
var rag: Ragdoll
var fall_up := true            # v0.114 : se relèvera sur le dos (true) ou à plat ventre, selon le sens du coup
var getup_glide := {}          # v0.114 : relevé en cours (le ragdoll glisse vers le bassin de l'animation)
var pair_on := false           # v0.114 : animation à deux en cours (chope : éclater au sol / projection d'épaule)
var guard_cool := 0.0          # parade pas spammable : re-garder trop vite = pas de fenêtre de parade
# v0.112
var weapon := ""               # "" = mains nues ; sinon une clé de Weapons.DEFS
var weapon_node: Node3D
var _blade_prev := []
var grab_mode := ""            # "hold" (tenu), "slam" (éclaté au sol), "throw" (lancé)
var grab_f := 0
var pummel_cd := 0
var col_shape: CollisionShape3D
var hang_h := 2.05             # hauteur des mains au-dessus des pieds, suspendu (mesurée sur l'animation)
var ledge := {}
var climb_f := 0
var climb_p1 := 0
var climb_p2 := 0
var climb_start := Vector3.ZERO
var drop_lock := 0.0
var hang_push := 0
var wall_n := Vector3.ZERO
var wr_dir := Vector3.ZERO
var wr_speed := 0.0
var last_wall_n := Vector3.ZERO
var wall_lock := 0.0
var wj_t := 0.0                # après un saut de mur : l'élan prime sur le stick (comme dans le jeu principal, v0.23)
var wall_chain := 0            # courses au mur depuis le dernier appui au sol
var pursuit := false           # saut de poursuite après un lanceur : gravité de montée jusqu'au sommet
var climb_kind := ""           # "mantle", "hang", "runup", "vault"
var climb_end := 0
var stop_anim := 0             # images restantes de l'animation d'arrêt / de demi-tour
var guard_step := ""
var mx_info := {}
var jump_speed := 0.0          # vitesse au sol au moment du saut (monter un mur en courant : seulement si on courait)
const HANG_ANIM := "mx/ledge__hanging_idle_against_wall"
const HANG_REACH := 2.35       # rebord le plus haut qu'on attrape (au-dessus des pieds), en l'air
const MANTLE_MAX := 1.45       # en dessous : on enjambe directement
const VAULT_MAX := 1.25        # obstacle franchi en courant (s'il est fin)
const VAULT_SPEED := 5.0
const VAULT_DEPTH := 1.1       # épaisseur maxi d'un obstacle qu'on franchit
const RUNUP_MAX := 3.6         # mur qu'on monte en courant (au-dessus des pieds)
const SHIMMY := 1.85           # m/s le long du rebord (Climbing Physics Prototype : TRAVERSE_SPEED)
# v0.113 : course au mur nettement affaiblie (retour de Paul : « ça marche bien, il faut la rendre beaucoup moins puissante »)
const WR_MIN_SPEED := 5.0      # vitesse le long du mur pour s'y mettre à courir
const WR_SPEED := 6.5          # plafond (plus de vitesse gratuite : on garde au plus son élan)
const WR_MAX := 0.7            # s (1,3 s en v0.112)
const WR_CHAIN := 3            # courses au mur d'affilée sans toucher le sol
const WR_MIN_H := 0.8          # m au-dessus du dernier sol pour prendre le mur (v0.114)
const WJ_OUT := 5.2            # saut de mur : vers l'extérieur (couloir de 2,5 m traversé en ~0,35 s)
const WJ_UP := 6.0


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
	col_shape = cs
	set_look(look)


func set_look(l: String) -> void:
	look = l
	if rig:
		rig.queue_free()
	rig = Rig.new()
	add_child(rig)
	rig.setup(l)
	rag = Ragdoll.new()
	rag.setup(rig.skel, self)
	rig.play("cmu/guard_idle", 0.0)
	_face_rig()
	if mx_info.is_empty() and FileAccess.file_exists("res://assets/anims/mx_info.json"):
		mx_info = JSON.parse_string(FileAccess.get_file_as_string("res://assets/anims/mx_info.json"))
	if rig.has(HANG_ANIM):
		var hp: Dictionary = rig.pose_at(HANG_ANIM, 0.5)
		hang_h = maxf((hp["hand_r"] as Transform3D).origin.y + 0.06, 1.6)
	weapon_node = null
	if weapon != "":
		_attach_weapon()


# ------------------------------------------------------------------ armes (v0.112)

## Animations de l'arme en main (Mixamo : packs épée-bouclier, hache, épée à deux mains ; v0.113).
const WEAPON_ANIMS := {
	"sword": {"idle": "mx/sword__idle", "run": "mx/sword__run", "block": "block"},
	"katana": {"idle": "mx/sword__idle", "run": "mx/katana__running_with_sword", "block": "block", "equip": ["mx/katana__draw_sword", 0.0, 1.2]},
	"axe": {"idle": "mx/axe__idle", "run": "mx/axe__run", "block": "mx/axe__block", "equip": ["mx/axe__equip_over_shoulder", 0.3, 1.6]},
	"bat": {"idle": "mx/bat__batter_idle", "run": "mx/axe__run", "block": "mx/greatsword__blocking_idle"},
}


func _wanim(slot: String, default: String) -> String:
	if weapon != "" and WEAPON_ANIMS[weapon].has(slot) and rig.has(WEAPON_ANIMS[weapon][slot]):
		return WEAPON_ANIMS[weapon][slot]
	return default


func equip(id: String) -> void:
	unequip()
	weapon = id
	_attach_weapon()
	in_combat_t = 4.0
	if WEAPON_ANIMS[id].has("equip") and state == "move":
		var e: Array = WEAPON_ANIMS[id].equip
		rig.play(e[0], 0.08, e[2], e[1])
		stop_anim = 30
	rig.flash(0.12, Weapons.DEFS[id].col)
	game.popup(global_position + Vector3.UP * 2.3, Weapons.DEFS[id].name.to_upper(), Weapons.DEFS[id].col)
	game.sfx.play("whoosh", global_position, 0.6)


func unequip() -> void:
	if weapon_node and is_instance_valid(weapon_node):
		weapon_node.get_parent().queue_free()
	weapon_node = null
	weapon = ""


func _attach_weapon() -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_name = "hand_r"
	rig.skel.add_child(ba)
	weapon_node = Weapons.make_model(weapon)
	ba.add_child(weapon_node)


## Coup à jouer pour un « emplacement » (attack, heavy, air…) : celui de l'arme en main, sinon le coup à mains nues.
func _wmove(slot: String, default: String) -> String:
	if weapon != "" and Weapons.DEFS[weapon].moves.has(slot):
		return Weapons.DEFS[weapon].moves[slot]
	return default


## RB devant le mur d'armes : prendre l'arme (on repose celle qu'on avait), ou raccrocher la sienne devant son crochet.
func _rack_action(id: String) -> void:
	if weapon == id:
		game.arena.rack_show(id, true)
		unequip()
		game.popup(global_position + Vector3.UP * 2.3, "MAINS NUES", Color(1, 1, 1))
		return
	if weapon != "":
		game.arena.rack_show(weapon, true)
	game.arena.rack_show(id, false)
	equip(id)


## Points de la lame dans le monde (de la garde à la pointe), d'après l'os de la main et la prise Weapons.GRIP.
func _blade_points() -> Array:
	var d: Dictionary = Weapons.DEFS[weapon]
	var hb := rig.skel.find_bone("hand_r")
	var g: Transform3D = rig.skel.global_transform * rig.skel.get_bone_global_pose(hb) * Weapons.GRIP
	var out := []
	for i in 4:
		out.append(g * Vector3(0, lerpf(d.blade.x, d.blade.y, i / 3.0), 0))
	return out


func _face_rig() -> void:
	if pair_on:
		return     # animation à deux : le modèle est posé sur le repère de la paire
	rig.rotation.y = atan2(facing.x, facing.z)


# ------------------------------------------------------------------ boucle

func _physics_process(dt: float) -> void:
	if hitstop > 0:
		hitstop -= 1
		rag.hold(true)
		rig.tick(dt)
		return
	rag.hold(false)
	if dodge_cool > 0.0:
		dodge_cool -= dt
		if dodge_cool <= 0.0:
			dodges = 0
	riposte_t = maxf(riposte_t - dt, 0.0)
	guard_cool = maxf(guard_cool - dt, 0.0)
	drop_lock = maxf(drop_lock - dt, 0.0)
	wall_lock = maxf(wall_lock - dt, 0.0)
	wj_t = maxf(wj_t - dt, 0.0)
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
		"hang": _st_hang(dt)
		"climb": _st_climb(dt)
		"wallrun": _st_wallrun(dt, on_floor)
		"preview": _st_preview(dt)
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
	if pair_on and st != "grab":
		_pair_end()
	if state == "grab" and st != "grab":
		rig.clear_overlay()
	if state == "wallrun" and st != "wallrun":
		rig.lean = Vector3.ZERO
		rig.position = Vector3.ZERO
	if state == "climb" and st != "climb" and col_shape:
		col_shape.disabled = false
	if state in ["hang", "climb"] and not st in ["hang", "climb"]:
		rig.position = Vector3.ZERO
		rig.lean = Vector3.ZERO
	state = st
	f = 0


func _gravity(dt: float, mult := 1.0) -> void:
	# montée : gravité douce si A est tenu (ou au tout début du saut : un appui bref donne quand même un vrai saut)
	var g := GRAV_UP if velocity.y > 0.0 and (pursuit or Inputs.held("jump") or (state == "air" and f < 12)) else GRAV_DOWN
	if velocity.y <= 0.0:
		pursuit = false
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
		if hvel.length() > 6.0 and weapon == "":
			# demi-tour en pleine course (Mixamo « Running Turn 180 »)
			rig.play("mx/move__turn_180_running", 0.06, 1.6)
			stop_anim = 14
		hvel = hvel.normalized().slerp(target.normalized(), 0.6) * hvel.length() * 0.5
	elif target.length() < 0.05 and hvel.length() > 7.5 and stop_anim <= 0 and weapon == "":
		# arrêt net après un sprint (Mixamo « Fast Stop From Full Run »)
		rig.play("mx/move__fast_stop", 0.06, 1.7, 0.1)
		stop_anim = 22
	hvel = hvel.move_toward(target, rate * dt)
	_turn_to(d, dt)
	velocity.y = -2.0 if on_floor else velocity.y - GRAV_DOWN * dt
	if on_floor and _try_vault_ground():
		return
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
		var rk: String = game.arena.rack_near(global_position)
		if rk != "":
			_rack_action(rk)
		else:
			_start_grab()
		return true
	if Inputs.buffered("attack"):
		if riposte_t > 0.0:
			_start_attack("riposte")
		elif sprinting:
			_start_attack(_wmove("sprint_attack", "slide"))
		else:
			_start_attack(_wmove("attack", "jab"))
		return true
	if Inputs.buffered("heavy", false, CHARGE_MIN + 0.1):
		if sprinting:
			Inputs.clear("heavy")
			_start_attack(_wmove("sprint_heavy", "flying_hook"))
			return true
		if riposte_t > 0.0:
			Inputs.clear("heavy")
			_start_attack("riposte")
			return true
		if weapon != "":
			# arme en main : Y part tout de suite (pas de charge)
			Inputs.clear("heavy")
			_start_attack(_wmove("heavy", "push_kick"))
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
	if stop_anim > 0:
		stop_anim -= 1
		if sp < 0.35 or stop_anim > 0:
			return
	if sp < 0.35:
		var idle := "cmu/guard_idle" if in_combat_t > 0.0 else "idle"
		if weapon != "":
			idle = _wanim("idle", "sword_idle")
		rig.play(idle, 0.18, 1.0, 0.0, false)
	elif sp < 3.2:
		rig.play("walk", 0.15, clampf(sp / 1.6, 0.8, 1.8), 0.0, false)
	elif sp < 8.0:
		if weapon != "":
			rig.play(_wanim("run", "jog"), 0.12, clampf(sp / 5.0, 0.9, 1.6), 0.0, false)
		else:
			rig.play("jog", 0.12, clampf(sp / 4.6, 0.9, 1.6), 0.0, false)
	else:
		rig.play("mx/move__running_fast" if weapon == "" else _wanim("run", "sprint"), 0.12, clampf(sp / 8.5, 1.0, 1.5), 0.0, false)


func _jump() -> void:
	jump_speed = Vector2(hvel.x, hvel.z).length()
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
	hvel = hvel.move_toward(d * top, AIR_ACCEL * dt * (0.12 if wj_t > 0.0 else 1.0))
	_turn_to(d, dt, TURN * 0.6)
	_gravity(dt)
	fall_peak = maxf(fall_peak, global_position.y)
	if f > 12 and rig.current == "ninja_start":
		rig.play("ninja_loop", 0.2)
	if velocity.y < -3.0 and rig.current in ["ninja_loop", "ninja_start"]:
		rig.play("mx/move__falling_idle", 0.25)
	if coyote > 0 and Inputs.buffered("jump"):
		_jump()
		return
	# v0.112 : rebords et course au mur
	if _try_ledge():
		return
	if _try_wallrun():
		return
	if Inputs.buffered("dodge") and not air_dash_used:
		_start_airdash()
		return
	if Inputs.buffered("attack") and air_attacks < 4:
		_start_attack(_wmove("air", "air_jab"))
		return
	if Inputs.buffered("heavy"):
		_start_attack("air_spike")
		return
	if Inputs.buffered("grab"):
		pass


func _ground_t(nm: String) -> float:
	return float(mx_info.get(nm, {}).get("ground_t", 0.0))


func _land() -> void:
	var drop := fall_peak - global_position.y
	fall_peak = global_position.y
	_go("move")
	land_lag = HEAVY_LAND_LAG if drop > 3.5 else LAND_LAG
	if hvel.length() > 3.0:
		land_lag = 1
	pursuit = false
	wall_chain = 0
	if drop > 2.5 and hvel.length() > 5.0:
		# grande chute en courant : roulade de réception (Mixamo « Falling Into A Roll »)
		rig.play("mx/move__falling_to_roll", 0.05, 1.8, _ground_t("move__falling_to_roll"))
		land_lag = 0
		stop_anim = 30
	elif drop > 3.5:
		rig.play("mx/move__hard_landing", 0.05, 1.7, _ground_t("move__hard_landing"))
		stop_anim = HEAVY_LAND_LAG + 6
	elif drop > 1.2:
		rig.play("mx/move__landing", 0.05, 1.6, _ground_t("move__landing"))
		stop_anim = 10
	else:
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
	_blade_prev = []
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
	if f == su - 2 and mv.get("blade", false) and weapon != "":
		_blade_prev = _blade_points()
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
		if air and not Moves.M[nxt].get("air", false):
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
		# v0.113 : le saut monte aussi haut que l'ennemi envoyé en l'air (sommet de sa trajectoire, un peu en dessous)
		if tgt and is_instance_valid(tgt) and tgt.get("state") == "air":
			var vy: float = maxf(tgt.velocity.y, 0.0)
			var gj: float = tgt.JUGGLE_GRAV * (1.0 + 0.12 * tgt.juggle)
			var apex: float = tgt.global_position.y + vy * vy / (2.0 * gj)
			var h := apex - 0.35 - global_position.y
			if h > 0.5:
				velocity.y = clampf(sqrt(2.0 * GRAV_UP * h), JUMP_V, 15.0)
				pursuit = true
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
	if mv.get("blade", false) and weapon != "":
		_check_blade()
		return
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
			m2.sweep = Moves.SWEEP.get(move_id, 0)
			if perfect_t > 0.0 or mv.get("crit", false):
				m2.dmg = int(m2.dmg * 1.5)
				m2.stun = int(m2.stun * 1.4)
				m2.crit = true
			var res: String = e.take_hit(self, m2, dir)
			_on_hit(e, move_id, res, int(m2.hitstop))
	if has_hit and perfect_t > 0.0:
		perfect_t = 0.0


## Arme : la zone de frappe suit la lame ; entre deux images on balaie (4 positions intermédiaires) pour ne rien traverser.
func _check_blade() -> void:
	var cur := _blade_points()
	if _blade_prev.size() != cur.size():
		_blade_prev = cur
	var r := float(Weapons.DEFS[weapon].radius) * (1.2 if perfect_t > 0.0 else 1.0)
	for k in 4:
		var s := (k + 1) / 4.0
		for i in cur.size():
			var c: Vector3 = (_blade_prev[i] as Vector3).lerp(cur[i], s)
			if k == 3:
				game.debug_box(c, r)
			for e in game.enemies:
				if e in hit_list or not e.hittable():
					continue
				if e.capsule_hit(c, r):
					hit_list.append(e)
					var dir := facing
					var m2 := mv.duplicate()
					m2.sweep = Moves.SWEEP.get(move_id, 0)
					if perfect_t > 0.0 or mv.get("crit", false):
						m2.dmg = int(m2.dmg * 1.5)
						m2.stun = int(m2.stun * 1.4)
						m2.crit = true
					var res: String = e.take_hit(self, m2, dir)
					if mv.get("bowl", false) and res in ["hit", "counter"]:
						e.thrown_by = self
					_on_hit(e, move_id, res, int(m2.hitstop))
	_blade_prev = cur
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

func _start_dodge(keep_facing := false) -> bool:
	if dodges >= DODGE_CHAIN and dodge_cool > 0.0:
		return false
	dodges += 1
	dodge_cool = DODGE_COOL + 0.3
	var d := stick_world()
	sprinting = false
	if keep_facing:
		# esquive en garde : on reste face à l'ennemi, l'animation dépend de la direction
		dodge_dir = d.normalized() if d.length() > 0.2 else -facing
		var fw := dodge_dir.dot(facing)
		var rt := dodge_dir.dot(facing.cross(Vector3.UP))
		var nm := ("forward" if fw > 0 else "backward") if absf(fw) >= absf(rt) else ("right" if rt > 0 else "left")
		_go("dodge")
		invuln = 0
		var a := "mx/move__dodge_" + nm
		var L: float = float(mx_info.get("move__dodge_" + nm, {}).get("length", 1.0))
		rig.play(a, 0.03, L * 0.7 / (DODGE_F / 60.0), 0.05)
	else:
		dodge_dir = d.normalized() if d.length() > 0.2 else facing
		facing = dodge_dir
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
			_start_attack(_wmove("dodge_attack", "dash_punch"))
			return
		if Inputs.buffered("heavy"):
			_start_attack(_wmove("dodge_heavy", "slide"))
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
		_start_attack(_wmove("air", "air_jab"))
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
	guard_step = ""
	if weapon != "":
		rig.play(_wanim("block", "block"), 0.06, 1.0, 0.25)
	else:
		rig.play("mx/guard__to_block_idle", 0.06, 1.0)
	rig.flash(0.06, Color(0.4, 0.7, 1.0))


func parrying() -> bool:
	return state == "guard" and guard_f <= PARRY_F


func _st_guard(dt: float) -> void:
	guard_f += 1
	if weapon != "" and f == 8 and _wanim("block", "block") == "block":
		rig.set_speed(0.0)
	var d := stick_world()
	hvel = hvel.move_toward(d * GUARD_WALK, ACCEL * dt)
	velocity.y = -2.0
	# pas de boxe en garde (Mixamo « Boxing Step ») selon la direction, sans se retourner
	if weapon == "" and f > 8:
		var st := ""
		if d.length() > 0.3:
			var fw := d.dot(facing)
			var rt := d.dot(facing.cross(Vector3.UP))
			st = ("forward" if fw > 0 else "back") if absf(fw) >= absf(rt) else ("right" if rt > 0 else "left")
		if st != guard_step or (st != "" and rig.pos() >= rig.length() - 0.05):
			guard_step = st
			if st == "":
				rig.play("mx/guard__to_block_idle", 0.12, 1.0, 0.3)
			else:
				rig.play("mx/move__boxing_step_" + st, 0.1, 1.5, 0.05)
	if not Inputs.held("guard"):
		guard_cool = 0.35
		_go("move")
		return
	if Inputs.buffered("dodge"):
		# en garde : esquive dans la direction du stick sans se retourner (Mixamo « Dodge » 4 directions)
		_start_dodge(true)
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
			if weapon == "":
				rig.play("mx/guard__high_center_block", 0.03, 2.2, 0.2)
				guard_step = "hit"
			game.parry(self, attacker)
			return "parry"
		hvel = kb.normalized() * 4.0
		hitstop = 5
		if weapon == "":
			rig.play("mx/guard__block_reaction", 0.03, 2.0, 0.1)
			guard_step = "hit"
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
		fall_up = kb.dot(facing) <= 0.0      # v0.114 : poussé vers l'arrière = sur le dos (décidé par le coup, pas par la chute)
		getup_glide = {}
		velocity.y = 4.0
		rig.play("knockback", 0.03, 1.4)
		if game.ragdoll_on:
			rag.start(Vector3(kb.x, 2.0, kb.z) * 0.7, true)   # ragdoll visuel : le bassin suit la capsule pendant la chute
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
	if rag.active:
		if down_f < 14:
			rag.pin(global_position + Vector3.UP * 0.95, dt)
		elif down_f == 14:
			rag.pinned = false
			rag.damp(0.4)
		elif getup_glide.is_empty():
			rag.tether(global_position, dt)     # au sol : le corps reste près de la capsule (jamais l'inverse)
	if down_f == 40:
		invuln = 40
		if rag.active:
			# relevé (règle de Paul) : le corps glisse vers la capsule, puis l'animation démarre ; dos / ventre = sens du coup
			getup_glide = rig.getup_start(fall_up, "getup", 0.0, "cmu/getup_front", 0.0)
		else:
			rig.play("getup", 0.15, 2.4, 0.5)
	if not getup_glide.is_empty() and (rag.glide(getup_glide.pelvis, dt) or down_f >= 48):
		rig.play(getup_glide.anim, 0.0, 2.0 if fall_up else 1.6, getup_glide.from)
		rag.blend_out(0.2)
		getup_glide = {}
	# relevé rapide : B ou A au sol
	if down_f > 22 and down_f < 40 and (Inputs.buffered("dodge") or Inputs.buffered("jump")):
		invuln = 20
		getup_glide = {}
		if rag.active:
			rag.blend_out(0.12)     # la capsule reste où elle est : le corps la rejoint
		_start_dodge()
		return
	if down_f >= 75:
		_go("move")


# ------------------------------------------------------------------ chope (v0.112 : on le tient)

func _start_grab() -> void:
	_go("grab")
	grabbed = null
	grab_mode = ""
	in_combat_t = 4.0
	var want := stick_world()
	if want.length() > 0.2:
		facing = want.normalized()
	rig.play("throw", 0.05, 1.4, 0.02)
	rig.set_speed(1.0)


func _st_grab(dt: float) -> void:
	var g := Moves.GRAB
	if grab_mode != "hold":
		hvel = hvel.move_toward(Vector3.ZERO, DECEL * dt)
	velocity.y = -2.0
	if grabbed == null and grab_mode == "":
		if f == int(g.startup):
			var t = _pick_target(facing, float(g.reach), 0.9)
			if t and t.grabbable():
				var to: Vector3 = t.global_position - global_position
				to.y = 0
				if to.length() < float(g.reach):
					facing = to.normalized()
					grabbed = t
					t.grab_by(self)
					grab_mode = "hold"
					grab_f = 0
					pummel_cd = 0
					f = 0
					# v0.114 : « Superhuman Choke Lift » : il le saisit à la gorge et le soulève à bout de bras (le sbire pend en ragdoll)
					rig.play(GRAB_LIFT, 0.06, LIFT_SPEED, LIFT_FROM)
					game.sfx.play("grab", global_position, 0.7)
					game.popup(global_position + Vector3.UP * 2.3, "CHOPE !", Color(1, 0.85, 0.4))
					hitstop = 4
					return
		if f >= int(g.startup) + int(g.whiff):
			_go("move")
		return
	match grab_mode:
		"hold": _grab_hold(dt)
		"slam": _grab_slam()
		"throw": _grab_throw()


## Tenu (v0.114) : il le saisit à la gorge et le soulève d'une main (Mixamo « Superhuman Choke Lift ») ; le sbire pend en ragdoll
## visuel, la tête dans la main du héros. On peut marcher (jambes de la marche, bras levé gardé par-dessus : Rig.set_overlay).
## Y = l'éclater au sol, RB = projection d'épaule : animations à deux (attaquant + victime enregistrés ensemble, Mixamo).
const GRAB_LIFT := "mx/grab__superhuman_choke_lift"
const LIFT_FROM := 1.25        # s : il tend la main
const LIFT_HOLD := 3.05        # s : bras levé, sbire à bout de bras (pose tenue)
const LIFT_SPEED := 2.4
const GRAB_WALK_ANIM := "walk"
const GRAB_WALK := 2.3         # m/s : on peut marcher en le tenant (v0.113)
const ARM_R: Array[String] = ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "thumb_01_r", "thumb_02_r", "thumb_03_r",
	"index_01_r", "index_02_r", "index_03_r", "middle_01_r", "middle_02_r", "middle_03_r", "ring_01_r", "ring_02_r", "ring_03_r",
	"pinky_01_r", "pinky_02_r", "pinky_03_r"]
# animations à deux : [attaquant, victime, départ (s), instant de l'impact / du lâcher (s), vitesse, calage]
# calage "front" : la victime au départ est devant le héros ; "back" : la victime au lâcher est pile dans son dos
const PAIR_SLAM := ["mx/grab__hell_slammer_a", "mx/grab__hell_slammer_b", 4.4, 5.95, 1.7, "front"]
const PAIR_THROW := ["mx/grab__shoulder_throw_aggressor", "mx/grab__shoulder_throw_victim", 2.0, 3.35, 1.5, "back"]
var pair_hit_f := 0


## Où le sbire tenu a la tête (sa capsule reste au sol devant le héros ; seul son ragdoll pend dans la main).
func grip_point() -> Vector3:
	return rig.bone_pos("hand_r") + Vector3.DOWN * 0.08


func _grab_hold(dt: float) -> void:
	var g := Moves.GRAB
	grab_f += 1
	pummel_cd -= 1
	var d := stick_world()
	_turn_to(d, dt, 5.0)
	hvel = hvel.move_toward(d * GRAB_WALK, 20.0 * dt)
	if not is_instance_valid(grabbed):
		_go("move")
		return
	grabbed.global_position = global_position + facing * 0.62
	grabbed.facing = -facing
	var lifted := rig.current != GRAB_LIFT or rig.pos() >= LIFT_HOLD
	if rig.current == GRAB_LIFT and rig.pos() >= LIFT_HOLD:
		rig.set_speed(0.0)
	if lifted and pummel_cd <= int(g.pummel_f) - 14:
		if hvel.length() > 0.4:
			rig.play(GRAB_WALK_ANIM, 0.15, clampf(hvel.length() / 1.4, 0.6, 1.6), 0.0, false)
			rig.set_overlay(GRAB_LIFT, LIFT_HOLD, ARM_R)
		elif rig.current != GRAB_LIFT:
			rig.clear_overlay()
			rig.play(GRAB_LIFT, 0.15, 0.0, LIFT_HOLD)
	if Inputs.buffered("dodge"):
		grabbed.release_grab(Vector3.ZERO)
		grabbed = null
		grab_mode = ""
		_start_dodge()
		return
	if Inputs.buffered("heavy") and lifted:
		grab_mode = "slam"
		_pair_start(PAIR_SLAM)
		game.sfx.play("whoosh_heavy", global_position, 0.6)
		return
	if Inputs.buffered("grab") and lifted:
		grab_mode = "throw"
		# il le jette par-dessus son épaule (il retombe derrière lui) : avec le stick, le héros tourne le dos à la cible
		var aim := stick_world()
		if aim.length() > 0.5:
			facing = -aim.normalized()
		_pair_start(PAIR_THROW)
		return
	if Inputs.buffered("attack") and pummel_cd <= 0 and lifted:
		pummel_cd = int(g.pummel_f)
		# coups de poing de la main libre, le bras qui tient reste levé
		rig.play("jab" if combo % 2 == 0 else "cross", 0.04, 1.8, 0.06)
		rig.set_overlay(GRAB_LIFT, LIFT_HOLD, ARM_R)
		grabbed.pummeled(self, float(g.pummel_dmg))
		_on_hit(grabbed, "pummel", "hit", 4)
		game.sfx.play("light", grabbed.global_position + Vector3.UP * 1.2, 0.6)
		game.fx.spark(grip_point() + Vector3.DOWN * 0.45, facing, 0.4, Color(1, 0.9, 0.55))
		return
	if grab_f >= int(g.hold_max):
		# trop long : il se dégage (comme la chope de Smash Bros)
		grabbed.escape_grab(facing)
		grabbed = null
		grab_mode = ""
		hvel = -facing * 4.0
		_go("hurt")
		stun = 16
		rig.play("hit_chest", 0.05, 1.4)
		game.popup(global_position + Vector3.UP * 2.3, "IL SE DÉGAGE", Color(1, 0.6, 0.5))


## Animation à deux : les deux modèles jouent leur moitié depuis la même origine. Le repère de la paire est tourné et posé
## pour que l'attaquant soit sur la capsule du héros et que la victime soit devant lui (là où il la tenait).
func _pair_start(pr: Array) -> void:
	var a: String = pr[0]
	var b: String = pr[1]
	var t_s: float = pr[2]
	var pa: Vector3 = (rig.pose_at(a, t_s)["pelvis"] as Transform3D).origin
	var back: bool = pr[5] == "back"
	var pb: Vector3 = (rig.pose_at(b, float(pr[3]) if back else t_s)["pelvis"] as Transform3D).origin
	var d := Vector3(pb.x - pa.x, 0, pb.z - pa.z)
	var want := -facing if back else facing
	var yaw := atan2(want.x, want.z) - atan2(d.x, d.z)
	f = 0
	hvel = Vector3.ZERO
	pair_on = true
	pair_hit_f = int(round((float(pr[3]) - t_s) / float(pr[4]) * 60.0))
	rig.clear_overlay()
	rig.rotation = Vector3(0, yaw, 0)
	rig.position = -(Basis(Vector3.UP, yaw) * Vector3(pa.x, 0, pa.z))
	rig.play(a, 0.12, float(pr[4]), t_s)
	if is_instance_valid(grabbed):
		grabbed.pair_play(b, t_s, float(pr[4]), rig.global_transform)


## Fin de l'animation à deux : l'animation (pas le ragdoll) a déplacé l'attaquant, la capsule le rejoint.
func _pair_end() -> void:
	if not pair_on:
		return
	var pel := rig.bone_pos("pelvis")
	pair_on = false
	rig.position = Vector3.ZERO
	global_position = Vector3(pel.x, global_position.y, pel.z)
	_face_rig()


## Y pendant la chope : Mixamo « Hell Slammer » (attaquant + victime) ; à l'impact il rebondit (jonglable), on peut agir.
func _grab_slam() -> void:
	var g := Moves.GRAB
	if f == pair_hit_f and grabbed and is_instance_valid(grabbed):
		grabbed.pair_end()
		grabbed.slam_by(self, grabbed.global_position)
		grabbed = null
	if f >= pair_hit_f + int(g.slam_recovery) or (f > pair_hit_f + 6 and has_hit):
		grab_mode = ""
		_go("move")


## RB pendant la chope : projection d'épaule (Mixamo « Shoulder Throw », attaquant + victime). Au lâcher, il part dans le sens
## où l'animation l'envoie (par-dessus l'épaule, derrière le héros) et renverse les autres (boule de bowling).
func _grab_throw() -> void:
	var g := Moves.GRAB
	if f == pair_hit_f and grabbed and is_instance_valid(grabbed):
		var v: Vector3 = grabbed.pair_vel
		grabbed.pair_end()
		var kb: Array = g.kb
		# l'animation l'envoie derrière le héros, un peu de biais : on garde l'axe (dans le dos du héros, donc là où visait le stick)
		var dir := -facing
		if Vector2(v.x, v.z).length() > 0.2 and Vector3(v.x, 0, v.z).normalized().dot(dir) < 0.3:
			dir = Vector3(v.x, 0, v.z).normalized()
		grabbed.release_grab(dir * float(kb[0]) + Vector3.UP * float(kb[1]))
		_on_hit(grabbed, "throw", "hit", 8)
		game.shake(0.35)
		game.sfx.play("heavy", global_position, 0.8)
		grabbed = null
	if f >= pair_hit_f + int(g.recovery):
		grab_mode = ""
		_go("move")


## Appelé par le mannequin quand il touche le sol après l'éclatement.
func slam_landed(e: Node) -> void:
	has_hit = true
	combo += 1
	combo_t = 1.2
	hitstop = 10
	rig.freeze(10 / 60.0)
	hit_landed.emit(e, "slam", "hit")


# ------------------------------------------------------------------ rebords (v0.112)
## D'après Climbing Physics Prototype (teitasan/climbing_physics_prototype, MIT) : un rayon horizontal trouve le mur et sa
## normale, un rayon vertical juste derrière la face trouve le dessus ; une capsule vérifie qu'on tient debout en haut.
## Réglages repris de son GameFeel : vitesse le long du rebord 1,85 m/s, se hisser ~0,6 s, lâcher = 0,3 s sans réagripper.

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func _free_at(feet: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	q.shape = cap
	q.transform = Transform3D(Basis(), feet + Vector3.UP * 0.86)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Rebord devant (direction `dir`) depuis `from` (pieds). Retourne {} ou {wall, n, top, rel, stand, can_stand}.
func find_ledge(dir: Vector3, from: Vector3) -> Dictionary:
	dir.y = 0
	if dir.length() < 0.1:
		return {}
	dir = dir.normalized()
	for h in [-0.35, 0.05, 0.5, 0.95, 1.4, 1.85]:
		var r := _ray(from + Vector3.UP * h - dir * 0.1, from + Vector3.UP * h + dir * 0.85)
		if r.is_empty() or absf(r.normal.y) > 0.4:
			continue
		var n := Vector3(r.normal.x, 0, r.normal.z).normalized()
		var wp: Vector3 = r.position
		var top_r := _ray(Vector3(wp.x - n.x * 0.22, from.y + 3.3, wp.z - n.z * 0.22), Vector3(wp.x - n.x * 0.22, from.y + 0.3, wp.z - n.z * 0.22))
		if top_r.is_empty() or top_r.normal.y < 0.7:
			continue
		var top: float = top_r.position.y
		var stand := Vector3(wp.x - n.x * 0.5, top + 0.02, wp.z - n.z * 0.5)
		return {"wall": wp, "n": n, "top": top, "rel": top - from.y, "stand": stand, "can_stand": _free_at(stand)}
	return {}


func _try_ledge() -> bool:
	if drop_lock > 0.0:
		return false
	var s := stick_world()
	if s.length() < 0.3:
		return false
	var L := find_ledge(s, global_position)
	if L.is_empty() or s.normalized().dot(-L.n) < 0.5:
		return false
	var hs := Vector2(hvel.x, hvel.z).length()
	if L.rel >= 0.2 and L.rel <= VAULT_MAX and hs >= VAULT_SPEED:
		var V := _vault_land(L)
		if not V.is_empty():
			_start_climb(L, "vault", V)
			return true
	# v0.113 : avec de l'élan, un mur de 2 à 3,6 m se monte en courant (Mixamo « Runs Up A Wall Onto A Platform »)
	var wall_h: float = L.top - last_ground_y
	if jump_speed >= 5.0 and hs >= 4.0 and wall_h >= 2.0 and wall_h <= RUNUP_MAX and L.can_stand:
		_start_climb(L, "runup")
		return true
	if L.rel >= 0.2 and L.rel <= MANTLE_MAX and L.can_stand:
		_start_climb(L, "mantle")
		return true
	if L.rel > MANTLE_MAX and L.rel <= HANG_REACH:
		if L.top - hang_h > last_ground_y + 0.15:
			_start_hang(L)
		elif L.can_stand:
			_start_climb(L, "mantle")
		else:
			return false
		return true
	return false


## Obstacle bas et fin, franchi en courant : point de réception de l'autre côté, ou {} s'il est trop épais.
func _vault_land(L: Dictionary) -> Dictionary:
	var n: Vector3 = L.n
	var beyond: Vector3 = L.wall - n * VAULT_DEPTH
	var r := _ray(Vector3(beyond.x, L.top + 0.4, beyond.z), Vector3(beyond.x, global_position.y - 1.5, beyond.z))
	if r.is_empty() or r.position.y > L.top - 0.3:
		return {}
	var land := Vector3(L.wall.x - n.x * (VAULT_DEPTH + 0.6), r.position.y, L.wall.z - n.z * (VAULT_DEPTH + 0.6))
	if not _free_at(land + Vector3.UP * 0.05):
		return {}
	return {"land": land}


## En courant contre un obstacle bas et fin, on le franchit sans sauter (Mixamo « Jumping Over An Obstacle With 2 Hands »).
func _try_vault_ground() -> bool:
	var hs := Vector2(hvel.x, hvel.z).length()
	if hs < VAULT_SPEED:
		return false
	var dir := Vector3(hvel.x, 0, hvel.z).normalized()
	var L := find_ledge(dir, global_position)
	if L.is_empty() or L.rel < 0.4 or L.rel > VAULT_MAX or dir.dot(-L.n) < 0.6:
		return false
	if (L.wall - global_position).length() > 1.2:
		return false
	var V := _vault_land(L)
	if V.is_empty():
		return false
	_start_climb(L, "vault", V)
	return true


func _start_hang(L: Dictionary) -> void:
	ledge = L
	_go("hang")
	hang_push = 0
	facing = -L.n
	hvel = Vector3.ZERO
	velocity = Vector3.ZERO
	air_dash_used = false
	air_attacks = 0
	global_position = Vector3(L.wall.x + L.n.x * 0.36, L.top - hang_h, L.wall.z + L.n.z * 0.36)
	# Mixamo « Hanging By Hands Against Wall » (pieds contre le mur) ; le modèle avance pour que les mains soient au bord
	rig.play(HANG_ANIM, 0.1, 1.0)
	rig.position = facing * 0.2
	game.sfx.play("land", global_position + Vector3.UP * 2.0, 0.4)


func _st_hang(_dt: float) -> void:
	hvel = Vector3.ZERO
	velocity = Vector3.ZERO
	var n: Vector3 = ledge.n
	var s := stick_world()
	var right := facing.cross(Vector3.UP).normalized()
	var lat := s.dot(right)
	var moving := false
	if absf(lat) > 0.3:
		var step := right * signf(lat) * SHIMMY / 60.0 * absf(lat)
		var probe := global_position + right * signf(lat) * 0.3 + Vector3.UP * (hang_h - 1.4)
		var L2 := find_ledge(-n, Vector3(probe.x, ledge.top - 1.4, probe.z) + n * 0.1)
		if not L2.is_empty() and absf(L2.top - ledge.top) < 0.3 and L2.n.dot(n) > 0.8:
			global_position += step
			ledge.top = L2.top
			ledge.wall = Vector3(global_position.x - n.x * 0.36, L2.wall.y, global_position.z - n.z * 0.36)
			ledge.stand = L2.stand - right * signf(lat) * 0.3
			ledge.can_stand = L2.can_stand
			moving = true
			# Mixamo « Braced Hang Shimmy » gauche / droite
			rig.play("mx/ledge__braced_shimmy_" + ("right" if lat > 0 else "left"), 0.12, absf(lat) * 1.3, 0.0, false)
	if not moving and rig.current != HANG_ANIM and f > 6:
		rig.play(HANG_ANIM, 0.15, 1.0, 0.0, false)
	if Inputs.buffered("jump"):
		if s.dot(n) > 0.5:
			# saut en arrière, dos au mur (Mixamo « Hanging On Wall To Jump Off »)
			velocity = n * 5.5 + Vector3.UP * 7.0
			hvel = Vector3(velocity.x, 0, velocity.z)
			facing = n
			drop_lock = 0.3
			_go("air")
			rig.play("mx/ledge__jump_from_wall", 0.05, 1.8, 0.35)
		elif ledge.can_stand:
			_start_climb(ledge, "hang")
		else:
			velocity = Vector3.UP * 5.0
			drop_lock = 0.3
			_go("air")
		return
	if s.dot(-n) > 0.6:
		hang_push += 1
		if hang_push > 12 and ledge.can_stand and f > 10:
			_start_climb(ledge, "hang")
			return
	else:
		hang_push = 0
	if Inputs.buffered("dodge") or (s.dot(n) > 0.7 and f > 10 and not Inputs.held("jump")):
		hvel = n * 1.5
		velocity = Vector3(hvel.x, -0.5, hvel.z)
		drop_lock = 0.35
		_go("air")
		rig.play("mx/move__falling_idle", 0.15)


## Se hisser / franchir (la capsule suit un chemin, collision coupée) :
##  - "hang" : depuis l'agrippe, Mixamo « Climb Wall From Braced Hang To Crouch » (le corps monte dans l'animation, la capsule
##    avance vers le haut du rebord puis s'y pose à la fin) ;
##  - "mantle" : rebord bas, Quaternius ClimbUp_1m ;
##  - "runup" : mur un peu trop haut pour s'agripper, avec de l'élan : Mixamo « Runs Up A Wall Onto A Platform » ;
##  - "vault" : obstacle bas et fin en courant : Mixamo « Jumping Over An Obstacle With 2 Hands Planted ».
func _start_climb(L: Dictionary, kind: String, V := {}) -> void:
	ledge = L.duplicate()
	if not V.is_empty():
		ledge.land = V.land
	climb_kind = kind
	_go("climb")
	climb_f = 0
	facing = -L.n
	var keep := Vector3(hvel.x, 0, hvel.z)
	hvel = Vector3.ZERO
	velocity = Vector3.ZERO
	col_shape.disabled = true
	climb_start = global_position
	match kind:
		"hang":
			climb_end = 50
			rig.play("mx/ledge__braced_hang_to_crouch", 0.08, 1.13 / (climb_end / 60.0))
		"runup":
			climb_end = 46
			rig.play("mx/wall__wall_run_up_platform", 0.06, (2.0 - 0.35) / (climb_end / 60.0), 0.35)
		"vault":
			climb_end = 34
			ledge.keep = keep.length()
			rig.play("mx/wall__vault_two_hands", 0.05, (1.15 - 0.15) / (climb_end / 60.0), 0.15)
		_:
			climb_end = int(lerpf(20, 30, clampf((L.rel - 0.45) / 1.4, 0, 1)))
			rig.play("climb_up", 0.06, 0.667 / (climb_end / 60.0))
	game.sfx.play("jump", global_position, 0.5)


func _st_climb(_dt: float) -> void:
	climb_f += 1
	hvel = Vector3.ZERO
	velocity = Vector3.ZERO
	var n: Vector3 = ledge.n
	var u := clampf(float(climb_f) / climb_end, 0.0, 1.0)
	var sm := u * u * (3.0 - 2.0 * u)
	match climb_kind:
		"hang":
			rig.position = facing * 0.2 * (1.0 - u)
			var k := clampf((u - 0.35) / 0.6, 0.0, 1.0)
			var p := climb_start.lerp(ledge.stand, k)
			global_position = Vector3(p.x, climb_start.y, p.z)
		"runup":
			var base := Vector3(ledge.wall.x + n.x * 0.35, climb_start.y, ledge.wall.z + n.z * 0.35)
			var up := Vector3(ledge.wall.x + n.x * 0.3, ledge.top, ledge.wall.z + n.z * 0.3)
			if u < 0.25:
				global_position = climb_start.lerp(base, u / 0.25)
			elif u < 0.75:
				global_position = base.lerp(up, (u - 0.25) / 0.5)
			else:
				global_position = up.lerp(ledge.stand, (u - 0.75) / 0.25)
		"vault":
			var over := Vector3(ledge.wall.x - n.x * VAULT_DEPTH * 0.5, ledge.top + 0.3, ledge.wall.z - n.z * VAULT_DEPTH * 0.5)
			if u < 0.5:
				global_position = climb_start.lerp(over, sm / 0.5 if sm < 0.5 else 1.0)
			else:
				global_position = over.lerp(ledge.land, (u - 0.5) / 0.5)
		_:
			var mid := Vector3(ledge.wall.x + n.x * 0.12, ledge.top + 0.05, ledge.wall.z + n.z * 0.12)
			if sm < 0.55:
				global_position = climb_start.lerp(mid, sm / 0.55)
			else:
				global_position = mid.lerp(ledge.stand, (sm - 0.55) / 0.45)
	if u >= 1.0:
		global_position = ledge.land if climb_kind == "vault" else ledge.stand
		col_shape.disabled = false
		rig.position = Vector3.ZERO
		_go("move")
		land_lag = 2 if climb_kind != "vault" else 0
		if climb_kind == "vault":
			hvel = facing * maxf(float(ledge.get("keep", RUN)), RUN)
		last_ground_y = global_position.y
		fall_peak = global_position.y


# ------------------------------------------------------------------ course au mur (v0.112, affaiblie en v0.113)
## d'après godot-wall-running (Garbaj, MIT) : en l'air, un mur juste à côté et de l'élan le long du mur = on court dessus ;
## réglages de départ de Vigilante (madebynova), puis réduits sur demande de Paul : 0,7 s, pas de vitesse gratuite, gravité
## qui revient vite, saut de mur plus court, 3 courses au plus avant de retoucher le sol. Animation Mixamo « Wall Run »
## (et son miroir pour l'autre côté).

func _try_wallrun() -> bool:
	if f < 4 or wall_chain >= WR_CHAIN:
		return false
	# v0.114 : pas de course au ras du sol (il prenait le mur à 50 cm et glissait aussitôt jusqu'en bas)
	if global_position.y - last_ground_y < WR_MIN_H:
		return false
	var hv := Vector3(hvel.x, 0, hvel.z)
	if hv.length() < WR_MIN_SPEED:
		return false
	var p := global_position
	var right := hv.normalized().cross(Vector3.UP).normalized()
	for side in [1.0, -1.0]:
		var d: Vector3 = right * side
		var r := _ray(p + Vector3.UP * 1.0, p + Vector3.UP * 1.0 + d * 0.8)
		if r.is_empty() or absf(r.normal.y) > 0.3:
			continue
		var n := Vector3(r.normal.x, 0, r.normal.z).normalized()
		if _ray(p + Vector3.UP * 2.2, p + Vector3.UP * 2.2 + d * 0.95).is_empty():
			continue      # mur trop bas : pas de course (les murets restent des murets)
		if wall_lock > 0.0 and n.dot(last_wall_n) > 0.9:
			continue
		var along := hv - n * hv.dot(n)
		if along.length() < WR_MIN_SPEED * 0.8:
			continue
		if stick_world().dot(n) > 0.7:
			continue
		_start_wallrun(n, along.normalized(), along.length(), side)
		return true
	return false


func _start_wallrun(n: Vector3, dir: Vector3, sp: float, side: float) -> void:
	_go("wallrun")
	wall_chain += 1
	wall_n = n
	wr_dir = dir
	wr_speed = minf(sp * 0.9, WR_SPEED)
	velocity.y = clampf(velocity.y * 0.5 + 2.0, 1.5, 4.5)     # v0.114 : il garde l'élan de son saut (comme en v0.112)
	facing = dir
	air_dash_used = false
	air_attacks = 0
	# « Wall Run » de Mixamo a le mur à gauche (pieds côté +X du modèle) ; mur à droite : son miroir
	rig.play("mx/wall__wall_run" + ("_m" if side > 0 else ""), 0.08, (0.9 - 0.2) / WR_MAX, 0.2)
	game.fx.dust(global_position + Vector3.UP * 1.0 - n * 0.3, 0.5)
	game.sfx.play("land", global_position, 0.4)


func _st_wallrun(dt: float, on_floor: bool) -> void:
	var p := global_position
	var n := wall_n
	if on_floor and f > 2:
		_land()
		return
	var still := _ray(p + Vector3.UP * 1.0, p + Vector3.UP * 1.0 - n * 0.85)
	var t := f / 60.0
	if still.is_empty() or t > WR_MAX:
		last_wall_n = n
		wall_lock = 0.3
		hvel = wr_dir * wr_speed * 0.7 + n * 1.5
		_go("air")
		rig.play("mx/move__falling_idle", 0.15)
		return
	wr_speed = maxf(wr_speed - 4.0 * dt, 3.0)
	hvel = wr_dir * wr_speed - n * 0.6
	velocity.y -= (5.0 if t < 0.35 else 16.0) * dt
	velocity.y = maxf(velocity.y, -4.0)
	# l'animation Mixamo rapproche le bassin du mur d'environ 35 cm : on décale le corps pour que les pieds restent dehors
	rig.position = rig.position.lerp(n * 0.3, minf(1.0, dt * 12.0))
	if Inputs.buffered("jump"):
		last_wall_n = n
		wall_lock = 0.35
		hvel = wr_dir * wr_speed * 0.7 + n * WJ_OUT
		velocity.y = WJ_UP
		wj_t = 0.3
		facing = Vector3(hvel.x, 0, hvel.z).normalized()
		_go("air")
		rig.play("ninja_start", 0.05, 1.6, 0.22)
		game.sfx.play("jump", p, 0.6)
		game.fx.dust(p + Vector3.UP * 1.0 - n * 0.3, 0.7)
		return
	if Inputs.buffered("dodge"):
		last_wall_n = n
		wall_lock = 0.4
		hvel = wr_dir * wr_speed * 0.6 + n * 3.0
		_go("air")
		rig.play("mx/move__falling_idle", 0.15)
		return
	if Inputs.buffered("attack"):
		last_wall_n = n
		wall_lock = 0.4
		_go("air")
		_start_attack(_wmove("air", "air_jab"))
		return
	if Inputs.buffered("heavy"):
		last_wall_n = n
		wall_lock = 0.4
		_go("air")
		_start_attack("air_spike")
		return


# ------------------------------------------------------------------ aperçu (menu) : joue une animation sur place

func preview(anim: String) -> void:
	_go("preview")
	hvel = Vector3.ZERO
	rig.play(anim, 0.1, 1.0)


func _st_preview(_dt: float) -> void:
	hvel = Vector3.ZERO
	velocity.y = -2.0
	if f > 20 and (stick_world().length() > 0.3 or Inputs.buffered("attack") or Inputs.buffered("jump") or Inputs.buffered("dodge")):
		_go("move")
	elif rig.pos() >= rig.length() - 0.02 and rig.length() > 0.0:
		rig.play(rig.current, 0.0, 1.0, 0.0, true)


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


# ------------------------------------------------------------------ overlay : ce qui est possible MAINTENANT
## Calculé avec les mêmes règles que les états ci-dessus (une seule vérité). Chaque entrée :
## {b: bouton ("X","Y","A","B","L1","R1","Ymaint","stick"), t: ce que ça fait, on: possible tout de suite, wait: images avant que ça s'ouvre}
const MOVE_NAMES := {
	"jab": "jab", "cross": "direct", "hook": "coup de coude", "spin_kick": "coup de pied retourné (renverse)",
	"launcher": "uppercut lanceur (envoie en l'air)", "push_kick": "coup de pied poussé (brise la garde)",
	"haymaker": "gros crochet plongeant (renverse, mur)", "charged": "crochet chargé", "dash_punch": "direct plongeant",
	"slide": "glissade qui fauche", "flying_hook": "crochet volant", "air_jab": "jab aérien", "air_cross": "coup de pied latéral",
	"air_kick": "coup de talon qui écrase (rebond)", "ax_jump": "saut à la hache (renverse)", "air_spike": "piqué (onde au sol)", "riposte": "RIPOSTE (uppercut critique)",
	# armes (v0.112)
	"sw_a": "taille", "sw_b": "revers", "sw_c": "grand coup (renverse)", "sw_up": "taille montante (envoie en l'air)",
	"sw_heavy": "grand coup d'épée (brise la garde, renverse)", "sw_dash": "estocade en avançant", "sw_air": "taille aérienne",
	"sw_air2": "revers aérien", "sw_air3": "coup d'épée qui écrase",
	"ka_a": "coupe", "ka_b": "coupe retour", "ka_c": "coupe finale (renverse)", "ka_rise": "coupe montante (envoie en l'air)",
	"ka_iai": "dégainé éclair (traverse)", "ka_air": "coupe aérienne", "ka_air2": "coupe aérienne retour",
	"ax_chop": "coup de hache (ne bronche pas)", "ax_chop2": "2e coup de hache", "ax_final": "grand coup de hache (brise la garde)",
	"ax_sweep": "balayage à la hache (brise la garde)", "ax_up": "hache montante (envoie en l'air)", "ax_air": "hache qui écrase",
	"bt_a": "coup de batte", "bt_b": "revers de batte", "bt_swing": "HOME RUN (l'envoie loin)", "bt_smash": "batte vers le bas (il rebondit)",
	"bt_up": "batte montante (envoie en l'air)", "bt_air": "coup de batte aérien",
}

func _mn(id: String) -> String:
	return MOVE_NAMES.get(id, id)

func actions() -> Array:
	var out := []
	var dodge_ok := not (dodges >= DODGE_CHAIN and dodge_cool > 0.0)
	match state:
		"move":
			if land_lag > 0:
				out.append({"b": "", "t": "réception…", "on": false, "wait": land_lag})
				return out
			if riposte_t > 0.0:
				out.append({"b": "X", "t": MOVE_NAMES.riposte, "on": true})
			elif sprinting:
				out.append({"b": "X", "t": _mn(_wmove("sprint_attack", "slide")) + " (en sprint)", "on": true})
				out.append({"b": "Y", "t": _mn(_wmove("sprint_heavy", "flying_hook")) + " (en sprint)", "on": true})
			elif weapon != "":
				var chain := []
				var m := _wmove("attack", "jab")
				while m != "" and chain.size() < 4:
					chain.append(_mn(m))
					m = Moves.M[m].chain.get("attack", "")
				out.append({"b": "X", "t": " ▸ ".join(chain), "on": true})
				out.append({"b": "Y", "t": _mn(_wmove("heavy", "push_kick")), "on": true})
			else:
				out.append({"b": "X", "t": "jab ▸ direct ▸ coude ▸ retourné", "on": true})
				out.append({"b": "Y", "t": MOVE_NAMES.push_kick, "on": true})
				out.append({"b": "Ymaint", "t": "maintenu : " + MOVE_NAMES.charged, "on": true})
			out.append({"b": "B", "t": "roulade (invincible au début)" if dodge_ok else "roulade (recharge…)", "on": dodge_ok})
			out.append({"b": "A", "t": "saut", "on": true})
			out.append({"b": "L1", "t": "garde (pile au coup = parade)", "on": true})
			var rk: String = game.arena.rack_near(global_position)
			if rk != "":
				out.append({"b": "R1", "t": ("raccrocher : " if rk == weapon else "prendre : ") + Weapons.DEFS[rk].name, "on": true})
			else:
				var t = _pick_target(facing, float(Moves.GRAB.reach), 0.9)
				out.append({"b": "R1", "t": "chope (tenir 3 s)" if t else "chope (personne à portée)", "on": t != null})
		"air":
			out.append({"b": "X", "t": "combo aérien : jab ▸ pied latéral ▸ talon (écrase)" if weapon == "" else _mn(_wmove("air", "air_jab")) + " ▸ …", "on": air_attacks < 4})
			out.append({"b": "Y", "t": MOVE_NAMES.air_spike, "on": true})
			out.append({"b": "B", "t": "dash aérien", "on": not air_dash_used})
		"attack":
			var su := int(mv.startup)
			var ac := int(mv.active)
			var from: int = maxi(int(mv.get("chain_from", su)), su + ac)
			var air := bool(mv.get("air", false))
			for b in mv.chain:
				var nxt: String = mv.chain[b]
				if air and not Moves.M[nxt].get("air", false):
					continue
				var lab: String = MOVE_NAMES.get(nxt, nxt)
				out.append({"b": "X" if b == "attack" else "Y", "t": lab, "on": f >= from, "wait": maxi(from - f, 0)})
			if mv.get("jump_cancel", false):
				if has_hit:
					out.append({"b": "A", "t": "saut de poursuite ▸ puis X X X en l'air", "on": f >= su + ac, "wait": maxi(su + ac - f, 0)})
				elif f < su + ac:
					out.append({"b": "A", "t": "(s'il touche) saut de poursuite", "on": false, "wait": su + ac - f})
			var dc: String = mv.get("dodge", "active")
			var dlab := "dash aérien" if air else "roulade (annule le coup)"
			if dc == "always":
				out.append({"b": "B", "t": dlab, "on": dodge_ok or air})
			elif dc == "active":
				out.append({"b": "B", "t": dlab, "on": f >= su + ac, "wait": maxi(su + ac - f, 0)})
			elif has_hit:
				out.append({"b": "B", "t": dlab + " (il a touché)", "on": f >= su + ac, "wait": maxi(su + ac - f, 0)})
			else:
				out.append({"b": "B", "t": "roulade seulement si le coup touche", "on": false})
			if out.is_empty():
				out.append({"b": "", "t": "coup engagé : pas d'annulation", "on": false})
		"charge":
			out.append({"b": "Ymaint", "t": "relâcher Y : frapper (%d %%)" % int(clampf(charge_t / CHARGE_MAX, 0, 1) * 100), "on": true})
			out.append({"b": "B", "t": "roulade (annule la charge)", "on": true})
		"dodge":
			out.append({"b": "X", "t": MOVE_NAMES.dash_punch, "on": f >= DODGE_ATTACK_F, "wait": maxi(DODGE_ATTACK_F - f, 0)})
			out.append({"b": "Y", "t": MOVE_NAMES.slide, "on": f >= DODGE_ATTACK_F, "wait": maxi(DODGE_ATTACK_F - f, 0)})
			out.append({"b": "B", "t": "2e roulade" if dodges < DODGE_CHAIN else "roulade (recharge…)", "on": f >= DODGE_F - 4 and dodges < DODGE_CHAIN, "wait": maxi(DODGE_F - 4 - f, 0)})
			out.append({"b": "A", "t": "saut", "on": f >= DODGE_F - 4, "wait": maxi(DODGE_F - 4 - f, 0)})
		"airdash":
			out.append({"b": "X", "t": MOVE_NAMES.air_jab, "on": f >= 6 and air_attacks < 4, "wait": maxi(6 - f, 0)})
			out.append({"b": "Y", "t": MOVE_NAMES.air_spike, "on": f >= 6, "wait": maxi(6 - f, 0)})
		"guard":
			out.append({"b": "L1", "t": "PARADE active (%d images)" % maxi(PARRY_F - guard_f, 0) if parrying() else "garde (bloque de face)", "on": true})
			if riposte_t > 0.0:
				out.append({"b": "X", "t": MOVE_NAMES.riposte, "on": true})
			out.append({"b": "B", "t": "roulade", "on": dodge_ok})
			out.append({"b": "R1", "t": "chope", "on": true})
		"grab":
			if grabbed and grab_mode == "hold":
				out.append({"b": "", "t": "tenu : encore %.1f s" % maxf((int(Moves.GRAB.hold_max) - grab_f) / 60.0, 0.0), "on": false})
				out.append({"b": "Y", "t": "l'ÉCLATER au sol (il rebondit : jongle)", "on": true})
				out.append({"b": "X", "t": "coups pendant la chope", "on": pummel_cd <= 0, "wait": maxi(pummel_cd, 0)})
				out.append({"b": "R1", "t": "le lancer (stick = direction)", "on": true})
				out.append({"b": "B", "t": "lâcher et rouler", "on": true})
			elif grab_mode == "slam":
				out.append({"b": "X", "t": "après l'impact : uppercut / saut + combo", "on": has_hit})
			elif grabbed:
				out.append({"b": "stick", "t": "choisir la direction du lancer", "on": true})
			else:
				out.append({"b": "", "t": "chope ratée : récupération", "on": false})
		"hang":
			out.append({"b": "A", "t": "se hisser" if ledge.get("can_stand", false) else "pas de place en haut", "on": ledge.get("can_stand", false)})
			out.append({"b": "stick", "t": "gauche / droite : se déplacer le long du rebord", "on": true})
			out.append({"b": "A", "t": "stick dos au mur + A : saut en arrière", "on": true})
			out.append({"b": "B", "t": "lâcher", "on": true})
		"climb":
			out.append({"b": "", "t": "se hisse…", "on": false})
		"wallrun":
			out.append({"b": "A", "t": "saut de mur (vers le mur d'en face)", "on": true})
			out.append({"b": "X", "t": "attaque aérienne (quitte le mur)", "on": true})
			out.append({"b": "Y", "t": MOVE_NAMES.air_spike, "on": true})
			out.append({"b": "B", "t": "lâcher le mur", "on": true})
		"hurt":
			out.append({"b": "B", "t": "roulade de sortie (fin de l'étourdissement)", "on": f > stun - 6, "wait": maxi(stun - 6 - f, 0)})
		"down":
			out.append({"b": "B", "t": "relevé rapide (roulade)", "on": down_f > 22 and down_f < 40, "wait": maxi(23 - down_f, 0)})
			out.append({"b": "A", "t": "relevé rapide", "on": down_f > 22 and down_f < 40, "wait": maxi(23 - down_f, 0)})
	return out


## Indice de situation (ennemi en l'air, sonné…) d'après l'état réel des mannequins proches.
func situation_hint() -> String:
	if state == "move":
		var rk: String = game.arena.rack_near(global_position)
		if rk != "":
			return ("RB : raccrocher " if rk == weapon else "RB : prendre ") + Weapons.DEFS[rk].name.to_lower()
	if state == "wallrun":
		return "Course au mur : A = saut vers le mur d'en face"
	if state == "hang":
		return "Agrippé : A = se hisser, gauche / droite = se déplacer, B = lâcher"
	if state == "grab" and grab_mode == "hold":
		return "Tu le tiens : Y = l'éclater au sol, X = frapper, R1 = lancer"
	for e in game.enemies:
		var d: Vector3 = e.global_position - global_position
		d.y = 0
		if d.length() > 4.0:
			continue
		match e.state:
			"stagger": return "Ennemi sonné : frappe-le, tous tes coups passent"
			"air": return "Ennemi en l'air : saute (A) pour le jongler" if state in ["move"] else "Ennemi en l'air : continue le jongle"
			"down": return "Ennemi au sol : seuls la glissade (roulade + Y / sprint + X) et le piqué le touchent"
			"windup":
				if e.atk.get("heavy", false):
					return "Coup lourd (orange) : esquive (B) ou parade (L1 pile au coup)"
				return "Il prépare un coup (rouge) : garde, parade ou esquive"
			"block": return "Il bloque : coup de pied poussé (Y) ou chope (R1) pour passer la garde"
	return ""

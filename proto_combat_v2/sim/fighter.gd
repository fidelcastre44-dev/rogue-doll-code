class_name Fighter
extends CharacterBody3D
## Un combattant de la SIMULATION (héros ou sbire) : une capsule (1,75 m) qui ne dépend jamais de l'affichage.
## Tout est compté en images (60 / s). L'état, le coup en cours, les points de vie, la direction regardée, la vitesse :
## c'est la vérité du jeu. Le « cerveau » (HeroBrain ou DummyBrain) décide des actions à partir de la commande de l'image ;
## ce fichier tient le tronc commun : déplacement de la capsule, coups (images, zone de frappe), réactions aux coups,
## figé à l'impact (par personnage, jamais sur le temps du jeu), événements pour l'affichage.

const RADIUS := 0.35
const HEIGHT := 1.75
const FPS := 60.0

var id := 0
var team := 0                 # 0 = joueurs, 1 = sbires
var kind := "hero"            # hero | dummy
var model := "male"           # male | female | dummy (affichage)
var world: SimWorld
var brain: RefCounted

var hp := 100.0
var hp_max := 100.0
var state := "idle"
var f := 0                    # images passées dans l'état
var move_id := ""
var mv := {}                  # fiche du coup en cours
var hits_done := []           # cibles déjà touchées par ce coup
var hit_landed := false
var facing := Vector3(0, 0, -1)
var hvel := Vector3.ZERO      # vitesse horizontale (m/s)
var grounded := true
var freeze := 0               # images de figé (hitstop)
var slow := 0                 # images de ralenti (une image sur deux)
var _slow_skip := false
var stun := 0                 # images d'étourdissement restantes (hurt, stagger)
var juggle := 0               # coups reçus en l'air d'affilée
var fall_up := true           # tombera sur le dos (sinon à plat ventre)
var downs := 0                # chutes d'affilée (3e relevé = roulade rapide)
var invincible := false
var armor := false
var guarding := false
var lunge_left := 0.0         # élan restant (m) pendant armé + actif
var lunge_per := 0.0
var hang := 0.0
var ko := false
var crit_next := false
var events: Array = []        # [{type, ...}] pour l'affichage, vidés chaque image par le monde
var grabbed_by: Fighter = null
var holding: Fighter = null
var pair_offset := Vector3.ZERO
var last_hit := {}            # dernier coup reçu (pour l'affichage : réaction)
var seed_roll := 0.0          # tirage partagé (réactions)


func setup(world_: Node, id_: int, team_: int, kind_: String, model_: String) -> void:
	world = world_
	id = id_
	team = team_
	kind = kind_
	model = model_
	name = "%s_%d" % [kind, id]
	collision_layer = 2 if team == 0 else 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)


func emit(type: String, data := {}) -> void:
	data["type"] = type
	events.append(data)


func go(s: String) -> void:
	if state != s:
		emit("state", {"from": state, "to": s})
	state = s
	f = 0


func on_floor() -> bool:
	return grounded


func pos() -> Vector3:
	return global_position


func centre() -> Vector3:
	return global_position + Vector3.UP * (HEIGHT * 0.5)


func face_to(dir: Vector3) -> void:
	dir.y = 0
	if dir.length() > 0.001:
		facing = dir.normalized()


## Tourne vers `dir` à la vitesse de rotation réglée (demi-tour en ~5 images).
func turn_towards(dir: Vector3, rate := -1.0) -> void:
	dir.y = 0
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var r := Tuning.v("turn_rate") if rate < 0 else rate
	var a := facing.signed_angle_to(dir, Vector3.UP)
	var step := r / FPS
	if absf(a) <= step:
		facing = dir
	else:
		facing = facing.rotated(Vector3.UP, signf(a) * step).normalized()


# ------------------------------------------------------------------ image de simulation

## Une image : figé / ralenti, puis le cerveau, puis la physique de la capsule.
func step(cmd) -> void:
	if freeze > 0:
		freeze -= 1
		brain.note(cmd)      # les appuis pendant le figé ne sont pas perdus (tampon)
		return
	if slow > 0:
		slow -= 1
		_slow_skip = not _slow_skip
		if _slow_skip:
			brain.note(cmd)
			return
	f += 1
	if lunge_left > 0.0 and lunge_per > 0.0:
		# élan du coup : la vitesse horizontale est celle de l'élan (pas un ajout), jusqu'à la fin de l'armé + actif
		var d := minf(lunge_per, lunge_left)
		lunge_left -= d
		hvel = facing * d * FPS
		if lunge_left <= 0.0001:
			lunge_left = 0.0
			hvel = Vector3.ZERO if grounded else hvel * 0.3
	brain.tick(cmd)
	_integrate()


func _integrate() -> void:
	var g := Tuning.v("grav_up") if velocity.y > 0 else Tuning.v("grav_down")
	if state == "air_hit" or (state == "attack" and mv.get("air", false) and not mv.get("dive", false) and hang > 0.0):
		g = Tuning.v("juggle_grav")     # pendant un jongle, l'attaquant et la cible retombent au même rythme
	if state in ["grabbed", "pair", "held"]:
		velocity = Vector3.ZERO
		hvel = Vector3.ZERO
		grounded = true
		return
	# au sol les capsules se bloquent entre elles ; en l'air, tenu ou projeté, un perso traverse les autres (jongles, chopes)
	var ghost := not grounded or velocity.y > 0.0 or state in ["air_hit", "held", "hold"]
	collision_layer = 0 if ghost else (2 if team == 0 else 4)
	collision_mask = 1 if ghost else (1 | 2 | 4)
	velocity.x = hvel.x
	velocity.z = hvel.z
	if not grounded or velocity.y > 0.0:
		velocity.y -= g / FPS
	elif velocity.y < 0:
		velocity.y = 0
	move_and_slide()
	grounded = is_on_floor()
	if grounded and velocity.y < 0:
		velocity.y = 0
	hvel.x = velocity.x
	hvel.z = velocity.z


## Frottement au sol vers la vitesse voulue (accélération / freinage très vifs : pleine vitesse en 6 images).
func drive(want: Vector3) -> void:
	want.y = 0
	var a := (Tuning.v("accel") if want.length() > hvel.length() else Tuning.v("decel")) / FPS
	hvel = hvel.move_toward(want, a)


func brake(rate := -1.0) -> void:
	var a := (Tuning.v("decel") if rate < 0 else rate) / FPS
	hvel = hvel.move_toward(Vector3.ZERO, a)


# ------------------------------------------------------------------ coups

## Démarre un coup (fiche de data/moves.gd). `lunge_override` = élan voulu (aide à la visée).
func start_move(idm: String, lunge_override := -1.0) -> void:
	mv = Moves.get_move(idm)
	move_id = idm
	hits_done = []
	hit_landed = false
	go("attack")
	var l := float(mv.get("lunge", 0.0)) * Tuning.v("lunge_scale")
	if lunge_override >= 0.0:
		l = lunge_override
	lunge_left = l
	lunge_per = l / maxf(float(mv.startup + mv.active), 1.0)
	armor = bool(mv.get("armor", false))
	hang = float(mv.get("hang", 0.0))
	if not mv.get("keep_momentum", false) and bool(mv.get("air", false)):
		hvel *= 0.4
	emit("move", {"move": idm})


func move_phase() -> String:
	if state != "attack":
		return ""
	if f <= int(mv.startup):
		return "startup"
	if f <= int(mv.startup) + int(mv.active):
		return "active"
	return "recovery"


func move_done() -> bool:
	return state == "attack" and f >= Moves.total(mv)


## Sphère de frappe de cette image (monde) ou [] si le coup ne touche pas en ce moment.
func hit_sphere() -> Array:
	if move_phase() != "active":
		return []
	var b: Array = mv.box
	var fwd := float(b[0])
	if mv.get("sweep", false):
		var k := float(f - int(mv.startup)) / maxf(float(mv.active), 1.0)
		fwd += k * 0.6
	var c := global_position + facing * fwd + Vector3.UP * float(b[1])
	return [c, float(b[2])]


## La capsule est-elle touchée par la sphère (centre, rayon) ?
func capsule_hit(c: Vector3, r: float, low := false) -> bool:
	var a := global_position + Vector3.UP * RADIUS
	var b := global_position + Vector3.UP * (HEIGHT - RADIUS)
	if low and state == "air_hit" and global_position.y > 0.9:
		return false
	var ab := b - a
	var t := clampf((c - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var p := a + ab * t
	return p.distance_to(c) <= r + RADIUS


func hittable() -> bool:
	return not invincible and not ko and state not in ["pair", "held", "grabbed"] and not (state == "down" and f < 6)


func targetable() -> bool:
	return not ko and state not in ["pair", "held", "grabbed"]


func grabbable() -> bool:
	return targetable() and state not in ["air_hit", "down", "getup", "roll"] and grounded


# ------------------------------------------------------------------ réactions aux coups
## Reçoit un coup. Renvoie "hit" | "block" | "parry" | "armor" | "miss". `dir` = sens du coup (horizontal, normalisé).
func take_hit(attacker: Fighter, m: Dictionary, dir: Vector3, crit := false) -> String:
	if not hittable():
		return "miss"
	var dmg := float(m.dmg) * (1.5 if crit else 1.0)
	var effect: String = m.get("effect", "")
	var kb: Array = m.kb
	var stun_f := int(m.stun)
	var from_front := dir.dot(facing) < 0.0
	last_hit = {"dir": dir, "effect": effect, "move": m, "attacker": attacker.id, "front": from_front, "crit": crit,
		"sweep_dir": int(m.get("sweep_dir", 0)), "height": float(m.box[1]), "dmg": dmg, "roll": world.roll()}
	# parade (fenêtre ouverte par le cerveau) ou garde de face
	if brain.has_method("on_incoming"):
		var r: String = brain.on_incoming(attacker, m, dir)
		if r == "parry":
			emit("parry", {"attacker": attacker.id})
			return "parry"
		if r == "block":
			if m.get("guard_break", false):
				_guard_break(dir)
				return "hit"
			hvel = dir * 2.5
			freeze = maxi(freeze, 2)
			emit("block", {"attacker": attacker.id})
			return "block"
	if armor and state == "attack" and move_phase() == "startup":
		hp -= dmg * 0.5
		emit("hit", {"armor": true, "dmg": dmg * 0.5})
		return "armor"
	hp -= dmg
	freeze = maxi(freeze, int(round(float(m.hitstop) * Tuning.v("hitstop_scale"))))
	if m.get("slowmo", 0.0) > 0.0:
		slow = maxi(slow, int(float(m.slowmo) * FPS * 2.0))
	if holding:
		release_hold(dir)
	armor = false
	lunge_left = 0.0
	if hp <= 0.0:
		hp = 0.0
		ko = true
		effect = "knockdown" if effect in ["", "stagger"] else effect
	match effect:
		"launch", "juggle", "spike":
			_launch(dir, kb, effect, stun_f)
		"knockdown":
			_launch(dir, kb, "knockdown", stun_f)
		"stagger":
			go("stagger")
			stun = stun_f
			hvel = dir * float(kb[0])
			fall_up = true
		_:
			if state == "air_hit" or not grounded:
				_launch(dir, [float(kb[0]), maxf(float(kb[1]), 2.5)], "juggle", stun_f)
			else:
				go("hurt")
				stun = stun_f
				hvel = dir * float(kb[0])
	emit("hit", {"dmg": dmg, "effect": effect, "dir": dir, "crit": crit, "attacker": attacker.id})
	return "hit"


func _launch(dir: Vector3, kb: Array, effect: String, stun_f: int) -> void:
	var was_air := state == "air_hit"
	go("air_hit")
	stun = stun_f
	if effect == "juggle" or (was_air and effect in ["launch", "knockdown"]):
		juggle += 1
	elif not was_air:
		juggle = 0
	var decay := pow(Tuning.v("juggle_decay"), juggle)
	hvel = dir * float(kb[0])
	fall_up = true if effect != "juggle" else dir.dot(facing) <= 0.0
	var vy := float(kb[1])
	velocity.y = vy * (decay if vy > 0 else 1.0)
	if effect == "spike":
		velocity.y = vy
	if effect == "knockdown" and not was_air:
		velocity.y = maxf(vy, 2.5)
	grounded = false
	mv = {}
	move_id = ""
	spike_next = effect == "spike"


var spike_next := false


func _guard_break(dir: Vector3) -> void:
	guarding = false
	go("stagger")
	stun = 40
	hvel = dir * 4.0
	emit("guard_break", {})


## États subis, avancés chaque image par le cerveau (commun héros / sbire).
func tick_hurt() -> bool:
	match state:
		"hurt":
			brake(40.0)
			stun -= 1
			if stun <= 0:
				go("idle")
			return true
		"stagger":
			brake(26.0)
			stun -= 1
			if stun <= 0:
				go("idle")
			return true
		"air_hit":
			hvel = hvel.move_toward(Vector3.ZERO, 1.5 / FPS)
			if grounded and f > 2:
				if spike_next and velocity.y <= 0.0:
					# écrasé au sol : il rebondit (jonglable)
					spike_next = false
					velocity.y = 6.0
					grounded = false
					hvel *= 0.5
					emit("bounce", {})
					return true
				_land_down()
			return true
		"down":
			brake(30.0)
			stun -= 1
			if stun <= 0:
				go("getup")
				stun = Tuning.vi("getup_frames")
				if downs >= Tuning.vi("quick_getup_after"):
					stun = 22
					invincible = true
					emit("quick_getup", {})
			return true
		"getup":
			brake(30.0)
			stun -= 1
			if stun <= 0:
				invincible = false
				if downs >= Tuning.vi("quick_getup_after"):
					downs = 0
				go("idle")
				juggle = 0
				if ko:
					ko = false
					hp = hp_max
					emit("respawn", {})
			return true
	return false


func _land_down() -> void:
	go("down")
	downs += 1
	stun = Tuning.vi("down_frames") + (30 if ko else 0)
	hvel = Vector3.ZERO
	juggle = 0
	emit("down", {"face_up": fall_up, "ko": ko})


# ------------------------------------------------------------------ chope (tenu par un autre)

func release_hold(dir := Vector3.ZERO) -> void:
	if holding and is_instance_valid(holding):
		holding.grabbed_by = null
		holding.go("stagger")
		holding.stun = 12
		holding.hvel = -facing * 2.0
	holding = null


func debug_line() -> String:
	return "%s f%d %s hp %.0f" % [state, f, move_id, hp]


## Notre coup vient d'être paré.
func parried_by(by: Fighter) -> void:
	lunge_left = 0.0
	mv = {}
	move_id = ""
	brain.on_parried(by)

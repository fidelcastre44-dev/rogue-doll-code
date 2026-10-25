class_name SimWorld
extends Node3D
## La simulation : fait avancer tous les combattants d'une image (60 / s fixes), à partir d'une commande par joueur,
## résout les coups (zones de frappe contre capsules), distribue les jetons d'attaque des sbires, tient le compteur
## d'images et la graine partagée. Rien ici ne lit l'affichage. L'hôte (coop) fait tourner cette classe ; l'affichage
## écoute `stepped(events)`.

signal stepped(events: Array)

const SPOTS := {
	"centre": {"hero": Vector3(0, 0, 2.0), "foes": [Vector3(0, 0, 0)]},
	"ligne": {"hero": Vector3(0, 0, 3.0), "foes": [Vector3(-1.6, 0, 0), Vector3(0, 0, 0), Vector3(1.6, 0, 0)]},
	"foule": {"hero": Vector3(0, 0, 0), "foes": [Vector3(3, 0, 0), Vector3(-3, 0, 1), Vector3(1, 0, -3.5), Vector3(-2, 0, -3), Vector3(3.5, 0, 3)]},
	"mur": {"hero": Vector3(0, 0, -6.0), "foes": [Vector3(0, 0, -8.5)]},
	"vide": {"hero": Vector3(0, 0, 0), "foes": []},
}

var frame := 0
var fighters: Array[Fighter] = []
var players: Array[Fighter] = []
var foes: Array[Fighter] = []
var tokens: Array = []
var _rng := RandomNumberGenerator.new()
var seed_value := 1234
var paused := false
var step_once := false
var slowmo := 1.0             # ralenti global du LABO seulement (pas un effet de jeu) : 1, 0.5, 0.25
var _slow_acc := 0.0
var foe_mode := "passive"
var spot := "centre"
var next_id := 1
var terrain: Node3D
var inputs: Node


func _ready() -> void:
	_rng.seed = seed_value
	inputs = get_node_or_null("/root/Inputs")
	terrain = Arena.build()
	add_child(terrain)


func rand() -> float:
	return _rng.randf()


func randi_n(n: int) -> int:
	return _rng.randi() % n


## Tirage partagé noté dans l'événement de coup (réactions identiques chez chaque joueur).
func roll() -> float:
	return _rng.randf()


# ------------------------------------------------------------------ mise en place

func add_player(model := "male") -> Fighter:
	var h := Fighter.new()
	h.setup(self, next_id, 0, "hero", model)
	next_id += 1
	h.brain = HeroBrain.new(h)
	h.hp_max = 150.0
	h.hp = h.hp_max
	add_child(h)
	fighters.append(h)
	players.append(h)
	return h


func add_foe() -> Fighter:
	var d := Fighter.new()
	d.setup(self, next_id, 1, "dummy", "dummy")
	next_id += 1
	d.brain = DummyBrain.new(d)
	d.hp_max = Tuning.v("foe_hp")
	d.hp = d.hp_max
	add_child(d)
	fighters.append(d)
	foes.append(d)
	return d


func clear_foes() -> void:
	for d in foes:
		fighters.erase(d)
		d.collision_layer = 0
		d.collision_mask = 0
		remove_child(d)      # tout de suite hors de la physique : le suivant ne doit pas être repoussé par le fantôme
		d.queue_free()
	foes.clear()
	tokens.clear()


func load_spot(name: String, count := -1) -> void:
	spot = name
	var sp: Dictionary = SPOTS[name]
	clear_foes()
	var positions: Array = sp.foes
	if count >= 0:
		positions = []
		for i in count:
			var a := TAU * i / maxf(count, 1)
			positions.append(Vector3(sin(a), 0, -cos(a)) * (0.0 if count == 1 else 2.2) + Vector3(0, 0, 0))
	for p in positions:
		var d := add_foe()
		d.global_position = p
		d.facing = Vector3(0, 0, 1)
		d.brain.set_mode(foe_mode)
	for i in players.size():
		var h := players[i]
		reset_fighter(h, sp.hero + Vector3(i * 1.6, 0, 0), Vector3(0, 0, -1))


func reset_fighter(fi: Fighter, p: Vector3, face: Vector3) -> void:
	fi.global_position = p
	fi.velocity = Vector3.ZERO
	fi.hvel = Vector3.ZERO
	fi.facing = face
	fi.state = "idle"
	fi.f = 0
	fi.mv = {}
	fi.move_id = ""
	fi.hp = fi.hp_max
	fi.ko = false
	fi.freeze = 0
	fi.slow = 0
	fi.stun = 0
	fi.juggle = 0
	fi.downs = 0
	fi.invincible = false
	fi.armor = false
	fi.holding = null
	fi.grabbed_by = null
	fi.grounded = true
	if fi.brain is HeroBrain:
		fi.brain.grab_phase = ""
		fi.brain.buf.clear()
	fi.emit("reset_done", {})


func set_foe_mode(m: String) -> void:
	foe_mode = m
	for d in foes:
		d.brain.set_mode(m)


# ------------------------------------------------------------------ image

func _physics_process(_dt: float) -> void:
	if paused and not step_once:
		return
	step_once = false
	if slowmo < 1.0:
		_slow_acc += slowmo
		if _slow_acc < 1.0:
			return
		_slow_acc -= 1.0
	step()


## Une image complète : commandes, cerveaux + physique, coups, événements.
func step() -> void:
	frame += 1
	var events := []
	for i in players.size():
		var cmd = inputs.command(i, frame)
		players[i].step(cmd)
	for d in foes:
		d.step(null)
	_separate()
	_resolve_hits()
	_tick_threats()
	for fi in fighters:
		if fi.global_position.y < -5.0:
			reset_fighter(fi, Vector3.ZERO, fi.facing)
		for e in fi.events:
			e["who"] = fi.id
			events.append(e)
		fi.events = []
	stepped.emit(events)


## Séparation douce des capsules au sol (elles ne se bloquent pas physiquement : jongles, chopes, passages).
func _separate() -> void:
	for i in fighters.size():
		var a := fighters[i]
		if not a.grounded or a.state in ["held", "hold", "air_hit", "roll"]:
			continue
		for j in range(i + 1, fighters.size()):
			var b := fighters[j]
			if not b.grounded or b.state in ["held", "hold", "air_hit", "roll"]:
				continue
			var d := b.global_position - a.global_position
			d.y = 0
			var dist := d.length()
			var minimum := Fighter.RADIUS * 2.0 * 0.95
			if dist < minimum:
				var push := (d.normalized() if dist > 0.01 else a.facing) * (minimum - dist) * 0.5
				a.global_position -= push
				b.global_position += push


func _resolve_hits() -> void:
	for a in fighters:
		var sph := a.hit_sphere()
		if sph.is_empty():
			continue
		for t in fighters:
			if t == a or t.team == a.team or t.id in a.hits_done:
				continue
			if not t.capsule_hit(sph[0], sph[1], bool(a.mv.get("low", false))):
				continue
			a.hits_done.append(t.id)
			var dir := t.global_position - a.global_position
			dir.y = 0
			dir = dir.normalized() if dir.length() > 0.01 else a.facing
			# le recul suit surtout le regard de l'attaquant, un peu la position relative
			dir = (a.facing * 0.7 + dir * 0.3).normalized()
			var crit: bool = a.crit_next or bool(a.mv.get("crit", false))
			var m := a.mv
			var res := t.take_hit(a, m, dir, crit)
			on_hit(a, t, m, res, crit)
			if res == "parry":
				break


## Suites d'un coup (appelé aussi par le slam de la chope).
func on_hit(a: Fighter, t: Fighter, m: Dictionary, res: String, crit: bool) -> void:
	if res in ["hit", "armor", "block"]:
		a.hit_landed = true
		a.freeze = maxi(a.freeze, int(round(float(m.hitstop) * Tuning.v("hitstop_scale"))))
		if res == "hit":
			if m.get("slowmo", 0.0) > 0.0:
				a.slow = maxi(a.slow, int(float(m.slowmo) * 60.0 * 2.0))
			a.brain.on_hit_landed(t, m)
			a.crit_next = false
	a.emit("hit_result", {"target": t.id, "result": res, "move": m.get("anim", ""), "shake": float(m.get("shake", 0.2)), "crit": crit,
		"at": t.centre() + Vector3.UP * (float(m.box[1]) - 0.9), "effect": m.get("effect", ""), "sfx": m.get("sfx", "light")})


## Coup de pied plongeant : onde au sol.
func quake(a: Fighter, radius: float, dmg: float) -> void:
	for t in fighters:
		if t.team == a.team or not t.hittable():
			continue
		var d := t.global_position - a.global_position
		d.y = 0
		if d.length() <= radius and t.grounded:
			var m := {"dmg": dmg, "hitstop": 4, "stun": 40, "kb": [4.0, 4.0], "effect": "knockdown", "box": [0, 0.5, radius], "shake": 0.3, "sweep_dir": 0}
			t.take_hit(a, m, d.normalized() if d.length() > 0.01 else a.facing)


## Fenêtre d'esquive parfaite : un coup ennemi va toucher ce joueur dans les N prochaines images.
func _tick_threats() -> void:
	for p in players:
		var win := 0
		for d in foes:
			if d.state != "attack" or d.mv.is_empty():
				continue
			var left := int(d.mv.startup) - d.f
			if left >= 0 and left <= Tuning.vi("perfect_dodge_window"):
				var to := p.global_position - d.global_position
				to.y = 0
				if to.length() < float(d.mv.box[0]) + 1.0 and to.normalized().dot(d.facing) > 0.5:
					win = maxi(win, left + 2)
		if win > 0 and p.state not in ["roll", "air_dash"]:
			p.brain.dodge_ok_win = maxi(p.brain.dodge_ok_win, win)


# ------------------------------------------------------------------ aides

## Ennemi le plus pertinent dans le cône (degrés) autour de `dir`, à moins de `range` m.
func best_target(me: Fighter, dir: Vector3, range_: float, cone: float, grab := false) -> Fighter:
	var best: Fighter = null
	var best_score := -1e9
	dir.y = 0
	if dir.length() < 0.01:
		dir = me.facing
	dir = dir.normalized()
	for t in fighters:
		if t == me or t.team == me.team or not (t.grabbable() if grab else t.targetable()):
			continue
		var d := t.global_position - me.global_position
		d.y = 0
		var dist := d.length()
		if dist > range_ or dist < 0.01:
			continue
		var ang := rad_to_deg(dir.angle_to(d.normalized()))
		if ang > cone * 0.5:
			continue
		var score := -dist - ang * 0.02
		if score > best_score:
			best_score = score
			best = t
	return best


func nearest_player(me: Fighter) -> Fighter:
	var best: Fighter = null
	var bd := 1e9
	for p in players:
		if not p.targetable():
			continue
		var d := p.global_position.distance_to(me.global_position)
		if d < bd:
			bd = d
			best = p
	return best


func request_token(d: Fighter) -> bool:
	tokens = tokens.filter(func(x): return is_instance_valid(x) and x.brain.token)
	if tokens.size() < Tuning.vi("foe_attackers_max"):
		tokens.append(d)
		return true
	return false


func release_token(d: Fighter) -> void:
	tokens.erase(d)


## Deux sbires ne lancent pas leur coup à la même image.
func can_attack_now(d: Fighter) -> bool:
	for o in foes:
		if o != d and o.state == "attack" and o.move_phase() == "startup" and o.f < 6:
			return false
	return true

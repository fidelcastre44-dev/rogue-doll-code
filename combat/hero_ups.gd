class_name HeroUps
extends RefCounted
## Améliorations de bouton (v0.212) et coups « À tester » de la v0.212, branchés sur le héros (player.gd).
##
## Améliorations générales : chacune liste les boutons qu'elle peut améliorer ; un loot n'en améliore qu'un
## (player.btn_ups = {id: [boutons]}). Impact (X, Y), Triple Tour, Renvoi (X, Y, L1, B), Défense (R1), Tazer (X, Y, L1, B),
## Électrification de zone (s'ajoute au Tazer).
## Coups : la vague (L1 + X), toile d'araignée (R1 sans personne à portée), tomoe nage (chope + B, variante),
## désarmer (X juste après une parade), pas de côté (B sans stick), pluie d'objets (R2), renvoi de projectile (parade au bon moment).

const IMPACT_R := 1.35        # zone de frappe ×
const IMPACT_DMG := 1.3       # dégâts ×
const ELEC_T := 2.4           # s : électrifié
const DEFENSE_HITS := 3       # coups encaissés par le bouclier (ennemi ou objet tenu) avant qu'il casse
const WEB_RANGE := 10.0
const WEB_K := 55.0           # raideur de l'élastique (v0.216 : vrai ressort, il rebondit un peu en arrivant)
const WEB_DAMP := 6.0         # amortissement du ressort (faible = plus élastique)
const WEB_MAX := 22.0         # m/s : vitesse max de ce qui est ramené
const WEB_SHOT := 0.06        # s : le fil jaillit de la main jusqu'à la cible
const WEB_FOLLOW := 3.0       # m : ennemi ramené à moins de ça = X ou Y enchaîne une attaque (le fil est lâché)
const WEB_AIR_DOWN := 0.45    # en l'air : le fil part en légère diagonale vers le bas
const WAVE_R := 6.5
const WAVE_STUN := 2.2
const RAIN_R := 14.0
const RAIN_CD := 2.5
const EVADE_T := 1.2          # s : après un pas de côté réussi, le coup suivant est critique

## Bouton de chaque coup du héros (pour les améliorations de bouton).
const BUTTON_OF := {
	"jab": "X", "cross": "X", "jab2": "X", "pin_punch": "X", "run_kick": "Y", "air_bigknee": "Y", "tackle_wall": "R1", "upper": "X", "hook": "X", "knee": "X", "elbow": "X", "air": "X", "air_cross": "X", "air_upper": "X",
	"air_hook": "X", "air_knee": "X", "hammer": "X", "spin_counter": "X", "spin_counter3": "X", "collar_punch": "X", "superman": "X",
	"kick": "Y", "hikick": "Y", "spinkick": "Y", "axe": "Y", "quake": "Y", "charge": "Y", "charge_sho": "Y", "charge_hado": "Y",
	"power": "Y", "shoryu": "Y", "hadoken": "Y", "air_kick": "Y", "bicycle": "Y", "dive_kick": "Y", "drop_kick": "Y", "capoeira": "Y",
	"soccer_kick": "Y", "prop_kick": "Y", "wall_run": "Y", "wall_run_h": "Y", "headbutt": "Y", "prop_bash": "Y",
	"grab": "R1", "slam": "R1", "tackle": "R1", "tackle_slam": "R1", "air_slam": "R1", "web": "R1", "swing": "R1",
	"wave": "L1", "disarm": "X", "tomoe": "B", "dive": "A", "tramp": "A", "super_jump": "A", "piledriver": "A", "rain": "R2",
}

var p: CharacterBody3D
var evade_t := 0.0            # pas de côté réussi : critique en attente
var shield_hits := 0
var rain_cd := 0.0
var web_target: Object = null
var web_kind := ""            # enemy / prop / wall
var web_point := Vector3.ZERO
var web_line: MeshInstance3D
var web_hit := false
var web_shot := 0.0           # temps depuis que le fil est parti (il jaillit, puis se tend)
var tomoe_victim: Node3D = null
var stats := {}               # compteurs (tests)


func _init(player: CharacterBody3D) -> void:
	p = player


func _count(k: String) -> void:
	stats[k] = stats.get(k, 0) + 1


func has(id: String, button: String) -> bool:
	var b: Array = p.btn_ups.get(id, [])
	return button in b or "*" in b


## Bouton du coup en cours (ou d'un coup donné). La roulade compte pour B, la garde pour L1.
func button(kind := "") -> String:
	if kind == "":
		kind = p.attack
	if kind == "" and p.roll >= 0.0:
		return "B" if p.roll_kind != "sweep" else "X"
	if kind == "" and p.guarding:
		return "L1"
	return BUTTON_OF.get(kind, "")


var tazed := {}                # roulade avec le Tazer sur B : sbires déjà électrifiés pendant cette esquive


func tick(dt: float) -> void:
	evade_t -= dt
	rain_cd -= dt
	if p.roll >= 0.0 and has("tazer", "B"):
		for e in p.enemies:
			if is_instance_valid(e) and not e.parts.is_empty() and not tazed.has(e) and e.parts.chest.global_position.distance_to(p.global_position + Vector3.UP) < 1.0:
				tazed[e] = true
				on_hit(e, "")
	elif p.roll < 0.0:
		tazed.clear()
	if web_line and (p.attack != "web" or not is_instance_valid(web_line)):
		_web_line_off()


# ------------------------------------------------------------------ frappe

## Augmentation d'impact : zone de frappe et dégâts plus grands pour les coups du bouton amélioré.
func radius_mult() -> float:
	return IMPACT_R if has("impact", button()) else 1.0


func dmg_mult() -> float:
	return IMPACT_DMG if has("impact", button()) else 1.0


## Après un coup qui touche : Tazer (électrifie), et électrification de zone si elle est débloquée.
func on_hit(victim: Node, kind := "") -> void:
	var b := button(kind)
	if b != "" and has("tazer", b) and victim.has_method("electrify"):
		victim.electrify(ELEC_T, p.btn_ups.has("zone"))
		_count("tazer")


## Pas de côté réussi (un coup ennemi l'a manqué pendant le pas) : le prochain coup est critique.
func on_evade(_attacker: Node) -> void:
	if p.roll_kind != "step" or p.roll < 0.0:
		return
	if evade_t <= 0.0:
		p._flash(Color(1, 0.9, 0.4), 0.08)
		p.get_parent().impact(0.05, 0.3)
		_count("evade")
	evade_t = EVADE_T


# ------------------------------------------------------------------ projectiles et coups reçus

## Un projectile ennemi arrive sur le héros : « reflect » (renvoyé vers le tireur), « absorb » (le bouclier encaisse) ou "" (touché).
func deflect(proj: Node3D) -> String:
	var dir: Vector3 = proj.velocity.normalized()
	var front: bool = (-p.global_basis.z).dot(-dir) > 0.2
	if p.guarding and front:
		if p.guard_t <= p.PARRY_WINDOW + 0.05 or has("renvoi", "L1"):
			_count("reflect_guard")
			return "reflect"   # parade pile au bon moment (ou renvoi sur L1) : renvoyé
		return "absorb"        # simplement paré
	if p.roll >= 0.0 and has("renvoi", "B"):
		_count("reflect_roll")
		return "reflect"
	if p.attack != "":
		var b := button()
		if b in ["X", "Y"] and has("renvoi", b):   # pendant tout le coup
			_count("reflect_hit")
			return "reflect"
	if front and _shield_ready():
		shield_hit()
		return "absorb"
	return ""


## Défense : un ennemi tenu par le col ou un objet tenu sert de bouclier.
func _shield_ready() -> bool:
	if not has("defense", "R1"):
		return false
	if p.attack in ["collar", "collar_punch"] and p.enemy and p.enemy.state == "held":
		return true
	return p.attack in ["prop_hold", "prop_wind"] and p.held_prop != null


## Coup reçu de face avec un bouclier : il encaisse à la place du héros (casse au 3e coup). Vrai si absorbé.
func absorb_hit(dir: Vector3) -> bool:
	if not _shield_ready() or (-p.global_basis.z).dot(-dir) < 0.2:
		return false
	shield_hit()
	return true


func shield_hit() -> void:
	shield_hits += 1
	_count("shield")
	p.get_parent().impact(0.05, 0.45)
	if p.attack.begins_with("collar") and p.enemy:
		p.enemy.collar_hit(8.0)
		p.enemy.held_hit = 0.2
	if shield_hits >= DEFENSE_HITS:
		shield_hits = 0
		if p.attack.begins_with("collar") and p.enemy:
			p.enemy.toss(-p.global_basis.z * 2.0 + Vector3.UP * 2.0, 2.0)   # le bouclier humain cède : il tombe
			p.attack = ""
		elif p.held_prop:
			p._break_prop()


# ------------------------------------------------------------------ coups

## Impact (instant « active ») des coups v0.212 (fiches avec le mot « v212 »).
func impact(kind: String) -> void:
	match kind:
		"wave":
			var n := 0
			for e in p.enemies:
				if is_instance_valid(e) and not e.parts.is_empty() and e.state == "stand" and e.root.origin.distance_to(p.global_position) < WAVE_R:
					e.stun(WAVE_STUN)
					n += 1
			_count("wave")
			stats["wave_stunned"] = n
			p._shock_ring(p.global_position)
			p.get_parent().impact(0.06, 0.6)
		"web":
			_web_fire()
		"tomoe":
			_tomoe_throw()
		"disarm":
			pass
		"rain":
			_rain()


## L1 maintenu + X : la vague (forme).
func try_wave() -> bool:
	if not p.wave or not Input.is_action_pressed("guard") or not p.is_on_floor():
		return false
	p.guarding = false
	p.start("wave")
	return true


## X juste après une parade, sur un sbire armé tout proche : il lui arrache son arme.
func try_disarm() -> bool:
	if p.riposte_t <= 0.0 and p.guard_t > 1.2:
		return false
	for e in p.enemies:
		if not is_instance_valid(e) or e.parts.is_empty() or e.get("weapon") == null:
			continue
		if not (e.ai == "stunned" or p.riposte_t > 0.0):
			continue
		if e.root.origin.distance_to(p.global_position) > 1.9:
			continue
		var d: Vector3 = e.root.origin - p.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.start("disarm")
		var b: RigidBody3D = e.drop_weapon()
		if b:
			p.held_prop = b
			p.prop_rot = Basis(Vector3.RIGHT, deg_to_rad(80))
			b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			b.freeze = true
			b.collision_layer = 0
			p.prop_t = 0.0
			p.prop_wind = 0.0
			p.prop_sweep.clear()
		e.stun(1.0)
		_count("disarm")
		p.get_tree().create_timer(0.22).timeout.connect(func():
			if is_instance_valid(p) and p.attack == "disarm" and p.held_prop:
				p.start("prop_hold"))
		return true
	return false


## R1 (forme) quand personne n'est à portée de chope : il tire un fil.
func try_web() -> bool:
	if not p.web:
		return false
	for e in p.enemies:
		if is_instance_valid(e) and not e.parts.is_empty() and e.state in ["stand", "down"] and e.parts.chest.global_position.distance_to(p.global_position) < 1.6:
			return false   # quelqu'un à portée : la chope normale
	if p.stick_dir.length() > 0.3:
		p.rotation.y = atan2(-p.stick_dir.x, -p.stick_dir.z)
	p.start("web")
	web_target = null
	web_kind = ""
	web_hit = false
	return true


func _hand() -> Vector3:
	return p.j.fist_r.global_position


func _web_fire() -> void:
	var f := -p.global_basis.z
	var from := p.global_position + Vector3.UP * 1.25
	var aim := f if p.is_on_floor() else (f + Vector3.DOWN * WEB_AIR_DOWN).normalized()   # en l'air : visée en diagonale vers le bas
	var space := p.get_world_3d().direct_space_state
	var best: Dictionary = {}
	# Sbires d'abord (cône étroit), sinon le premier objet / mur sur la ligne.
	var bd := WEB_RANGE
	for e in p.enemies:
		if not is_instance_valid(e) or e.parts.is_empty() or e.state in ["held", "swung", "dead"]:
			continue
		var c: Vector3 = e.parts.chest.global_position
		var d := c - from
		if d.length() < bd and f.angle_to(d * Vector3(1, 0, 1)) < deg_to_rad(20):
			bd = d.length()
			best = {"kind": "enemy", "obj": e, "at": c}
	if best.is_empty():
		var q := PhysicsRayQueryParameters3D.create(from, from + aim * WEB_RANGE, 1)
		q.exclude = [p.get_rid()]
		var r := space.intersect_ray(q)
		if not r.is_empty():
			best = {"kind": "prop" if r.collider is RigidBody3D else "wall", "obj": r.collider, "at": r.position}
	if best.is_empty():
		p.attack = ""   # dans le vide
		return
	web_kind = best.kind
	web_target = best.obj
	web_point = best.at
	web_hit = true
	web_shot = 0.0
	_count("web_" + web_kind)
	if web_kind == "enemy":
		var e = web_target
		if e.state == "stand":
			e.trip((p.global_position - e.root.origin).normalized(), 0.0, 1.2)
		e.timer = maxf(e.timer, 1.5)
	elif web_kind == "prop":
		var b: RigidBody3D = web_target
		b.freeze = false
	p.get_parent().impact(0.04, 0.3)


## R1 maintenu : l'élastique ramène l'ennemi / l'objet devant lui (ou le tire vers le mur).
func web_tick(dt: float) -> void:
	if not web_hit:
		if p.t > 0.2:
			p.attack = ""
		return
	var held := Input.is_action_pressed("grab")
	web_shot += dt
	var goal := p.global_position - p.global_basis.z * 1.6 + Vector3.UP * 1.1
	# Enchaînement (v0.216, retour de Thibaud) : l'ennemi ramené arrive sur nous, X ou Y lâche le fil et lance l'attaque.
	if web_kind in ["enemy", "prop"] and is_instance_valid(web_target) and (Input.is_action_just_pressed("light") or Input.is_action_just_pressed("heavy")):
		var tp: Vector3 = web_target.parts.chest.global_position if web_kind == "enemy" else web_target.global_position
		if tp.distance_to(p.global_position + Vector3.UP) < WEB_FOLLOW:
			_web_follow(Input.is_action_just_pressed("heavy"))
			return
	match web_kind:
		"enemy":
			var e = web_target
			if not is_instance_valid(e) or e.parts.is_empty():
				web_release()
				return
			e.timer = maxf(e.timer, 1.0)
			var c: Vector3 = e.parts.pelvis.global_position
			web_point = e.parts.chest.global_position
			# Ressort amorti (élastique) : il est tiré vers nous, dépasse un peu et rebondit au bout du fil.
			var mean := Vector3.ZERO
			var m := 0.0
			for b in e.parts.values():
				mean += b.linear_velocity * b.mass
				m += b.mass
			mean /= maxf(m, 0.001)
			var acc := (goal - c) * WEB_K - mean * WEB_DAMP
			var nv := (mean + acc * dt).limit_length(WEB_MAX)
			for b in e.parts.values():
				if not b.freeze:
					b.linear_velocity += nv - mean
		"prop":
			var b: RigidBody3D = web_target
			if not is_instance_valid(b):
				web_release()
				return
			web_point = b.global_position
			var acc2 := (goal - b.global_position) * WEB_K - b.linear_velocity * WEB_DAMP
			b.linear_velocity = (b.linear_velocity + acc2 * dt).limit_length(WEB_MAX)
		"wall":
			var to := web_point - (p.global_position + Vector3.UP * 1.0)
			if to.length() > 1.2:
				p.velocity = to.normalized() * 14.0
			else:
				p.velocity = Vector3.ZERO
				held = false
	var hand := _hand()
	_web_line(hand, hand.lerp(web_point, clampf(web_shot / WEB_SHOT, 0.0, 1.0)))   # le fil jaillit, puis reste tendu
	if not held and p.t > 0.1:
		web_release()


## X ou Y quand l'ennemi (ou l'objet) ramené arrive sur nous : le fil est lâché sans le projeter, il reste devant nous
## (presque arrêté) et l'attaque part tout de suite (au sol : le combo / le coup lourd ; en l'air : le combo aérien / le Y aérien).
func _web_follow(heavy: bool) -> void:
	if web_kind == "enemy" and is_instance_valid(web_target):
		for b in web_target.parts.values():
			b.linear_velocity *= 0.2
		web_target.timer = maxf(web_target.timer, 1.0)
	elif web_kind == "prop" and is_instance_valid(web_target):
		web_target.linear_velocity *= 0.2
	web_target = null
	web_hit = false
	_web_line_off()
	p.attack = ""
	if heavy:
		p.heavy_buf = 0.15
	else:
		p.light_buf = 0.15
	_count("web_follow")


## R1 relâché : il lâche ; l'ennemi ou l'objet garde sa vitesse (on peut le projeter en tournant).
func web_release() -> void:
	if web_kind == "enemy" and is_instance_valid(web_target):
		web_target.projectile_t = 1.2   # son corps percute les autres
		web_target.swing_victims.clear()
	elif web_kind == "prop" and is_instance_valid(web_target):
		p.flying.append({"b": web_target, "t": 0.0, "hits": {}})
	web_target = null
	web_hit = false
	_web_line_off()
	p.start("web_throw")


func _web_line(a: Vector3, b: Vector3) -> void:
	if web_line == null or not is_instance_valid(web_line):
		web_line = MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.018
		m.bottom_radius = 0.018
		m.height = 1.0
		web_line.mesh = m
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Color(0.95, 0.95, 1.0)
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		web_line.material_override = mt
		p.get_parent().add_child(web_line)
	var d := b - a
	if d.length() < 0.01:
		return
	var y := d.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var thin := clampf(sqrt(2.0 / maxf(d.length(), 0.5)), 0.45, 1.4)   # élastique : plus il est tendu (long), plus il est fin
	web_line.global_transform = Transform3D(Basis(x * thin, y * d.length(), x.cross(y) * thin), (a + b) * 0.5)


func _web_line_off() -> void:
	if web_line and is_instance_valid(web_line):
		web_line.queue_free()
	web_line = null


## Chope + B (variante « tomoe ») : il roule en arrière en emportant l'ennemi, projeté par-dessus lui.
func start_tomoe() -> void:
	tomoe_victim = p.enemy
	p.hold_o = p.global_position
	p.hold_f = -p.global_basis.z
	p.hold_c0 = p.enemy.parts.chest.global_position
	p.start("tomoe")


func tomoe_tick() -> void:
	var e = tomoe_victim
	if e == null or not is_instance_valid(e) or e.state != "held" or p.hit_done:
		return
	var f: Vector3 = p.hold_f
	var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
	var axis := Vector3.UP.cross(f)
	var u := clampf(p.t / p.ATK.tomoe.active, 0.0, 1.0)
	var p1: Vector3 = p.hold_o + f * 0.5 + Vector3.UP * 0.9       # sur le pied du héros
	var p2: Vector3 = p.hold_o + Vector3.UP * 1.7                 # au-dessus de lui
	var chest: Vector3 = p.hold_c0.lerp(p1, smoothstep(0.0, 0.4, u)).lerp(p2, smoothstep(0.4, 1.0, u))
	e.hold(Basis(axis, deg_to_rad(lerpf(10.0, -150.0, smoothstep(0.2, 1.0, u)))) * face, chest)


func _tomoe_throw() -> void:
	var e = tomoe_victim
	tomoe_victim = null
	if e == null or not is_instance_valid(e) or e.state != "held":
		return
	var f: Vector3 = p.hold_f
	e.toss(-f * 7.0 + Vector3.UP * 5.0, 4.0)   # projeté par-dessus lui, derrière
	e.hp = maxf(e.hp - 16.0, 0.0)
	e.land_dmg = 10.0
	e.land_t = 0.0
	p.connected = true
	p._gain(12.0)
	_count("tomoe")
	p.get_parent().impact(0.1, 0.9)


## R2 : pluie d'objets. Tous les objets de la salle s'envolent vers les sbires.
func try_rain() -> bool:
	if not p.rain or rain_cd > 0.0 or not p.is_on_floor() or p.attack != "":
		return false
	rain_cd = RAIN_CD
	p.start("rain")
	return true


func _rain() -> void:
	var targets := []
	for e in p.enemies:
		if is_instance_valid(e) and not e.parts.is_empty() and e.state != "dead":
			targets.append(e)
	if targets.is_empty():
		return
	var n := 0
	for b in p.get_tree().get_nodes_in_group("reactive"):
		if not b is RigidBody3D or b == p.held_prop or b.global_position.distance_to(p.global_position) > RAIN_R:
			continue
		var e = targets[n % targets.size()]
		var to: Vector3 = e.parts.chest.global_position - b.global_position
		var tt := clampf(to.length() / 14.0, 0.35, 0.9)
		b.freeze = false
		b.linear_velocity = Vector3(to.x / tt, to.y / tt + 0.5 * 9.8 * tt, to.z / tt)   # trajectoire en cloche vers le sbire
		b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		p.flying.append({"b": b, "t": 0.0, "hits": {}})
		n += 1
	stats["rain_props"] = n
	_count("rain")
	p.get_parent().impact(0.06, 0.8)

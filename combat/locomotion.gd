class_name Locomotion
extends RefCounted
## Déplacements du héros avec le décor (v0.212, « Terrain d'essai ») :
##   - marche automatique sur une petite marche (≤ 0,4 m) ;
##   - enjamber un muret / une rambarde (automatique en sprint, ou A tout près) ;
##   - se hisser sur un bloc de 1 m (A tout près, ou en sautant contre) ;
##   - s'agripper au rebord d'un bloc haut (2 m) en sautant contre, puis A / stick vers le mur = se hisser, B / stick à l'opposé = lâcher ;
##   - glissade dans l'escalier ou sur la pente : B maintenu en descendant (sprint + B = glissade prolongée), fauche les sbires ;
##   - glisser sous un obstacle bas : sprint + B devant une barrière haute ;
##   - grande chute : B juste avant de toucher le sol = réception roulée, sinon atterrissage lourd (petit temps mort) ;
##   - rebond mural : esquive contre un mur = il rebondit dessus et repart dans l'autre sens ;
##   - bonus de chute : plus il tombe de haut, plus son coup aérien (ou sa chope plongeante) frappe fort.
## Les états « en main » (enjambée, hissé, suspendu…) prennent le contrôle du héros : `tick()` renvoie vrai et le reste
## de player._physics_process est sauté.

const STEP := 0.42            # m : marche franchie sans sauter
const VAULT_T := 0.42         # s : enjambée
const MANTLE_T := 0.4         # s : se hisser sur un bloc bas
const CLIMB_T := 0.6          # s : se hisser depuis le rebord
const HEAVY_T := 0.5          # s : atterrissage lourd (temps mort)
const BIG_FALL := 1.8         # m : au-delà, réception roulée ou atterrissage lourd (la plateforme fait 2 m)
const ROLL_WINDOW := 0.3      # s : B pressé avant de toucher le sol = réception roulée
const HANG_REACH := 2.05      # m : des pieds aux mains, bras tendus
const GLIDE_MAX := 15.0       # m/s
const SKID_T := 0.6
const FALL_BONUS_MAX := 1.0   # +100 % de dégâts au maximum

var p: CharacterBody3D        # le héros
var state := ""               # "", vault, mantle, hang, climb, heavy_land, glide, skid
var t := 0.0
var w := 0.0                  # poids de la pose (fondu d'entrée / sortie)
var a0 := Vector3.ZERO        # départ / arrivée des mouvements guidés
var a1 := Vector3.ZERO
var top := 0.0
var wall_n := Vector3.ZERO
var air_peak := 0.0           # point le plus haut du saut / de la chute en cours
var takeoff_g := 0.0          # hauteur du sol quitté (seules les chutes d'un rebord comptent : un grand saut sur place ne pénalise pas)
var was_air := false
var land_roll_t := -1.0       # B pressé juste avant une grande réception
var regrab_t := 0.0           # après avoir lâché un rebord, on ne s'y raccroche pas tout de suite
var glide_dir := Vector3.ZERO
var glide_v := 0.0
var glide_long := false
var bounced := false          # rebond mural déjà fait pendant cette esquive
var hang_push := 0.0          # stick poussé vers le mur depuis ce temps (se hisser)
var hang_ready := false       # le stick a été relâché depuis qu'il s'est agrippé (sinon il se hisserait tout seul)
var sprint_t := 9.0           # temps depuis le dernier sprint (glissade prolongée)
var last_fall := 0.0          # hauteur de la dernière chute (tests, affichage)
var stats := {}               # compteurs (tests) : vault, mantle, hang, climb, glide, skid, heavy_land, land_roll, wall_bounce, step
var cs: CollisionShape3D
var cap_h := 1.6


func _init(player: CharacterBody3D) -> void:
	p = player
	for c in p.get_children():
		if c is CollisionShape3D:
			cs = c
	if cs:
		cap_h = cs.shape.height


func _count(k: String) -> void:
	stats[k] = stats.get(k, 0) + 1


func active() -> bool:
	return state != ""


## L'action en cours est un déplacement « en main » (le joueur ne contrôle plus le héros).
func locked() -> bool:
	return state in ["vault", "mantle", "hang", "climb", "heavy_land"]


func invulnerable() -> bool:
	return state in ["vault", "mantle", "climb", "skid"] or (state == "glide" and t < 0.35)


## Remise à zéro (le labo replace le héros ailleurs : ce n'est pas une chute).
func reset() -> void:
	cancel()
	was_air = false
	air_peak = p.global_position.y
	takeoff_g = p.global_position.y
	land_roll_t = -1.0
	regrab_t = 0.0
	bounced = false


func cancel() -> void:
	if state == "":
		return
	_small(false)
	state = ""
	w = 0.0


# ------------------------------------------------------------------ sondes

func _space() -> PhysicsDirectSpaceState3D:
	return p.get_world_3d().direct_space_state


func _ray(a: Vector3, b: Vector3, inside := false) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.exclude = [p.get_rid()]
	q.hit_from_inside = inside
	return _space().intersect_ray(q)


func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 0.001 else Vector3.ZERO


## Obstacle devant (dans la direction d) : position du contact, normale, hauteur du dessus (top, INF = trop haut / mur),
## hauteur par rapport aux pieds (rel) et épaisseur (thick, 9 = plein).
func probe(d: Vector3, reach := 0.9) -> Dictionary:
	d = _flat(d)
	if d == Vector3.ZERO:
		return {}
	var o := p.global_position
	var hit := {}
	for h in [0.22, 0.55, 0.9, 1.3, 1.75]:
		var r := _ray(o + Vector3.UP * h, o + Vector3.UP * h + d * (reach + 0.3))
		if not r.is_empty() and r.normal.y < 0.5 and not r.collider is RigidBody3D:
			hit = r
			break
	if hit.is_empty():
		return {}
	var n := _flat(hit.normal)
	var x: Vector3 = hit.position - n * 0.05
	var r2 := _ray(Vector3(x.x, o.y + 3.4, x.z), Vector3(x.x, o.y - 0.3, x.z), true)
	var tp := INF
	if not r2.is_empty() and r2.normal != Vector3.ZERO:
		tp = r2.position.y
	var thick := 9.0
	if tp != INF:
		var yy := tp - 0.12
		var far := Vector3(hit.position.x, yy, hit.position.z) - n * 1.2
		var r3 := _ray(far, Vector3(hit.position.x, yy, hit.position.z) - n * 0.02, true)
		if r3.is_empty():
			thick = 0.05
		elif r3.normal != Vector3.ZERO:
			thick = 1.2 - far.distance_to(r3.position)
	var dist: float = ((hit.position - o) * Vector3(1, 0, 1)).length()
	return {"pos": hit.position, "n": n, "top": tp, "rel": tp - o.y, "thick": thick, "dist": dist}


## Sol sous un point (INF si rien en dessous).
func ground_at(at: Vector3, up := 0.5) -> float:
	var r := _ray(at + Vector3.UP * up, at + Vector3.DOWN * 6.0, true)
	if r.is_empty() or r.normal == Vector3.ZERO:
		return INF
	return r.position.y


## Pente sous le héros : direction de la descente (à plat) et raideur (0 = plat).
func slope() -> Array:
	var r := _ray(p.global_position + Vector3.UP * 0.3, p.global_position + Vector3.DOWN * 0.6)
	if r.is_empty():
		return [Vector3.ZERO, 0.0]
	var n: Vector3 = r.normal
	return [_flat(n), 1.0 - n.y]


## Barrière haute devant (passage libre dessous, barre à hauteur de buste).
func low_obstacle(d: Vector3, reach := 5.0) -> bool:
	d = _flat(d)
	var o := p.global_position
	for k in 8:
		var at := o + d * (0.5 + k * reach / 8.0)
		var hi := _ray(at + Vector3.UP * 0.4, at + Vector3.UP * 1.5)
		var lo := _ray(o + Vector3.UP * 0.35, at + Vector3.UP * 0.35)
		if not hi.is_empty() and lo.is_empty():
			return true
	return false


func _ceiling() -> bool:
	var o := p.global_position
	return not _ray(o + Vector3.UP * 0.3, o + Vector3.UP * 1.7).is_empty()


func _small(on: bool) -> void:
	if cs == null:
		return
	cs.shape.height = 0.66 if on else cap_h
	cs.position.y = cs.shape.height * 0.5


# ------------------------------------------------------------------ déclencheurs (appelés par player.gd)

## A au sol : enjamber / se hisser si un muret ou un bloc bas est tout près. Vrai si l'action est prise.
func try_jump() -> bool:
	if not p.terrain:
		return false
	var d: Vector3 = p.stick_dir if p.stick_dir.length() > 0.3 else -p.global_basis.z
	var pr := probe(d, 1.15)
	if pr.is_empty() or pr.top == INF:
		return false
	if pr.rel >= 0.45 and pr.rel <= 1.35:
		if pr.thick < 0.9:
			_start_vault(pr)
		else:
			_start_mantle(pr)
		return true
	return false


## B au sol : glissade (pente, escalier) ou glissade sous une barrière ; sinon la roulade normale. Vrai si l'action est prise.
func try_dodge(d: Vector3) -> bool:
	if not p.terrain:
		return false
	var dd := _flat(d) if d.length() > 0.1 else _flat(-p.global_basis.z)
	var sl := slope()
	var down: Vector3 = sl[0]
	if sl[1] > 0.015 and down != Vector3.ZERO and (dd.dot(down) > 0.25 or (p.sprinting and Vector2(p.velocity.x, p.velocity.z).dot(Vector2(down.x, down.z)) > 1.0)):
		_start_glide(down, p.sprinting or sprint_t < 0.6)
		return true
	if p.sprinting and low_obstacle(dd):
		_start_skid(dd)
		return true
	return false


## B en l'air, juste avant une grande réception : réception roulée (au lieu du petit dash aérien).
func try_air_dodge() -> bool:
	if not p.terrain:
		return false
	if p.velocity.y > -3.0 or air_peak - p.global_position.y < BIG_FALL - 0.6:
		return false
	var g := ground_at(p.global_position, 0.1)
	if g == INF or p.global_position.y - g > 2.2 or takeoff_g - g < 0.8:
		return false
	land_roll_t = ROLL_WINDOW
	return true


## Bonus de chute : plus il tombe de haut, plus son coup aérien frappe fort (×1 à ×2).
func fall_bonus() -> float:
	if not p.terrain or p.is_on_floor():
		return 1.0
	var g := ground_at(p.global_position, 0.1)
	if g == INF or takeoff_g - g < 0.8:
		return 1.0   # saut sur place (même très haut) : pas de bonus, seulement en tombant d'un rebord
	return 1.0 + clampf((air_peak - p.global_position.y - 1.0) / 2.5, 0.0, FALL_BONUS_MAX)


## Bonus de chute au moment de toucher le sol (chope plongeante, plongeon).
func land_bonus() -> float:
	if not p.terrain:
		return 1.0
	return 1.0 + clampf((last_fall - 1.0) / 2.5, 0.0, FALL_BONUS_MAX)


# ------------------------------------------------------------------ états

func _start(s: String) -> void:
	state = s
	t = 0.0
	_count(s)
	p.attack = ""
	p.roll = -1.0
	p.queued = false
	p.sprinting = s == "glide" and glide_long


func _start_vault(pr: Dictionary) -> void:
	_start("vault")
	wall_n = pr.n
	top = pr.top
	a0 = p.global_position
	var land: Vector3 = Vector3(pr.pos.x, a0.y, pr.pos.z) - wall_n * (pr.thick + 0.6)
	var g := ground_at(land, 0.5)
	a1 = Vector3(land.x, g if g != INF else a0.y, land.z)
	p.rotation.y = atan2(wall_n.x, wall_n.z)


func _start_mantle(pr: Dictionary) -> void:
	_start("mantle")
	wall_n = pr.n
	top = pr.top
	a0 = p.global_position
	a1 = Vector3(pr.pos.x, top + 0.02, pr.pos.z) - wall_n * 0.45
	p.rotation.y = atan2(wall_n.x, wall_n.z)


func _start_hang(pr: Dictionary) -> void:
	_start("hang")
	wall_n = pr.n
	top = pr.top
	a0 = Vector3(pr.pos.x, top - HANG_REACH, pr.pos.z) + wall_n * 0.33
	p.global_position = a0
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(wall_n.x, wall_n.z)
	hang_push = 0.0
	hang_ready = false
	p.get_parent().impact(0.03, 0.25)


func _start_glide(down: Vector3, long_: bool) -> void:
	glide_long = long_
	_start("glide")
	glide_dir = down
	glide_v = maxf(Vector2(p.velocity.x, p.velocity.z).length(), 9.0 if long_ else 6.0)
	p.sweep_hits.clear()
	p.rotation.y = atan2(-down.x, -down.z)
	_small(true)


func _start_skid(d: Vector3) -> void:
	_start("skid")
	glide_dir = d
	glide_v = 11.0
	p.sweep_hits.clear()
	p.rotation.y = atan2(-d.x, -d.z)
	_small(true)


func _end() -> void:
	_small(false)
	state = ""
	p.air = not p.is_on_floor()


## Une image de déplacement « en main ». Vrai si le héros est pris en charge (le reste de _physics_process est sauté).
func tick(dt: float) -> bool:
	if not p.terrain and state == "":
		return false
	regrab_t -= dt
	land_roll_t -= dt
	if state == "":
		w = move_toward(w, 0.0, dt * 8.0)
		return false
	t += dt
	w = move_toward(w, 1.0, dt * 14.0)
	match state:
		"vault":
			var u := clampf(t / VAULT_T, 0.0, 1.0)
			var pos := a0.lerp(a1, smoothstep(0.0, 1.0, u))
			var peak := maxf(top + 0.12, maxf(a0.y, a1.y) + 0.3)
			pos.y = lerpf(a0.y, a1.y, u) + (peak - lerpf(a0.y, a1.y, 0.5)) * sin(PI * u) * 1.0
			p.global_position = pos
			p.velocity = Vector3.ZERO
			if u >= 1.0:
				p.velocity = -wall_n * (p.speed * (p.SPRINT_MULT if p.sprinting else 1.0))
				_end()
		"mantle":
			var u := clampf(t / MANTLE_T, 0.0, 1.0)
			var up := smoothstep(0.0, 0.6, u)
			var fw := smoothstep(0.45, 1.0, u)
			p.global_position = Vector3(lerpf(a0.x, a1.x, fw), lerpf(a0.y, a1.y + 0.15, up) - 0.15 * fw, lerpf(a0.z, a1.z, fw))
			p.velocity = Vector3.ZERO
			if u >= 1.0:
				p.global_position = a1
				_end()
		"hang":
			p.global_position = a0
			p.velocity = Vector3.ZERO
			var d: Vector3 = p.stick_dir
			if d.dot(-wall_n) > 0.6 and hang_ready:
				hang_push += dt
			else:
				hang_push = 0.0
			if d.dot(-wall_n) < 0.3:
				hang_ready = true
			if Input.is_action_just_pressed("jump") or hang_push > 0.18:
				_start("climb")
				a1 = Vector3(a0.x, top + 0.02, a0.z) - wall_n * 0.8
			elif Input.is_action_just_pressed("roll") or d.dot(wall_n) > 0.6:
				regrab_t = 0.5
				p.velocity = wall_n * 2.0
				_end()
				p.air = true
		"climb":
			var u := clampf(t / CLIMB_T, 0.0, 1.0)
			var up := smoothstep(0.0, 0.55, u)
			var fw := smoothstep(0.5, 1.0, u)
			var pos := a0.lerp(Vector3(a0.x, top - 0.75, a0.z), up)
			pos = pos.lerp(a1, fw)
			p.global_position = pos
			p.velocity = Vector3.ZERO
			if u >= 1.0:
				p.global_position = a1
				_end()
		"heavy_land":
			p.velocity.x = 0.0
			p.velocity.z = 0.0
			p.velocity.y -= p.GRAVITY * dt
			p.move_and_slide()
			if t >= HEAVY_T:
				_end()
		"glide":
			var sl := slope()
			var steep: float = sl[1]
			var down: Vector3 = sl[0]
			if steep > 0.015 and down != Vector3.ZERO:
				glide_dir = glide_dir.slerp(down, minf(dt * 6.0, 1.0)).normalized()
				glide_v = minf(glide_v + 30.0 * steep * dt, GLIDE_MAX)
			else:
				glide_v = maxf(glide_v - (4.0 if glide_long else 9.0) * dt, 0.0)
			var steer: Vector3 = p.stick_dir - glide_dir * p.stick_dir.dot(glide_dir)
			glide_dir = (glide_dir + steer * dt * 1.5).normalized()
			p.rotation.y = lerp_angle(p.rotation.y, atan2(-glide_dir.x, -glide_dir.z), dt * 10.0)
			p.velocity.x = glide_dir.x * glide_v
			p.velocity.z = glide_dir.z * glide_v
			p.velocity.y -= p.GRAVITY * dt
			p.move_and_slide()
			_sweep(glide_dir)
			var held := Input.is_action_pressed("roll")
			if (not held and t > 0.2) or (glide_v < 2.0 and steep <= 0.015) or t > 6.0:
				if not _ceiling():
					_end()
		"skid":
			glide_v = maxf(glide_v - 11.0 * dt, 3.0)
			p.velocity.x = glide_dir.x * glide_v
			p.velocity.z = glide_dir.z * glide_v
			p.velocity.y -= p.GRAVITY * dt
			p.move_and_slide()
			_sweep(glide_dir)
			if t >= SKID_T and not _ceiling():
				_end()
			elif t > 2.0:
				_end()
	p._animate(dt)
	return true


func _sweep(d: Vector3) -> void:
	var kind: String = p.roll_kind
	var rd: Vector3 = p.roll_dir
	p.roll_kind = "slide"
	p.roll_dir = d
	p._sweep_hit()
	p.roll_kind = kind
	p.roll_dir = rd


## Après move_and_slide (héros libre) : marche, enjambée en sprint, rebord en l'air, réception, rebond mural.
func after_move(dt: float) -> void:
	if not p.terrain:
		return   # run classique : pas de déplacements avec le décor (les murets des salles restent des murs)
	var on_floor: bool = p.is_on_floor()
	var pos: Vector3 = p.global_position
	if on_floor:
		if was_air:
			last_fall = air_peak - pos.y if takeoff_g - pos.y > 0.8 else 0.0   # dénivelé réel : rebord, plateforme, bloc
			_landed(last_fall)
		air_peak = pos.y
		takeoff_g = pos.y
	else:
		air_peak = maxf(air_peak, pos.y) if was_air else pos.y
	was_air = not on_floor
	sprint_t = 0.0 if p.sprinting else sprint_t + dt
	if state != "":
		return
	# B maintenu en arrivant sur une pente (ou en roulant dessus) : la roulade devient une glissade.
	if on_floor and Input.is_action_pressed("roll") and p.attack == "" and (p.roll < 0.0 or p.roll_kind == "roll"):
		var sl := slope()
		var hv0 := Vector3(p.velocity.x, 0, p.velocity.z)
		if sl[1] > 0.015 and sl[0] != Vector3.ZERO and hv0.dot(sl[0]) > 1.5:
			_start_glide(sl[0], sprint_t < 0.6)
			return
	var hv := Vector3(p.velocity.x, 0, p.velocity.z)
	var d: Vector3 = p.stick_dir if p.stick_dir.length() > 0.3 else Vector3.ZERO
	# Rebond mural : esquive contre un mur.
	if p.roll >= 0.0 and p.roll_kind in ["roll", "dash"] and not bounced and p.is_on_wall():
		var n := _decor_wall()
		if n != Vector3.ZERO and n.dot(p.roll_dir) < -0.4:
			bounced = true
			p.roll_dir = _flat(p.roll_dir.bounce(n))
			p.roll = minf(p.roll, 0.05)
			p.rotation.y = atan2(-p.roll_dir.x, -p.roll_dir.z)
			p.velocity.y = 3.5
			p._flash(Color(0.8, 0.9, 1.0), 0.06)
			p.get_parent().impact(0.04, 0.35)
			_count("wall_bounce")
			return
	if p.roll < 0.0:
		bounced = false
	if p.attack != "" or p.roll >= 0.0 or p.hurt > 0.0 or d == Vector3.ZERO:
		return
	if on_floor:
		# Petite marche : il monte dessus sans sauter.
		if p.is_on_wall():
			var pr := probe(d, 0.45)
			if not pr.is_empty() and pr.top != INF and pr.rel > 0.04 and pr.rel <= STEP:
				p.global_position = Vector3(pos.x, pr.top + 0.02, pos.z) + d * 0.12
				_count("step")
				return
		# En sprint contre un muret ou une rambarde : il l'enjambe tout seul.
		if p.sprinting and hv.length() > 4.0:
			var pr2 := probe(d, 0.75)
			if not pr2.is_empty() and pr2.top != INF and pr2.rel >= 0.45 and pr2.rel <= 1.35 and pr2.thick < 0.9:
				_start_vault(pr2)
	elif regrab_t <= 0.0:
		# En l'air contre un bloc : il se hisse (bas) ou s'agrippe au rebord (haut).
		var pr3 := probe(d, 0.55)
		if pr3.is_empty() or pr3.top == INF:
			return
		if pr3.rel >= 0.25 and pr3.rel <= 1.05 and pr3.thick >= 0.3:
			_start_mantle(pr3)
		elif pr3.rel > 1.05 and pr3.rel <= HANG_REACH + 0.25 and p.velocity.y < 2.5:
			_start_hang(pr3)


## Normale du mur du décor touché à cette image (pas un sbire, pas un objet mobile), ou zéro.
func _decor_wall() -> Vector3:
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		if c.get_collider() is StaticBody3D and absf(c.get_normal().y) < 0.5:
			return _flat(c.get_normal())
	return Vector3.ZERO


func _landed(fall: float) -> void:
	if fall < BIG_FALL or state != "" or p.attack != "":
		return
	if land_roll_t > 0.0:
		land_roll_t = -1.0
		p.start_roll(_flat(-p.global_basis.z), "roll")   # réception roulée : aucun temps perdu
		_count("land_roll")
		p.get_parent().impact(0.03, 0.3)
		return
	_start("heavy_land")
	p.get_parent().impact(0.08, minf(0.5 + fall * 0.1, 1.1))
	if p.has_method("_shock_ring"):
		p._shock_ring(p.global_position)


# ------------------------------------------------------------------ poses (degrés, comme les fiches de coups)

func pose() -> Dictionary:
	var N = null
	match state:
		"vault":
			var u := clampf(t / VAULT_T, 0.0, 1.0)
			var k := sin(PI * u)
			return {"hips_pos": Vector3(0, 0.05 * k, 0), "hips": Vector3(-15 * k, 0, 45 * k), "spine": Vector3(-8, 0, -18 * k), "head": Vector3(8, 0, -22 * k),
				"sh_r": Vector3(55, 0, -15), "el_r": Vector3(0, 0, 0), "sh_l": Vector3(110, 0, 75 * k), "el_l": Vector3(20, 0, 0),
				"hip_l": Vector3(95 * k, 0, -25 * k), "kn_l": Vector3(-110 * k, 0, 0), "hip_r": Vector3(80 * k, 0, -15 * k), "kn_r": Vector3(-95 * k, 0, 0),
				"foot_l": N, "foot_r": N}
		"mantle", "climb":
			var u := clampf(t / (MANTLE_T if state == "mantle" else CLIMB_T), 0.0, 1.0)
			if state == "climb" and u < 0.45:
				var k2 := u / 0.45
				return {"hips_pos": Vector3(0, 0, 0.05), "hips": Vector3(5 - 20 * k2, 0, 0), "spine": Vector3(-10 * k2, 0, 0), "head": Vector3(-20 + 20 * k2, 0, 0),
					"sh_l": Vector3(lerpf(176, 150, k2), 0, 10), "el_l": Vector3(lerpf(5, 120, k2), 0, 0), "sh_r": Vector3(lerpf(176, 150, k2), 0, -10), "el_r": Vector3(lerpf(5, 120, k2), 0, 0),
					"hip_l": Vector3(20 + 40 * k2, 0, 0), "kn_l": Vector3(-30 - 50 * k2, 0, 0), "hip_r": Vector3(10, 0, 0), "kn_r": Vector3(-40, 0, 0), "foot_l": N, "foot_r": N}
			var k := sin(PI * minf(u * 1.2, 1.0))
			return {"hips_pos": Vector3(0, -0.15 * k, 0), "hips": Vector3(-38 * k, 0, 0), "spine": Vector3(-25 * k, 0, 0), "head": Vector3(25 * k, 0, 0),
				"sh_l": Vector3(70, 0, 15), "el_l": Vector3(10, 0, 0), "sh_r": Vector3(70, 0, -15), "el_r": Vector3(10, 0, 0),
				"hip_r": Vector3(110 * k, 0, 0), "kn_r": Vector3(-125 * k, 0, 0), "hip_l": Vector3(15 * k, 0, 0), "kn_l": Vector3(-40 * k, 0, 0), "foot_l": N, "foot_r": N}
		"hang":
			var sw := sin(t * 3.0) * 6.0
			return {"hips_pos": Vector3(0, 0, 0.04), "hips": Vector3(6 + sw, 0, 0), "spine": Vector3(4, 0, 0), "head": Vector3(-22, 0, 0),
				"sh_l": Vector3(176, 0, 8), "el_l": Vector3(4, 0, 0), "sh_r": Vector3(176, 0, -8), "el_r": Vector3(4, 0, 0),
				"hip_l": Vector3(18 - sw, 0, 0), "kn_l": Vector3(-25, 0, 0), "hip_r": Vector3(6 + sw, 0, 0), "kn_r": Vector3(-40, 0, 0), "foot_l": N, "foot_r": N}
		"heavy_land":
			var k := 1.0 - smoothstep(0.55, 1.0, t / HEAVY_T)
			return {"hips_pos": Vector3(0, -0.46 * k, 0.05 * k), "hips": Vector3(-38 * k, 0, 0), "spine": Vector3(-28 * k, 0, 0), "head": Vector3(30 * k, 0, 0),
				"sh_l": Vector3(55 * k, 0, 55 * k), "el_l": Vector3(30 * k, 0, 0), "sh_r": Vector3(100 * k, 0, -12 * k), "el_r": Vector3(8 * k, 0, 0),
				"foot_l": Vector3(-0.24, 0.02, -0.28), "foot_r": Vector3(0.24, 0.02, 0.24)}
		"glide":
			var wob := sin(t * 18.0) * 4.0
			return {"hips_pos": Vector3(0, -0.62, 0.0), "hips": Vector3(78, 0, wob), "spine": Vector3(12, 0, 0), "head": Vector3(-38, 0, 0),
				"sh_l": Vector3(160, 0, 35), "el_l": Vector3(25, 0, 0), "sh_r": Vector3(160, 0, -35), "el_r": Vector3(25, 0, 0),
				"hip_l": Vector3(-6, 0, 8), "kn_l": Vector3(-12, 0, 0), "hip_r": Vector3(-2, 0, -8), "kn_r": Vector3(-30, 0, 0), "foot_l": N, "foot_r": N}
		"skid":
			return {"hips_pos": Vector3(0, -0.6, 0.1), "hips": Vector3(62, 0, 0), "spine": Vector3(-22, 0, 0), "head": Vector3(-12, 0, 0),
				"hip_r": Vector3(25, 0, 0), "kn_r": Vector3(0, 0, 0), "hip_l": Vector3(8, 0, 0), "kn_l": Vector3(-100, 0, 0),
				"sh_l": Vector3(-40, 0, -35), "el_l": Vector3(10, 0, 0), "sh_r": Vector3(45, 0, -20), "el_r": Vector3(60, 0, 0), "foot_l": N, "foot_r": N}
	return {}

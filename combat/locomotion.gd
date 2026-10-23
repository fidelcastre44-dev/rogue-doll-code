class_name Locomotion
extends RefCounted
## Déplacements du héros avec le décor (v0.212, « Terrain d'essai ») :
##   - marche automatique sur une petite marche (≤ 0,4 m) ;
##   - enjamber un muret / une rambarde (automatique en sprint, ou A tout près) ;
##   - se hisser sur un bloc de 1 ou 2 m (A tout près, ou en sautant contre) : il monte directement (v0.216, retour de Thibaud) ;
##   - s'agripper au rebord d'un bloc haut (3 m et plus) en sautant contre, puis A / stick vers le mur = se hisser, B / stick à l'opposé
##     = lâcher ; X = se hisser en repoussant ce qui est en haut ; R1 = attraper la cheville d'un sbire au bord et le jeter dans le vide ;
##   - enjamber aussi les objets du décor (tables, chaises, caisses…) en sprint ou avec A (v0.216) ;
##   - glissade dans l'escalier ou sur la pente : B maintenu en descendant (sprint + B = glissade prolongée), fauche les sbires ;
##   - glisser sous un obstacle bas : sprint + B devant une barrière haute ;
##   - grande chute (3 m et plus, v0.216) : B juste avant de toucher le sol = réception roulée, sinon atterrissage lourd (petit temps mort) ;
##   - rebond mural : esquive contre un mur = il rebondit dessus et repart dans l'autre sens ;
##   - bonus de chute : plus il tombe de haut, plus son coup aérien (ou sa chope plongeante) frappe fort.
## Les états « en main » (enjambée, hissé, suspendu…) prennent le contrôle du héros : `tick()` renvoie vrai et le reste
## de player._physics_process est sauté.

const STEP := 0.42            # m : marche franchie sans sauter
const VAULT_T := 0.53         # s : enjambée (capture CMU 127_27 jouée 1,5× plus vite)
const MANTLE_T := 0.4         # s : se hisser sur un bloc de 1 m (plus long pour 2 m, voir mantle_dur)
const CLIMB_T := 0.6          # s : se hisser depuis le rebord
const HEAVY_T := 0.5          # s : atterrissage lourd (temps mort ; capture CMU 82_02 à sa vitesse)
const HEAVY_AMP := 2.0        # amorti de l'atterrissage lourd : 2× celui de la capture (chute de 2 m contre 0,7 m)
const VAULT_CLEAR := 0.67     # m : hauteur que la capture d'enjambée franchit d'elle-même (pieds à 0,79 m)
const BIG_FALL := 3.0         # m : au-delà, réception roulée ou atterrissage lourd (v0.216 : 3 m, avant 1,8 ; la plateforme de 2 m ne fige plus)
const HANG_MIN := 2.4         # m : un bloc plus haut que ça (3 m) = il s'agrippe au rebord ; en dessous (1 m, 2 m), il se hisse directement
const MANTLE_MAX := 2.3       # m : hauteur au-dessus des pieds jusqu'à laquelle il se hisse directement
const YANK_REACH := 1.5       # m : sbire au bord (au-dessus du héros agrippé) qu'il peut attraper par la cheville
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
var edge := Vector3.ZERO      # milieu du rebord saisi (haut du mur, côté face) : les mains s'y posent (IK des bras)
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
var mantle_dur := MANTLE_T    # durée du « se hisser » en cours (plus haut = un peu plus long)
var climb_atk := false        # agrippé + X : il se hisse en repoussant ce qui est en haut
var climb_hit := false
var yank_t := -1.0            # agrippé + R1 : geste du bras qui attrape la cheville (pose)
var yank_victim: Node3D = null  # v0.218 : le sbire attrapé (le bras va chercher sa cheville, tire, puis il se hisse)
var yank_done := false
const YANK_PULL := 0.16       # s : la main tient la cheville, il tire d'un coup
const YANK_T := 0.42          # s : fin du geste ; s'il a fait tomber quelqu'un, il enchaîne en se hissant
const CLIMB_PUSH := 0.3       # v0.218 (Thibaud) : X agrippé repousse seulement (était 0,6 × la force du coup lourd, il faisait tomber)


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


## Objet du décor (table, chaise, caisse…) devant, au même format que probe() (pos, n, top, rel, thick, dist), ou {}.
## Les objets sont des corps mobiles : probe() les ignore, on les cherche à part pour pouvoir les enjamber.
func prop_probe(d: Vector3, reach := 0.9) -> Dictionary:
	d = _flat(d)
	if d == Vector3.ZERO:
		return {}
	var o := p.global_position
	var best := {}
	var bd := reach + 0.6
	for b in p.get_tree().get_nodes_in_group("reactive"):
		if not b is RigidBody3D or not is_instance_valid(b) or b == p.held_prop or b.get_meta("broken", false):
			continue
		var bb := _aabb(b)
		if bb.size == Vector3.ZERO:
			continue
		var c := bb.get_center()
		var to := (c - o) * Vector3(1, 0, 1)
		if to.length() > bd + 0.8 or to.normalized().dot(d) < 0.6:
			continue
		# demi-épaisseur de l'objet dans la direction d, et distance jusqu'à sa face avant
		var half := absf(d.x) * bb.size.x * 0.5 + absf(d.z) * bb.size.z * 0.5
		var near := to.dot(d) - half
		if near > reach or near < -0.25:
			continue
		var top := bb.end.y
		if top - o.y < 0.3:
			continue   # trop bas : on marche dessus / à côté
		bd = near
		var pos := o + d * maxf(near, 0.0)
		pos.y = o.y + 0.5
		best = {"pos": pos, "n": -d, "top": top, "rel": top - o.y, "thick": half * 2.0, "dist": maxf(near, 0.0), "prop": b}
	return best


## Boîte englobante (monde) des rendus d'un objet.
func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D and c.mesh:
			var a: AABB = c.global_transform * c.mesh.get_aabb()
			out = a if first else out.merge(a)
			first = false
	return out


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
	var pp := prop_probe(d, 1.0)
	if not pp.is_empty() and pp.rel <= 1.35 and (pr.is_empty() or pp.dist < pr.dist):
		_start_vault(pp)   # table, chaise, caisse… : il l'enjambe (v0.216)
		return true
	if pr.is_empty() or pr.top == INF:
		return false
	if pr.rel >= 0.45 and pr.rel <= 1.35 and pr.thick < 0.9:
		_start_vault(pr)
		return true
	if pr.rel >= 0.45 and pr.rel <= MANTLE_MAX and pr.thick >= 0.3:
		_start_mantle(pr)   # bloc de 1 ou 2 m : il se hisse directement (v0.216)
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
	if p.velocity.y > -3.0:
		return false
	var g := ground_at(p.global_position, 0.1)
	if g == INF or p.global_position.y - g > 2.2 or takeoff_g - g < BIG_FALL - 0.1:
		return false   # seulement au-dessus d'un vrai grand dénivelé (3 m et plus, v0.216)
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
	if s != "climb":
		climb_atk = false
	climb_hit = false
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
	mantle_dur = MANTLE_T * lerpf(1.0, 1.45, clampf(pr.rel - 1.0, 0.0, 1.0))   # bloc de 2 m : un peu plus long
	wall_n = pr.n
	top = pr.top
	a0 = p.global_position
	a1 = Vector3(pr.pos.x, top + 0.02, pr.pos.z) - wall_n * 0.45
	edge = Vector3(pr.pos.x, top, pr.pos.z)
	p.rotation.y = atan2(wall_n.x, wall_n.z)


func _start_hang(pr: Dictionary) -> void:
	_start("hang")
	wall_n = pr.n
	top = pr.top
	a0 = Vector3(pr.pos.x, top - HANG_REACH, pr.pos.z) + wall_n * 0.33
	edge = Vector3(pr.pos.x, top, pr.pos.z)
	p.global_position = a0
	p.velocity = Vector3.ZERO
	p.rotation.y = atan2(wall_n.x, wall_n.z)
	hang_push = 0.0
	hang_ready = false
	yank_t = -1.0
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
	w = move_toward(w, 1.0, dt * (7.0 if state == "glide" else 14.0))   # glissade : il se met de côté, pas d'un coup
	match state:
		"vault":
			# trajectoire de la capture : avancée recalée pour retomber en a1, saut rehaussé si l'obstacle est plus haut
			var u := clampf(t / VAULT_T, 0.0, 1.0)
			var rt: Vector3 = p._track(CycleData.VAULT_ROOT, u)
			var end: Vector3 = p._track(CycleData.VAULT_ROOT, 1.0)
			var fw := -wall_n
			var dist := Vector2(a1.x - a0.x, a1.z - a0.z).length()
			var pos := a0 + fw * (-rt.z) * dist / maxf(-end.z, 0.01)
			var peak := 0.0
			for v in CycleData.VAULT_ROOT:
				peak = maxf(peak, v.y - CycleData.VAULT_ROOT[0].y)
			var extra := maxf(top - a0.y + 0.12 - VAULT_CLEAR, 0.0)   # pieds de la capture : 0,79 m au plus haut
			pos.y = a0.y + rt.y + extra * rt.y / maxf(peak, 0.01) + (a1.y - a0.y - end.y) * u
			p.global_position = pos
			p.velocity = Vector3.ZERO
			if u >= 1.0:
				p.velocity = -wall_n * (p.speed * (p.SPRINT_MULT if p.sprinting else 1.0))
				_end()
		"mantle":
			var u := clampf(t / mantle_dur, 0.0, 1.0)
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
			yank_t = yank_t + dt if yank_t >= 0.0 else -1.0
			if yank_t >= YANK_PULL and yank_victim and not yank_done:
				_yank_pull()
			if yank_t > YANK_T:
				yank_t = -1.0
				var pulled := yank_done
				yank_victim = null
				yank_done = false
				if pulled:   # v0.218 (Thibaud) : il a fait tomber le sbire, il se hisse dans la foulée
					_start("climb")
					climb_atk = false
					a1 = Vector3(a0.x, top + 0.02, a0.z) - wall_n * 0.8
					_count("yank_climb")
			if yank_t >= 0.0 or state != "hang":
				pass   # pendant le geste (ou s'il se hisse déjà) : rien d'autre
			elif Input.is_action_just_pressed("light"):
				_start("climb")   # X : il se hisse en repoussant ce qui est en haut (v0.216, idée de Thibaud)
				climb_atk = true
				a1 = Vector3(a0.x, top + 0.02, a0.z) - wall_n * 0.8
				_count("climb_attack")
			elif Input.is_action_just_pressed("grab") and yank_t < 0.0:
				_yank()   # R1 : attrape la cheville d'un sbire au bord et le jette dans le vide
			elif Input.is_action_just_pressed("jump") or hang_push > 0.18:
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
			if climb_atk and not climb_hit and u >= 0.5:
				climb_hit = true
				_climb_push()
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
			_landed(takeoff_g - pos.y)   # v0.216 : le figé dépend du dénivelé (sol quitté -> sol touché), pas de la hauteur du saut
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
				return
			var pp := prop_probe(d, 0.7)
			if not pp.is_empty() and pp.rel <= 1.35:
				_start_vault(pp)   # table, chaise, caisse… (v0.216)
	elif regrab_t <= 0.0:
		# En l'air contre un bloc : il se hisse (bas) ou s'agrippe au rebord (haut).
		var pr3 := probe(d, 0.55)
		if pr3.is_empty() or pr3.top == INF:
			return
		var g0 := ground_at(pos, 0.1)
		var block_h: float = pr3.top - (g0 if g0 != INF else pos.y)   # hauteur du bloc depuis le sol (pas depuis les pieds en l'air)
		if block_h <= HANG_MIN:
			if pr3.rel >= 0.25 and pr3.rel <= MANTLE_MAX and pr3.thick >= 0.3:
				_start_mantle(pr3)   # 1 m, 2 m : il se hisse directement (v0.216)
		elif pr3.rel > 1.0 and pr3.rel <= HANG_REACH + 0.25 and p.velocity.y < 2.5:
			_start_hang(pr3)   # 3 m : il s'agrippe au rebord


## Agrippé + X : à mi-hauteur, il lance une petite attaque qui repousse les sbires en haut, près du rebord.
func _climb_push() -> void:
	var at := edge - wall_n * 0.9
	for e in p.enemies:
		if not is_instance_valid(e) or e.parts.is_empty() or e.state in ["held", "swung"]:
			continue
		var c: Vector3 = e.parts.chest.global_position
		if c.y < top - 0.2 or ((c - at) * Vector3(1, 0, 1)).length() > 1.6:
			continue
		# v0.218 (Thibaud) : il le repousse seulement (recul debout, pas de chute) : peu de force, presque pas de déséquilibre
		e.hit(e.parts.chest, (-wall_n + Vector3.UP * 0.1).normalized() * p.heavy_force * CLIMB_PUSH, c, 6.0, 0.25 if e.state == "stand" else 0.0, true)
		if e.state == "stand":
			e.poise = maxf(e.poise, 0.3)
			e.slide += -wall_n * 2.2   # il recule de quelques pas
		_count("climb_push")
		p.get_parent().impact(0.06, 0.5)


## Agrippé + R1 : un sbire au bord, au-dessus de lui : il l'attrape par la cheville et le tire dans le vide, derrière lui.
func _yank() -> void:
	yank_t = 0.0
	var best: Node3D = null
	var bd := YANK_REACH
	for e in p.enemies:
		if not is_instance_valid(e) or e.parts.is_empty() or not e.state in ["stand", "down"]:
			continue
		var f: Vector3 = e.parts.pelvis.global_position
		if f.y < top - 0.3:
			continue   # pas sur le dessus du bloc
		var dd := ((f - edge) * Vector3(1, 0, 1)).length()
		if dd < bd:
			bd = dd
			best = e
	if best == null:
		return   # personne : le geste dans le vide, il reste agrippé
	yank_victim = best   # v0.218 (Thibaud) : le bras va chercher la cheville (_yank_pull à YANK_PULL), puis il se hisse
	yank_done = false
	if best.state == "stand":
		best.stun(0.5)   # surpris : il ne bouge plus le temps que la main l'attrape
	_count("yank")


## La main tient la cheville : il tire d'un coup, le sbire bascule par-dessus le bord et tombe dans le vide.
func _yank_pull() -> void:
	yank_done = true
	var e := yank_victim
	if not is_instance_valid(e) or e.parts.is_empty() or e.state in ["held", "swung"]:
		yank_done = false
		yank_victim = null
		return
	e.toss(wall_n * 6.0 + Vector3.UP * 3.0, 3.0)   # tiré par la cheville : il passe par-dessus le bord, dans le vide
	e.thrown()
	e.hp = maxf(e.hp - 4.0, 0.0)
	p._flash(Color(1, 0.85, 0.4), 0.06)
	p.get_parent().impact(0.08, 0.7)


## Normale du mur du décor touché à cette image (pas un sbire, pas un objet mobile), ou zéro.
func _decor_wall() -> Vector3:
	for i in p.get_slide_collision_count():
		var c := p.get_slide_collision(i)
		if c.get_collider() is StaticBody3D and absf(c.get_normal().y) < 0.5:
			return _flat(c.get_normal())
	return Vector3.ZERO


func _landed(fall: float) -> void:
	if fall < BIG_FALL - 0.1 or state != "" or p.attack != "":
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

## Mains posées sur le rebord pendant qu'il y est accroché ou qu'il se hisse : cibles (monde) et poids de l'IK des bras.
func hand_targets() -> Dictionary:
	var k := 0.0
	match state:
		"hang":
			k = 1.0
		"climb":
			k = 1.0 - smoothstep(0.68, 0.85, t / CLIMB_T)
		"mantle":
			k = 1.0 - smoothstep(0.55, 0.75, t / mantle_dur)
	if k <= 0.0:
		return {}
	var f := -wall_n
	var right := f.cross(Vector3.UP)
	var base := edge + f * 0.06 + Vector3.UP * 0.05   # poings posés sur le dessus, juste derrière l'arête
	var kr := k
	if state == "climb" and climb_atk:
		kr = k * (1.0 - smoothstep(0.35, 0.5, t / CLIMB_T))   # la main droite lâche le rebord pour frapper
	var r := base + right * 0.22
	if state == "hang" and yank_t >= 0.0:
		var e := yank_victim
		if e and is_instance_valid(e) and not e.parts.is_empty():   # v0.218 : la main droite va jusqu'à la cheville, la tient, tire
			var ankle: Vector3 = e.parts.shin_r.global_transform * Vector3(0, -0.2, 0)
			var reach := smoothstep(0.0, YANK_PULL, yank_t)
			var back := smoothstep(YANK_PULL + 0.1, YANK_T, yank_t)
			r = r.lerp(ankle, reach * (1.0 - back))
			kr = k
		else:
			kr = k * (1.0 - sin(PI * clampf(yank_t / YANK_T, 0.0, 1.0)))   # personne : le bras part dans le vide
	return {"l": base - right * 0.22, "r": r, "w": k * w, "wr": kr * w, "out": wall_n}


## Se hisser (rebord de 2 m : climb ; bloc de 1 m : mantle). Les mains restent sur le rebord (IK des bras, player.gd),
## le genou droit monte, le pied droit se pose sur le dessus, puis le gauche, et il se redresse.
func _climb_pose(u: float, low: bool) -> Dictionary:
	var N = null
	var f := -wall_n
	var right := f.cross(Vector3.UP)
	var on_top := func(side: float, back: float) -> Vector3:   # point du dessus, dans le repère du héros (cible de pied)
		var wp := edge + f * back + right * side + Vector3.UP * 0.02
		return p.global_basis.inverse() * (wp - p.global_position)
	var a := 0.45 if low else 0.5     # le pied droit arrive sur le dessus
	var b := 0.62 if low else 0.7     # le pied gauche suit
	var c := 0.85                     # debout
	var pull := smoothstep(0.0, a, u)
	var lean := smoothstep(a * 0.6, b, u) * (1.0 - smoothstep(b, 1.0, u))
	var pz := {"hips_pos": Vector3(0, -0.12 * lean, 0.05 * (1.0 - pull)), "hips": Vector3(-10 * pull - 30 * lean, 0, 0),
		"spine": Vector3(-8 - 30 * lean, 0, 0), "head": Vector3(-25 * (1.0 - pull) + 20 * lean, 0, 0),
		"sh_l": Vector3(150, 0, 15), "el_l": Vector3(60, 0, 0), "sh_r": Vector3(150, 0, -15), "el_r": Vector3(60, 0, 0),
		"hip_r": Vector3(lerpf(15, 110, pull), 0, -5), "kn_r": Vector3(lerpf(-35, -130, pull), 0, 0),
		"hip_l": Vector3(lerpf(5, 40, pull), 0, 5), "kn_l": Vector3(lerpf(-25, -70, pull), 0, 0), "foot_l": N, "foot_r": N}
	# pieds toujours guidés (IK) : pendus sous lui, le genou droit qui monte, puis posés sur le dessus l'un après l'autre
	var hang_r := Vector3(0.1, 0.05 + 0.45 * pull, 0.08 - 0.25 * pull)
	var hang_l := Vector3(-0.1, 0.05 + 0.2 * pull, 0.12)
	pz.foot_r = hang_r.lerp(on_top.call(0.12, 0.25 + 0.15 * smoothstep(a, c, u)), smoothstep(a - 0.12, a, u))
	pz.foot_l = hang_l.lerp(on_top.call(-0.14, 0.2 + 0.25 * smoothstep(b, c, u)), smoothstep(b - 0.12, b, u))
	if u >= c:   # debout : pieds de la garde
		var k := smoothstep(c, 1.0, u)
		pz.foot_r = pz.foot_r.lerp(p.GUARD.foot_r, k)
		pz.foot_l = pz.foot_l.lerp(p.GUARD.foot_l, k)
	return pz

func pose() -> Dictionary:
	var N = null
	match state:
		"vault":   # capture CMU 127_27 (saut par-dessus en courant)
			var pz: Dictionary = p._clip(CycleData.VAULT, clampf(t / VAULT_T, 0.0, 1.0))
			pz.foot_l = N
			pz.foot_r = N
			return pz
		"mantle", "climb":
			var cp := _climb_pose(clampf(t / (mantle_dur if state == "mantle" else CLIMB_T), 0.0, 1.0), state == "mantle")
			if state == "climb" and climb_atk:   # v0.218 (Thibaud) : revers du bras qui balaie le dessus du bloc (« dégage ! »)
				var uu := clampf((t / CLIMB_T - 0.33) / 0.42, 0.0, 1.0)
				var k := sin(PI * uu)
				var sw := smoothstep(0.15, 0.6, uu)   # le bras part replié sur la poitrine, puis balaie vers l'extérieur
				cp.sh_r = cp.sh_r.lerp(Vector3(100, lerpf(40, -35, sw), lerpf(25, -70, sw)), k)
				cp.el_r = cp.el_r.lerp(Vector3(lerpf(100, 15, sw), 0, 0), k)
				cp.spine = cp.spine + Vector3(0, lerpf(18, -22, sw), 0) * k   # le buste accompagne le revers
				cp.head = cp.head + Vector3(-10, lerpf(-15, 25, sw), 8) * k   # il regarde de travers celui qu'il dégage
			return cp
		"hang":
			var sw := sin(t * 3.0) * 6.0
			if yank_t >= 0.0:   # bras droit qui attrape la cheville, puis il tire en se jetant en arrière (v0.218)
				var k2 := sin(PI * clampf(yank_t / YANK_T, 0.0, 1.0))
				var pull := smoothstep(YANK_PULL - 0.03, YANK_PULL + 0.08, yank_t) * (1.0 - smoothstep(YANK_PULL + 0.12, YANK_T, yank_t))
				return {"hips_pos": Vector3(0, -0.04 * pull, 0.04 + 0.12 * pull), "hips": Vector3(4 + 14 * pull, 0, 0), "spine": Vector3(6 - 12 * k2 + 18 * pull, -15 * k2 - 20 * pull, 0), "head": Vector3(-28 - 10 * k2 + 20 * pull, 10 * pull, 0),
					"sh_l": Vector3(176, 0, 8), "el_l": Vector3(4, 0, 0), "sh_r": Vector3(176 - 60 * k2, 0, -8 - 30 * k2), "el_r": Vector3(4 + 50 * k2, 0, 0),
					"hip_l": Vector3(14, 0, 4), "kn_l": Vector3(-28, 0, 0), "hip_r": Vector3(4, 0, -4), "kn_r": Vector3(-42, 0, 0), "foot_l": N, "foot_r": N}
			return {"hips_pos": Vector3(0, 0, 0.04), "hips": Vector3(4 + sw, 0, 0), "spine": Vector3(6, 0, 0), "head": Vector3(-28, 0, 0),
				"sh_l": Vector3(176, 0, 8), "el_l": Vector3(4, 0, 0), "sh_r": Vector3(176, 0, -8), "el_r": Vector3(4, 0, 0),
				"hip_l": Vector3(14 - sw, 0, 4), "kn_l": Vector3(-28, 0, 0), "hip_r": Vector3(4 + sw, 0, -4), "kn_r": Vector3(-42, 0, 0), "foot_l": N, "foot_r": N}
		"heavy_land":   # capture CMU 82_02 (saut d'un rebord), amorti exagéré : le bassin descend deux fois plus
			var u := clampf(t / HEAVY_T, 0.0, 1.0)
			var pz: Dictionary = p._clip(CycleData.HEAVY_LAND, u)
			var g: float = p.GUARD.get("hips_pos", Vector3.ZERO).y
			pz.hips_pos.y = g + (pz.hips_pos.y - g) * HEAVY_AMP * (1.0 - smoothstep(0.7, 1.0, u))
			return pz
		"glide":   # accroupi de côté, façon surf (retour de Paul) : pieds l'un devant l'autre (droit devant), main gauche qui traîne derrière, vers le sol
			var wob := sin(t * 18.0) * 3.0
			return {"hips_pos": Vector3(0.05, -0.44, 0.04), "hips": Vector3(-8, 72, 6 + wob), "spine": Vector3(-35, -18, -12), "head": Vector3(5, -50, 6),
				"sh_l": Vector3(40, 0, 0), "el_l": Vector3(10, 0, 0), "sh_r": Vector3(70, 0, -55), "el_r": Vector3(45, 0, 0),
				"foot_r": Vector3(0.04, 0.02, -0.36), "foot_l": Vector3(-0.03, 0.02, 0.3)}   # pied droit devant : c'est lui qui fauche
		"skid":
			return {"hips_pos": Vector3(0, -0.6, 0.1), "hips": Vector3(62, 0, 0), "spine": Vector3(-22, 0, 0), "head": Vector3(-12, 0, 0),
				"hip_r": Vector3(25, 0, 0), "kn_r": Vector3(0, 0, 0), "hip_l": Vector3(8, 0, 0), "kn_l": Vector3(-100, 0, 0),
				"sh_l": Vector3(-40, 0, -35), "el_l": Vector3(10, 0, 0), "sh_r": Vector3(45, 0, -20), "el_r": Vector3(60, 0, 0), "foot_l": N, "foot_r": N}
	return {}

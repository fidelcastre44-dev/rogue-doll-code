extends CharacterBody3D
## Perso : squelette en blocs (mêmes proportions que l'ennemi) animé par poses clés + IK des jambes.
## Une pose place le bassin et les pieds au sol ; l'IK calcule hanches et genoux pour que les pieds restent plantés.
## Garde de boxe orthodoxe, course, saut, roulade, combo de poings jab / direct / uppercut (léger), coup de poing aérien, chassé (lourd).

@export var speed := 5.0
@export var light_force := 30.0
@export var heavy_force := 110.0
@export var attack_speed := 1.35
## Aimantation (se tourner vers l'ennemi, s'approcher, rester collé en l'air) : 0 = désactivée (le jeu), 1 = très forte.
## 0.5 = le réglage historique (portée 2.2 m, 60°). Réglable dans le labo.
@export_range(0.0, 1.0, 0.05) var lock_power := 0.0
var lock_on: bool:
	get:
		return lock_power > 0.0
	set(v):
		lock_power = 0.5 if v else 0.0


## Valeur selon la force d'aimantation : `weak` à 0+, `mid` à 0.5 (réglage historique), `strong` à 1.
func _lk(weak: float, mid: float, strong: float) -> float:
	if lock_power <= 0.5:
		return lerpf(weak, mid, lock_power / 0.5)
	return lerpf(mid, strong, (lock_power - 0.5) / 0.5)
# Coups au choix (les anciens restent disponibles comme améliorations, voir AMELIORATIONS.md).
@export_enum("roll", "dash") var dodge_move := "roll"   # B / Rond : roulade, strafe éclair
@export_enum("none", "slide", "flop") var sprint_attack := "none"   # X pendant le sprint : rien, tacle glissé, ou plongeon pantin
@export_enum("kick", "hikick", "spinkick", "axe", "quake") var heavy_move := "kick"   # Y / Triangle au sol
@export_enum("jab") var air_move := "jab"                         # X / Carré en l'air
@export_enum("slam", "swing", "throw") var throw_move := "slam"   # chope (R1) : fracas, grand tour, lancer visé, massue humaine
# Modificateurs (cumulables) :
@export var double_jump := false   # A en l'air : 2e saut
@export var dive := false          # A en l'air : plongeon (après le double saut s'il y en a un), onde de choc à l'atterrissage
@export var parry := false         # garde levée au dernier moment : parade, l'attaquant est sonné
@export var riposte := false       # juste après une parade : coup critique
@export var guard_gauge := false
@export_enum("none", "power", "shoryu", "hadoken") var charge_move := "none"   # Y maintenu : attaque chargée (en plus du Y normal)
@export var sweep_triple := false  # amélioration du balayage (X + bas) : 3 tours au lieu d'un
@export var air_slam := false      # R1 en l'air : chope plongeante, il l'emporte en piqué et le plaque au sol (sinon pas de chope en l'air)   # la garde remplit la jauge de spécial
@export_enum("base", "hook", "knee") var light_move := "base"                     # combo X : jab + direct, ou + uppercut   # vitesse de toutes les animations d'attaque (1 = d'origine)

const AIR_HIT_BOUNCE := 4.2   # m/s : rebond vers le haut quand un coup aérien touche
const JAB_MAGNET_RANGE := 1.5  # m : aimantation du jab, seulement sur un sbire tout proche…
const JAB_MAGNET_ANGLE := 28.0 # … et presque droit devant (degrés)
const COMBO := ["jab", "cross", "upper"]   # tous les coups du combo (l'uppercut n'y est qu'avec l'amélioration)
const COLOR := Color(0.25, 0.45, 0.85)
const HURT_TIME := 0.35
const GRAVITY := 20.0
const JUMP_SPEED := 6.5     # m/s : ~1 m de haut, ~0.65 s en l'air
const JUMP_WINDUP := 0.06   # flexion avant de décoller
const LAND_TIME := 0.15     # amorti à l'atterrissage
const ROLL_TIME := 0.64     # v0.214 : roulade capturée, jouée 2× plus vite que la capture (0,5 s avant)
const ROLL_SPEED := 7.0     # m/s au départ de la roulade, ralentit jusqu'à ROLL_END_SPEED (v0.214 : roulade plus longue, même distance)
const ROLL_END_SPEED := 2.0
const MAX_AIR := 3          # coups aériens par saut
const COMBO_WINDOW := 0.25   # secondes après la fin d'un coup pendant lesquelles le suivant enchaîne encore
const GRAB_REACH := 0.75    # la chope attrape un ennemi dont le buste est à cette distance devant toi (à 0,75 m près)
const GRAB_DMG := 10.0
const COLLAR_HOLD_STAND := 1.5     # chopé debout : il se dégage au bout de 1,5 s
const COLLAR_HOLD_RAGDOLL := 4.0   # chopé au sol ou en l'air (sonné) : on le garde bien plus longtemps
const GRAB_COOLDOWN := 1.0
const PROP_DMG := 15.0      # objet du décor : fracassé, lancé ou en grand tour   # s : délai minimum entre deux chopes
const MOMENTUM := 4.0       # m/s : petite avancée donnée à chaque coup quand tu te déplaces (sans aimantation)
const LOCK_RANGE := 2.2     # verrouillage : au-delà, on ne se tourne pas vers l'ennemi
const LOCK_ANGLE := 60.0    # degrés de part et d'autre de là où tu regardes
const IDEAL := {"jab": 0.85, "cross": 0.85, "upper": 0.8, "air": 0.7, "hammer": 0.7, "kick": 1.1, "hikick": 0.8, "spinkick": 0.8, "air_kick": 0.95, "grab": GRAB_REACH, "axe": 1.0, "knee": 0.6, "shoryu": 0.5, "hook": 0.75, "elbow": 0.55}   # distance au buste où chaque coup touche le mieux
const DASH_SPEED := 9.0     # m/s : un ennemi verrouillé trop loin, on fonce sur lui avant le coup
const APPROACH_MAX := 11.0  # m/s, vitesse max de l'approche verrouillée
const ROLL_AFTER_HIT := 0.05   # roulade possible ce temps-là après l'impact d'un coup (le reste du coup reste punissable)
const ROLL_HURT_OK := 0.15     # touché : roulade possible quand il reste moins que ça de sonné (au bout de 0,2 s)
const ROLL_EXIT := 0.14        # après ce temps de roulade, n'importe quelle action la coupe (coup, saut, chope, autre esquive)
const SWEEP_TIME := 0.45      # balayage retourné (X + bas)
const SWEEP_TIME_3 := 1.0     # balayage triple : 3 tours
const SWEEP_CD := 0.35        # délai après la fin du balayage avant d'en relancer un
const SWEEP_SPEED := 5.0      # m/s au départ, ralentit jusqu'à ROLL_END_SPEED
const SWEEP_FROM := 0.06      # fenêtre où la jambe balaie
const SWEEP_TO := 0.38
const SWEEP_DMG := 8.0
const THROW_WIND := 0.9     # lancer visé : temps d'élan max (R1 maintenu)
const THROW_DMG := 14.0
const CLUB_HOLD := 5.0      # massue humaine : on ne le garde pas plus longtemps
const CLUB_HITS := 3        # massue : coups max, puis il est lâché
const CLUB_DMG := 5.0       # dégâts pris par la massue elle-même à chaque coup
const SPRINT_MULT := 1.4   # sprint : vitesse de course multipliée (1.75 avant la v0.21 : trop rapide)
const FLOP_SPEED := 12.5   # plongeon pantin : élan vers l'avant
const FLOP_JUMP := 7.0
const FLOP_DMG := 12.0
const SLIDE_TIME := 0.55    # tacle glissé
const SLIDE_SPEED := 11.0
const DASH_TIME := 0.16     # strafe éclair
const STRAFE_SPEED := 17.0
const DIVE_CHARGE := 0.2   # plongeon : temps d'armé (en temps d'attaque) avant de piquer
const DIVEKICK_SPEED := 10.0  # piqué : vitesse vers l'avant et vers le bas
const DIVE_SPEED := 18.0
const AIR_SLAM_SPEED := 16.0   # chope plongeante : vitesse du piqué
const AIR_SLAM_DMG := 16.0    # plongeon : vitesse vers le sol
const DIVE_RADIUS := 2.6    # rayon de l'onde de choc
const DIVE_DMG := 10.0
const FLIP_JUMP := 5.2      # salto avant (axe kick)
const SHORYU_POP := 7.0      # m/s : vitesse vers le haut quand il est lâché au sommet
const SHORYU_JUMP := 9.5    # shoryuken : il monte avec le poing
const KNEE_JUMP := 5.5      # genou volant : il décolle
const CHARGE_MAX := 0.8     # coup chargé : charge pleine
const CHARGE_NEED := {"none": 1.0, "power": 1.0, "shoryu": 0.8, "hadoken": 1.0}   # temps de charge max de chaque attaque chargée (au max, elle part toute seule)
const HOLD_X := 0.22        # X tenu plus que ça : balayage retourné
const HOLD_T := 0.18        # Y tenu plus que ça : on passe en charge
const CHARGE_CRIT := 0.15   # créneau du critique, juste après la charge pleine
const PARRY_WINDOW := 0.35  # parade : garde levée moins de ce temps avant le coup
const PARRY_STUN := 1.3     # l'attaquant est sonné
const RIPOSTE_WINDOW := 0.9 # riposte critique possible ce temps-là après une parade
const SPECIAL_MAX := 100.0
const SWING_HOLD := 3.0     # grand tour : on ne peut pas le tenir plus longtemps, il est lâché tout seul
const SWING_BASE := 7.0     # rad/s : le grand tour tourne tout seul à cette vitesse
const SWING_TURN := 14.0     # rad/s : vitesse de rotation max du grand tour (c'est le stick qui fait tourner)
const SWING_DMG := 12.0
const SLAM_LIFT := 0.22     # temps pour le soulever au-dessus de la tête (le reste jusqu'à "active" = l'abattre au sol)

# Les coups (durées, zone de frappe, effets, poses clés) sont des fiches dans res://moves/ (une par coup, voir combat/move_data.gd) :
# on les règle dans l'inspecteur de Godot. Ici, ATK les présente au format historique (ATK[id].active, ATK[id].get("heavy")...).
var ATK: Dictionary = MoveLibrary.table()
# Les poses : res://moves/poses.tres (garde + chaque pose d'attaque écrite comme « la garde + ces changements »).
var GUARD: Dictionary = MoveLibrary.poses().guard
var POSE_DIFF: Dictionary = MoveLibrary.poses().diffs
const JOINTS := ["hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r", "hip_l", "kn_l", "hip_r", "kn_r"]
const THIGH := 0.43
const SHIN := 0.45

# nom, parent, position du pivot (relative au parent), taille du bloc (rayon en x pour une sphère), centre du bloc (relatif au pivot)
const SKELETON := [
	["hips", "", Vector3(0, 0.9, 0), Vector3(0.32, 0.2, 0.2), Vector3(0, 0.1, 0)],
	["spine", "hips", Vector3(0, 0.2, 0), Vector3(0.38, 0.42, 0.22), Vector3(0, 0.23, 0)],
	["head", "spine", Vector3(0, 0.46, 0), Vector3(0.13, 0, 0), Vector3(0, 0.14, 0)],
	["sh_l", "spine", Vector3(-0.26, 0.43, 0), Vector3(0.1, 0.3, 0.1), Vector3(0, -0.15, 0)],
	["el_l", "sh_l", Vector3(0, -0.3, 0), Vector3(0.09, 0.28, 0.09), Vector3(0, -0.14, 0)],
	["fist_l", "el_l", Vector3(0, -0.3, 0), Vector3(0.07, 0, 0), Vector3.ZERO],
	["sh_r", "spine", Vector3(0.26, 0.43, 0), Vector3(0.1, 0.3, 0.1), Vector3(0, -0.15, 0)],
	["el_r", "sh_r", Vector3(0, -0.3, 0), Vector3(0.09, 0.28, 0.09), Vector3(0, -0.14, 0)],
	["fist_r", "el_r", Vector3(0, -0.3, 0), Vector3(0.07, 0, 0), Vector3.ZERO],
	["hip_l", "hips", Vector3(-0.1, 0, 0), Vector3(0.13, 0.42, 0.13), Vector3(0, -0.21, 0)],
	["kn_l", "hip_l", Vector3(0, -THIGH, 0), Vector3(0.11, 0.45, 0.11), Vector3(0, -0.225, 0)],
	["foot_l", "kn_l", Vector3(0, -SHIN, 0), Vector3.ZERO, Vector3.ZERO],
	["hip_r", "hips", Vector3(0.1, 0, 0), Vector3(0.13, 0.42, 0.13), Vector3(0, -0.21, 0)],
	["kn_r", "hip_r", Vector3(0, -THIGH, 0), Vector3(0.11, 0.45, 0.11), Vector3(0, -0.225, 0)],
	["foot_r", "kn_r", Vector3(0, -SHIN, 0), Vector3.ZERO, Vector3.ZERO],
]

var enemy: Node3D       # cible courante (verrouillage, chope tenue)
var enemies := []        # tous les sbires de l'arène
var sweep_hits := {}     # balayage : sbires déjà fauchés
var attack := ""
var t := 0.0
var hit_done := false
var run_phase := 0.0
const IDLE_AMP := 0.6   # amplitude de la garde au repos capturée (le boxeur de la capture rebondit beaucoup)
var gait_v := 0.0   # vitesse au sol (m/s) : choisit marche ou course et le rythme des foulées
var run_mix := 0.0   # 0 = garde, 1 = course
var from := {}       # pose au moment où l'attaque démarre
var base := {}       # pose de la frame courante (garde/course)
var shown := {}      # pose affichée (base ou attaque) : point de départ du coup suivant
var queued := false  # appui poing gardé en mémoire
var last := ""       # dernier coup terminé
var combo_left := 0.0
var roll := -1.0          # temps écoulé dans la roulade, -1 = pas de roulade
var roll_dir := Vector3.ZERO
var jump_wait := -1.0     # flexion avant décollage en cours, -1 = non
var air := false
var air_mix := 0.0
var land := 0.0
var air_hits := 0
var jump_buf := 0.0
var grab_buf := 0.0
var heavy_buf := 0.0
var roll_buf := 0.0
var air_buf := 0.0
var sweep_hit := false
var air_heavy_used := false
var collar_hits := 0
var swing_angle := 0.0   # grand tour : angle parcouru
var swing_w := 0.0
var swing_hold := 0.0   # temps depuis qu'on le tient par les pieds
var throw_t := 0.0      # lancer visé : élan accumulé
var club_hits := 0      # massue : coups donnés avec ce sbire
var air_jumps := 0      # sauts en l'air faits (double saut, plongeon)
var air_dash_used := false
var charging := false
var y_hold := -1.0
var charge_power := 1.0   # puissance de la dernière attaque chargée (0..1)
var y_air := -1.0       # Y appuyé en l'air : appui court ou maintenu ?
var x_held := 0.0       # depuis combien de temps X est enfoncé
var x_fired := false      # Y appuyé, on attend de savoir si c'est un appui court ou maintenu
var orb: MeshInstance3D = null   # coup chargé en cours (Y maintenu)
var charge_t := 0.0
var charge_flashed := false
var hit_mult := 1.0     # bonus du prochain coup (charge, riposte)
var hit_crit := false
var light_buf := 0.0
var roll_kind := "roll"   # esquive en cours (roulade, balayage, strafe, ou tacle glissé lancé du sprint)
var sprinting := false
var ragdoll_t := -1.0      # plongeon pantin : temps passé en ragdoll (-1 = pas en ragdoll)
var rag := {}              # morceaux du ragdoll du héros
var rag_nodes := []
var rag_top := 0.0
var sprint_mix := 0.0
var tap_t := 9.0          # temps depuis le dernier relâché du stick (double tap = sprint)
var tap_dir := Vector3.ZERO
var stick_was := 0.0
var grab_cd := 0.0
var sweep_cd := 0.0
var sweep_rev := 0
var collar_held := 0.0     # depuis quand on le tient par le col
var collar_limit := 3.0    # au-delà, il se dégage   # délai entre deux chopes (pas de spam)
var jump_yaw := 0.0   # orientation au moment du saut
var stick_dir := Vector3.ZERO   # direction du stick à cette image (les coups partent par là)
var sho_blocked := false
var sho_hold := false
var sho_victim: Node3D = null   # celui qui monte collé au poing (gardé à part : la cible peut changer en route)
var held_prop: RigidBody3D = null   # objet du décor tenu
var prop_rot := Basis()
var prop_t := 0.0
var prop_wind := 0.0
var prop_sweep := {}
var flying := []                     # objets lancés en vol   # shoryuken : l'ennemi monte collé au poing
var swing_sign := -1.0     # sens du grand tour
var swing_stick := 0.0
var swing_stick_ok := false
var sho_wait := false   # shoryuken : le saut part à l'impact, pas pendant l'accroupi
var guard_t := 0.0      # depuis combien de temps la garde est levée
var riposte_t := 0.0    # temps restant pour une riposte critique
var special := 0.0      # jauge de spécial (R2)
var swap_feet := false
var guarding := false    # garde (LB / L1 maintenu)
var guard_mix := 0.0
var block_stun := 0.0    # recul après un coup paré   # grand tour : quelle cheville dans quelle main
var collar_q := false    # droite gardée en mémoire pendant la précédente
var connected := false   # le coup en cours a touché
var approach := false    # approche verrouillée : on glisse vers l'ennemi pour arriver pile à l'impact
var attack_id := 0       # numéro du coup en cours (l'ennemi s'en sert pour réagir une fois par coup)
var slam_o := Vector3.ZERO   # où il se tenait au moment de la chope
var slam_f := Vector3.FORWARD
var slam_c0 := Vector3.ZERO  # buste de l'ennemi au moment de la chope
var hp := 100.0
var hurt := 0.0        # temps restant sonné après un coup reçu (pas de contrôle)
var mat := StandardMaterial3D.new()
var flash_mat := StandardMaterial3D.new()
var wind_key: Node3D = null   # clé de remontage dans le dos (elle tourne)
var j := {}          # pivots du squelette
var ups: HeroUps     # améliorations de bouton et coups « À tester » de la v0.212
var btn_ups := {}    # améliorations de bouton : {id: [boutons]} (impact, triple, renvoi, defense, tazer, zone)
# Formes débloquables (v0.212) : actives par défaut (run classique inchangée), coupées en Vanilla dans la salle des paliers.
@export var form_dropkick := true    # Y en sprint
@export var form_capoeira := true    # Y en sortie de roulade
@export var form_counter := true     # X en sortie de roulade (contre tournant)
@export var form_superjump := true   # A maintenu
@export var web := false             # toile d'araignée (R1 sans personne à portée)
@export var wave := false            # la vague (L1 + X)
@export var rain := false            # pluie d'objets (R2)
@export var sidestep := false        # pas de côté (B sans stick)
@export var terrain := false
@export var trampoline := true       # coup « fun » (v0.212) : presque inutile, donné gratuitement, pour rire         # déplacements avec le décor (carte de test : labo, salle des paliers)
@export_enum("suplex", "tomoe") var collar_b := "suplex"   # chope + B
var lc: Locomotion   # déplacements avec le décor (v0.212) : enjamber, se hisser, rebord, glissades, réception, rebond mural


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	platform_floor_layers = 1   # le corps de l'ennemi n'est jamais un sol qui nous transmettrait sa vitesse
	platform_wall_layers = 0
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	var cs := CollisionShape3D.new()
	cs.shape = CapsuleShape3D.new()
	cs.shape.radius = 0.3
	cs.shape.height = 1.6
	cs.position.y = 0.8
	add_child(cs)
	floor_snap_length = 0.35   # reste collé aux marches et aux pentes en descendant
	lc = Locomotion.new(self)
	ups = HeroUps.new(self)
	mat.albedo_color = COLOR
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0)
	for s in SKELETON:
		var pivot := Node3D.new()
		pivot.position = s[2]
		(j[s[1]] if s[1] != "" else self).add_child(pivot)
		j[s[0]] = pivot
		if s[3] == Vector3.ZERO and not s[0].begins_with("fist"):
			continue
		pivot.add_child(_cube(s[0], s[4]))
	_overlay(self)
	wind_key = j.spine.find_child("key", true, false)
	_animate(0.0)


func _physics_process(dt: float) -> void:
	if ragdoll_t >= 0.0:   # plongeon pantin : le corps est un vrai ragdoll, le perso suit
		_ragdoll_tick(dt)
		return
	var inp := Input.get_vector("left", "right", "up", "down")
	var dir := Vector3(inp.x, 0, inp.y).rotated(Vector3.UP, get_viewport().get_camera_3d().global_rotation.y)   # relatif à la caméra
	stick_dir = dir
	_sprint_input(dir)
	if lc.tick(dt):
		return   # enjambée, rebord, glissade… : le décor prend la main
	ups.tick(dt)
	var grounded := is_on_floor()
	# On ne bute contre l'ennemi que s'il est debout : son corps en l'air ou au sol (ragdoll, crispé) nous poussait et nous éjectait.
	collision_mask = 1 | 2   # seuls les sbires debout nous bloquent (les corps en ragdoll sont sur une autre couche)
	if attack in PENALTY:
		collision_mask = 1   # couché sur lui ou à côté : on ne monte pas sur son corps
	if attack == "" and roll < 0:
		_pick_target(dir)
	var roll_to := dir   # la roulade suit le stick, même sonné
	if hurt > 0:   # sonné : les entrées sont ignorées
		hurt -= dt
		inp = Vector2.ZERO
		dir = Vector3.ZERO
	roll_buf -= dt
	if Input.is_action_just_pressed("roll"):
		roll_buf = 0.15
	# Fin de roulade : passée l'invulnérabilité, une action la coupe.
	light_buf -= dt
	if Input.is_action_pressed("light"):
		x_held += dt
		if not is_on_floor() or roll >= 0 or attack in ["collar", "collar_punch", "swing", "throw_release", "headbutt"]:
			x_fired = true   # appui commencé en l'air, pendant une esquive ou une chope : pas de balayage
	else:
		x_held = 0.0
		x_fired = false
	if Input.is_action_just_pressed("light"):
		light_buf = 0.15   # gardé en mémoire : un coup pressé pendant la roulade part dès qu'elle peut être coupée
	if roll >= (_dodge_time() if roll_kind == "sweep" else ROLL_EXIT) and (light_buf > 0 or heavy_buf > 0 or grab_buf > 0 or jump_buf > 0 or Input.is_action_just_pressed("heavy") or Input.is_action_just_pressed("grab") or Input.is_action_just_pressed("jump")):
		roll = -1.0
		since_roll = 0.0 if roll_kind in ["roll", "dash"] else 9.0
	var free := roll < 0 and jump_wait < 0 and hurt <= 0
	combo_left -= dt
	jump_buf -= dt
	grab_buf -= dt
	heavy_buf -= dt
	if Input.is_action_just_pressed("grab"):
		grab_buf = 0.15
	if Input.is_action_just_pressed("heavy"):
		heavy_buf = 0.15
	if Input.is_action_just_pressed("jump"):
		jump_buf = 0.15   # appui gardé en mémoire : appuyer un peu trop tôt compte quand même
	var holding := (attack.begins_with("collar") and attack != "collar_finish") or attack in ["swing", "club_hold", "club_swing", "air_slam", "prop_hold", "prop_wind", "prop_swing", "web"] or (attack in ATELIER_HOLDS and not (attack in ["suplex", "hip_throw", "tomoe"] and hit_done))
	since_roll += dt
	_atelier_inputs(grounded, holding)
	if attack == "swing":
		_swing(dt, dir)
	elif attack in ["club_hold", "club_swing"]:
		_club(dt)
	elif attack == "air_slam":
		_air_slam_hold()
	elif attack in ["prop_hold", "prop_wind", "prop_swing"]:
		_prop_hold(dt, dir)
	elif attack == "web":
		ups.web_tick(dt)
	elif attack in ATELIER_HOLDS:
		pass   # coups de l'atelier : voir _atelier_tick
	elif holding:
		_collar(dt)
	if Input.is_action_just_pressed("guard"):
		guard_t = 0.0
	else:
		guard_t += dt
	riposte_t -= dt
	if y_hold >= 0.0:
		y_hold += dt
		if not Input.is_action_pressed("heavy"):
			y_hold = -1.0
			_start_heavy()   # relâché vite : le Y normal
		elif y_hold >= HOLD_T:
			y_hold = -1.0
			start({"power": "charge", "shoryu": "charge_sho", "hadoken": "charge_hado"}[charge_move])
			charge_t = 0.0
			charge_flashed = false
	if attack in ["charge", "charge_sho", "charge_hado"]:
		_charge(dt)
	if roll_buf > 0 and not grounded and roll < 0 and attack == "" and lc.try_air_dodge():
		roll_buf = 0.0   # grande chute : B juste avant de toucher le sol = réception roulée
	if roll_buf > 0 and (grounded or air_dash_n < air_dodges) and roll < 0 and hurt <= ROLL_HURT_OK and not holding and not attack in AIR_LOCKED and (attack == "" or t >= _roll_ok(attack) or (not grounded and ATK[attack].get("air", false))):
		roll_buf = 0.0
		if not grounded:
			air_dash_n += 1
			air_dash_used = air_dash_n >= air_dodges
		hurt = 0.0
		jump_wait = -1.0
		if grounded and attack == "" and lc.try_dodge(roll_to):
			pass   # pente / escalier : glissade ; sprint sous une barrière : glissade basse
		elif grounded and sidestep and roll_to.length() < 0.2:
			start_roll(global_basis.z, "step")   # B sans stick : petit pas en arrière (esquive réussie = contre critique)
		else:
			start_roll(roll_to, "" if grounded else "dash")   # en l'air : esquive aérienne (petit dash, une fois par saut)
	elif jump_buf > 0 and grounded and free and not holding and not attack in PENALTY and not attack in AIR_LOCKED and (attack == "" or (connected and t >= ATK[attack].active + 0.04)):
		jump_buf = 0.0
		if attack == "" and lc.try_jump():
			pass   # muret, rambarde, bloc bas tout près : il l'enjambe ou se hisse dessus
		else:
			attack = ""   # saut d'annulation : un coup qui a touché peut être coupé par un saut (uppercut puis saut = jongle)
			queued = false
			jump_wait = JUMP_WINDUP
	elif jump_buf > 0 and not grounded and free and not holding and (attack == "" or ATK[attack].get("air", false)) and jump_wait < 0:
		var max_jumps := int(double_jump) + int(dive)
		if air_jumps < max_jumps:
			jump_buf = 0.0
			air_jumps += 1
			if double_jump and air_jumps == 1:
				velocity.y = JUMP_SPEED * 0.95   # double saut, en salto avant
				start("flip_jump")
			else:
				start("dive")   # plongeon : il charge en l'air (geste du marteau), puis pique vers le sol
				velocity = Vector3.ZERO
	air_buf -= dt
	if InputMap.has_action("special") and Input.is_action_just_pressed("special") and free and not holding:
		ups.try_rain()   # R2 : pluie d'objets
	if sprint_attack != "none" and sprinting and grounded and attack == "" and roll < 0 and Input.is_action_just_pressed("light") and free and not holding:
		light_buf = 0.0
		sprinting = false
		x_fired = true
		if sprint_attack == "slide":
			start_roll(dir, "slide")   # X en plein sprint : tacle glissé
		else:
			if dir.length() > 0.2:
				rotation.y = atan2(-dir.x, -dir.z)
			x_fired = true
			start("flop_prep")   # X en plein sprint : temps d'arrêt, il plie les jambes... puis il se jette en ragdoll
			velocity = Vector3.ZERO
	elif x_held >= HOLD_X and not x_fired and grounded and roll < 0 and sweep_cd <= 0 and hurt <= 0 and not holding and not attack in ["grab", "flop_prep", "flop_land"] and not attack in PENALTY:
		x_fired = true   # X maintenu : balayage retourné (le jab parti à l'appui est coupé)
		light_buf = 0.0
		queued = false
		sweep_rev = 0
		sweep_cd = (SWEEP_TIME_3 if sweep_triple else SWEEP_TIME) + SWEEP_CD   # pas de spam : il finit sa rotation, puis un petit délai
		start_roll(-global_basis.z, "sweep")
	elif (Input.is_action_just_pressed("light") or (light_buf > 0 and attack == "")) and free and not holding:
		light_buf = 0.0
		if ups.try_wave() or ups.try_disarm():
			pass   # L1 + X : la vague ; juste après une parade : désarmer
		elif _atelier_light(grounded):
			pass   # sortie de roulade, ennemi couché devant...
		elif grounded:
			queued = true
		else:
			air_buf = 0.2   # gardé en mémoire : le marteau suivant part dès que le précédent le permet
	if air_buf > 0 and free and not grounded and air_hits < _air_combo().size() and not attack in AIR_LOCKED and (attack == "" or (_air_chain() and t >= ATK[attack].cancel)):
		air_buf = 0.0
		air_hits += 1
		start(_air_combo()[air_hits - 1])   # en l'air aussi : jab, direct, puis le coup spécial s'il est débloqué
	if heavy_buf > 0 and free and not holding:
		if grounded and _can_cancel():
			heavy_buf = 0.0
			queued = false
			if _atelier_heavy():
				pass   # sprint, sortie de roulade, ennemi couché, objet au sol, mur...
			elif charge_move != "none" and Input.is_action_pressed("heavy"):
				y_hold = 0.0   # appui court = coup lourd normal ; maintenu = attaque chargée
			else:
				_start_heavy()
		elif not grounded and not air_heavy_used and (attack == "" or (_air_chain() and t >= ATK[attack].cancel)):
			heavy_buf = 0.0
			air_heavy_used = true
			if Input.is_action_pressed("heavy"):
				y_air = 0.0   # appui court = chassé sauté ; maintenu = coup de pied en piqué
			else:
				_air_kick()
	grab_cd -= dt
	sweep_cd -= dt
	if y_air >= 0.0:
		y_air += dt
		if grounded:
			y_air = -1.0
		elif not Input.is_action_pressed("heavy"):
			y_air = -1.0
			_air_kick()
		elif y_air >= HOLD_T:
			y_air = -1.0
			rotation.y = jump_yaw   # il garde la direction qu'il avait au saut
			start("dive_kick")   # Y maintenu en l'air : coup de pied en piqué, en diagonale vers le sol
	if grab_buf > 0 and grab_cd <= 0 and free and not grounded and not air_slam and attack == "" and web and not holding:
		grab_buf = 0.0
		ups.try_web()   # toile d'araignée : marche aussi en l'air
	if grab_buf > 0 and grab_cd <= 0 and free and (_can_cancel() if grounded else (air_slam and (attack == "" or (_air_chain() and t >= ATK[attack].cancel)))):   # coup paré -> chope ; en l'air seulement avec la chope plongeante
		grab_buf = 0.0
		queued = false
		grab_cd = GRAB_COOLDOWN   # pas de chope en continu
		if sprinting and grounded and tackle_up:
			sprinting = false
			tackle_into = ""
			start("tackle")   # R1 en plein sprint : plaquage (amélioration)
		elif not grounded and (attack == "super_jump" or super_air):
			start("sj_grab")   # du haut du super saut : il plonge sur un sbire et l'emporte (chope plongeante)
		elif ups.try_web():
			pass   # personne à portée : il tire un fil (toile d'araignée)
		else:
			start("grab")
	# Combo : un appui pendant un coup est gardé en mémoire ; le coup suivant part dès que le précédent a touché.
	if queued and roll < 0 and _can_cancel():
		queued = false
		var combo := _combo()
		var i := combo.find(attack if attack != "" else last)
		start(combo[i + 1] if i >= 0 and i < combo.size() - 1 and (attack != "" or combo_left > 0) else "jab")
	if roll >= 0:
		roll += dt
		var sweep := roll_kind == "sweep"
		var start_sp: float = {"roll": ROLL_SPEED, "sweep": SWEEP_SPEED, "slide": SLIDE_SPEED, "dash": STRAFE_SPEED, "step": 7.0}[roll_kind]
		var sp := lerpf(start_sp, ROLL_END_SPEED if roll_kind != "slide" else 1.5, roll / _dodge_time())
		velocity.x = roll_dir.x * sp
		velocity.z = roll_dir.z * sp
		if sweep and sweep_triple:   # triple tour : on se déplace aussi vite qu'en marchant pour aller faucher les autres
			velocity.x = stick_dir.x * speed
			velocity.z = stick_dir.z * speed
		if roll_kind == "dash" and not grounded:
			velocity.y = 0.0   # strafe en l'air : à plat
		if sweep:
			var rev := int(roll / _dodge_time() * (3.0 if sweep_triple else 1.0))
			if rev != sweep_rev:
				sweep_rev = rev
				sweep_hits.clear()   # chaque tour peut refaucher
		if sweep and roll >= SWEEP_FROM and roll <= _dodge_time() - 0.07:
			_sweep_hit()
		if roll_kind == "slide" and roll >= 0.04 and roll <= SLIDE_TIME - 0.12:
			_sweep_hit()   # le tacle fauche tout ce qui est sur sa ligne
		if roll >= _dodge_time():
			roll = -1.0
			since_roll = 0.0 if roll_kind in ["roll", "dash"] else 9.0
	else:
		# Garde : maintenue au sol, hors attaque ; on avance lentement, tourné vers l'ennemi. Un coup ou une esquive la coupe.
		guarding = Input.is_action_pressed("guard") and grounded and attack == "" and jump_wait < 0 and hurt <= 0
		block_stun = maxf(block_stun - dt, 0.0)
		var mult := 0.2 if attack != "" or jump_wait >= 0 else 1.0
		if guarding:
			mult = 0.0 if block_stun > 0 else 0.3
		if holding:
			mult = 0.45 if attack in ["swing", "club_hold", "club_swing"] else 0.55   # on peut marcher en le tenant (par le col, ou par les pieds pendant le grand tour)
		var accel := 40.0 if grounded else 14.0   # en l'air on garde du contrôle, mais moins vif
		if sprinting and attack == "" and not guarding and grounded:
			mult *= SPRINT_MULT
		velocity.x = move_toward(velocity.x, dir.x * speed * mult, accel * dt)
		velocity.z = move_toward(velocity.z, dir.z * speed * mult, accel * dt)
		var c := _lock_point()
		if guarding and c != Vector3.INF:
			var to := (c - global_position) * Vector3(1, 0, 1)
			if to.length() > 0.05:
				rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 15.0 * dt)   # en garde, on fait face à l'ennemi
		elif (attack == "" or holding) and attack != "swing" and attack != "club_swing" and dir.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), (8.0 if holding else 15.0) * dt)
	if lock_on:
		_air_lock(dt, grounded)
		_approach(dt)
	# Coups aériens : ils suivent la courbe du saut (plus de suspension en l'air) ; c'est le rebond quand ils touchent qui fait monter.
	if attack == "dive_kick":
		velocity = -global_basis.z * DIVEKICK_SPEED + Vector3.DOWN * DIVEKICK_SPEED   # 45° vers le sol
	if sho_hold:
		_sho_carry()
	if not flying.is_empty():
		_fly_props(dt)

	if attack == "dive":
		if t < DIVE_CHARGE:
			velocity = Vector3(0, 0.6, 0)   # suspendu pendant qu'il arme
		else:
			if velocity.y > -DIVE_SPEED:
				velocity = -global_basis.z * 2.0 + Vector3.DOWN * DIVE_SPEED
			velocity.y = minf(velocity.y, -DIVE_SPEED)
	_atelier_tick(dt)
	if attack == "slam" or y_hold >= 0.0 or attack in ["charge", "charge_sho", "charge_hado"] or attack == "flop_prep" or attack == "dive_land" or attack == "quake" or attack == "airslam_land" or (attack == "flop_land" and t < 0.3) or (attack == "headbutt" and t < ATK.headbutt.active):
		velocity.x = 0.0   # planté pendant qu'il soulève et fracasse (ou qu'il charge)
		velocity.z = 0.0
	if jump_wait >= 0:
		jump_wait -= dt
		if jump_wait < 0:
			velocity.y = JUMP_SPEED
	velocity.y -= GRAVITY * dt
	if attack != "":
		t += dt * attack_speed
	_animate(dt)
	if attack != "":
		var a: Dictionary = ATK[attack]
		if attack == "slam" and not hit_done and t < a.active:
			_hold()
		if attack == "headbutt" and not hit_done and enemy and enemy.state == "held":
			# bras qui se tendent : il le tient à bout de bras en se penchant en arrière, puis le ramène vers sa tête
			var hf := -global_basis.z
			var reach := 0.62 + 0.3 * smoothstep(0.0, 0.12, t) - 0.35 * smoothstep(0.17, 0.24, t)
			enemy.hold(Basis(Vector3.UP.cross(hf), deg_to_rad(15)) * Basis(Vector3.UP, atan2(-hf.x, -hf.z)), global_position + hf * reach + Vector3.UP * 1.25)
		if not hit_done and t >= a.active:
			hit_done = true
			do_hit(a)
			if attack == "shoryu" and sho_wait:
				sho_wait = false
				velocity.y = SHORYU_JUMP * lerpf(0.55, 1.0, charge_power)   # il jaillit vers le ciel (plus haut s'il a bien chargé)
		elif attack in ["dive_kick", "wall_run", "wall_run_h"] and hit_done and not connected and not sho_blocked:
			do_hit(a)   # le piqué touche tout le long de sa descente
		elif attack == "bicycle" and hit_done and not connected and t < 0.34:
			do_hit(a)   # la jambe touche tout le long de son arc
		elif attack == "shoryu" and hit_done and not connected and not sho_blocked and t < 0.2:
			do_hit(a)   # le poing qui monte continue de chercher le menton sur toute sa course
		if t >= a.end and attack == "club_swing":
			attack = "club_hold"   # on le tient toujours par les pieds
			t = 0.15
		elif t >= a.end and attack == "prop_bash":
			attack = "prop_hold"   # il tient toujours l'objet
			t = 0.15
			prop_t = 0.2
		elif t >= a.end and attack == "collar_punch":
			attack = "collar"   # on le tient toujours
			t = 0.12
			if collar_q:
				collar_q = false
				start("collar_punch")
		elif t >= a.end:
			last = attack
			combo_left = COMBO_WINDOW
			attack = ""
	move_and_slide()
	lc.after_move(dt)
	if air and is_on_floor():
		land = LAND_TIME
		air_hits = 0
		air_heavy_used = false
		air_buf = 0.0
		air_jumps = 0
		air_dash_used = false
		air_dash_n = 0
		if attack == "air_slam" and enemy and enemy.state == "held":
			enemy.slam(-global_basis.z, AIR_SLAM_DMG * lc.land_bonus())   # plaqué au sol : il rebondit (plus fort de plus haut)
			start("airslam_land")
			land = 0.0
			connected = true
			_gain(AIR_SLAM_DMG * 0.6)
			_shock_ring(global_position - global_basis.z * 0.7)
			get_parent().impact(0.12, 1.1)
		super_used = false
		if super_air and not ATK.get(attack, {}).get("air", false):
			_atelier_land("")
		if ATK.get(attack, {}).get("air", false):
			var was := attack
			attack = ""
			if _atelier_land(was):
				pass
			elif was == "dive":
				start("dive_land")   # poings dans le sol
				land = 0.0
				_dive_shock()
	# Sécurité : un coup sans fin prévue (piqué, drop kick…) qui reste bloqué (contre un sbire en garde, un mur, un objet)
	# ou qui dure anormalement se termine : le héros n'est jamais figé.
	if attack != "" and ATK.get(attack, {}).get("end", 0.0) >= 10.0 and not attack in ["charge", "charge_sho", "charge_hado", "tackle", "prop_hold", "prop_wind", "prop_shield", "collar", "swing", "club_hold", "air_slam", "cheese_grater", "cheese_grater_r", "prop_swing", "flop", "flop_prep", "web"]:
		var stuck: bool = attack == "dive_kick" and (sho_blocked or is_on_wall())
		if stuck or t > 3.0 * attack_speed:
			var was1 := attack
			attack = ""
			if was1 == "dive_kick":
				velocity = global_basis.z * 3.0 + Vector3.UP * 3.0   # il rebondit en arrière
			elif is_on_floor():
				_atelier_land(was1)
	# Sécurité : un coup aérien bloqué jusqu'à la réception qui n'a jamais quitté le sol (mur, plafond...) se termine quand même.
	if attack in ["drop_kick", "superman", "sj_grab"] and is_on_floor() and not air and t > 0.4:
		var was0 := attack
		attack = ""
		_atelier_land(was0)
	if not air and not is_on_floor():
		jump_yaw = rotation.y   # direction au décollage
	air = not is_on_floor()


## Façon jeu de combat : dès qu'un coup au sol a passé son impact, n'importe quel autre coup peut le couper.
## Seule la chope ratée ne s'annule pas (c'est sa punition).
## Combo de X : jab, direct ; l'amélioration ajoute l'uppercut en 3e coup.
func _combo() -> Array:
	if light_move == "two":
		return ["jab", "cross"]   # (tests) combo à 2 coups
	return ["jab", "cross", "upper" if light_move in ["base", "upper"] else light_move]   # 3e coup : uppercut de base ; crochet ou genou volant en amélioration


## Combo de X en l'air : le même que celui du sol (jab, direct, puis uppercut / crochet / genou si débloqué).
func _air_combo() -> Array:
	if air_move == "hammer":
		return ["hammer", "hammer", "hammer"]   # ancien marteau (retiré du jeu, gardé pour les vieux tests)
	var c := ["air", "air_cross"]
	if light_move != "two":
		c.append({"hook": "air_hook", "knee": "air_knee"}.get(light_move, "air_upper"))   # uppercut de base
	return c


## Jab et direct : petite aimantation, seulement sur un sbire tout proche et presque droit devant (là où on regarde ou pousse le stick).
## Il se tourne vers lui et fait le petit pas qui manque pour toucher ; sinon, aucun élan.
func _jab_magnet(kind: String) -> float:
	var look := stick_dir.normalized() if stick_dir.length() > 0.3 else -global_basis.z
	var best: Node3D = null
	var bd := JAB_MAGNET_RANGE
	for e in enemies:
		if e.parts.is_empty() or e.state in ["held", "swung", "dead"]:
			continue
		var to: Vector3 = (e.parts.chest.global_position - global_position) * Vector3(1, 0, 1)
		if to.length() < bd and look.angle_to(to) < deg_to_rad(JAB_MAGNET_ANGLE):
			bd = to.length()
			best = e
	if best == null:
		return 0.0
	var to2: Vector3 = (best.parts.chest.global_position - global_position) * Vector3(1, 0, 1)
	rotation.y = atan2(-to2.x, -to2.z)
	enemy = best
	var gap: float = to2.length() - IDEAL[kind]
	return clampf(gap / maxf(ATK[kind].active / attack_speed, 0.05), 0.0, 3.0)


func _light_air() -> bool:
	return ATK.get(attack, {}).get("light_air", false)


## Coups aériens qu'on peut enchaîner : poings en l'air, et le genou volant.
func _air_chain() -> bool:
	return _light_air() or attack in ["knee", "flip_jump", "shoryu", "super_jump", "tramp"]


func _can_cancel() -> bool:
	return attack == "" or (not attack in ["grab", "prop_hold", "prop_wind", "prop_swing", "prop_slam", "prop_toss", "air", "hammer", "air_kick", "knee", "axe", "shoryu", "air_slam", "dive_kick", "flop", "flip_jump", "dive_land", "dive", "charge", "charge_sho", "charge_hado", "headbutt", "collar", "collar_punch", "club_hold", "club_swing", "swing"] and t >= ATK[attack].cancel)


## Moment du coup à partir duquel on peut rouler : juste après l'impact (ou un délai propre au coup, ex. chope ratée).
func _roll_ok(kind: String) -> float:
	var a: Dictionary = ATK[kind]
	return minf(a.get("roll", a.active + ROLL_AFTER_HIT), a.cancel)


func start_roll(dir: Vector3, kind := "") -> void:
	from = shown
	_hado_orb(-1.0)
	attack = ""
	queued = false
	roll = 0.0
	sweep_hit = false
	sweep_hits.clear()
	roll_kind = kind if kind != "" else dodge_move
	roll_dir = dir.normalized() if dir.length() > 0.1 else -global_basis.z
	if roll_kind in ["roll", "slide"]:
		rotation.y = atan2(-roll_dir.x, -roll_dir.z)
	if roll_kind == "dash" and dir.length() <= 0.1:
		roll_dir = global_basis.z   # strafe sans direction : petit pas en arrière


func _dodge_time() -> float:
	return {"roll": ROLL_TIME, "sweep": SWEEP_TIME_3 if sweep_triple else SWEEP_TIME, "slide": SLIDE_TIME, "dash": DASH_TIME, "step": 0.26}[roll_kind]


## Balayage : la jambe tendue au ras du sol fauche l'ennemi (une fois), même en garde (coup bas) ; il tombe.
func _sweep_hit() -> void:
	var foot: Vector3 = j.foot_r.global_position
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = SphereShape3D.new()
	q.shape.radius = 0.45
	q.transform = Transform3D(Basis(), foot + Vector3.UP * 0.15)
	q.collision_mask = 2 | 8
	# Sens dans lequel la jambe balaie (elle tourne dans le sens horaire vu de dessus) : ses pieds partent par là.
	var side := Vector3.DOWN.cross((foot - global_position) * Vector3(1, 0, 1)).normalized()
	if roll_kind == "slide":
		side = roll_dir   # tacle : ses pieds partent dans le sens de la glissade
	for h in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var part: RigidBody3D = h.collider
		var victim = part.get_parent()
		if not victim.has_method("trip") or sweep_hits.has(victim):
			continue
		sweep_hits[victim] = true   # chaque sbire n'est fauché qu'une fois, mais un balayage peut en faucher plusieurs
		sweep_hit = true
		if ups:
			ups.on_hit(victim, "")
		if victim.state == "stand":
			victim.trip(side, SWEEP_DMG)
		else:
			victim.hit(part, (side + Vector3.UP * 0.6).normalized() * heavy_force * 0.8, foot, SWEEP_DMG, 1.0, true)
		get_parent().impact(0.07, 0.6)


## Coup reçu : recul, flash, sonné un instant ; l'attaque en cours est annulée.
func take_hit(dir: Vector3, dmg: float, attacker: Node = null) -> void:
	if lc:
		lc.cancel()   # touché suspendu, en glissade… : il lâche tout
	if ups and ups.absorb_hit(dir):
		return   # défense : l'ennemi ou l'objet tenu encaisse à sa place
	y_hold = -1.0
	if attack == "prop_shield" and (-global_basis.z).dot(-dir) > -0.3:   # objet-bouclier : il encaisse à ta place
		shield_hits += 1
		velocity += dir * 1.5
		get_parent().impact(0.05, 0.4)
		if shield_hits >= SHIELD_HITS:
			_break_prop()
		return
	if guarding and (-global_basis.z).dot(-dir) > -0.6:   # paré : la garde couvre devant et les côtés, seuls les coups vraiment de dos passent
		if parry and guard_t <= PARRY_WINDOW:   # garde levée au dernier moment : parade
			if attacker and attacker.has_method("stun"):
				attacker.stun(PARRY_STUN)
				if ups and ups.has("tazer", "L1"):
					ups.on_hit(attacker, "wave")   # parade électrique
			if riposte:
				riposte_t = RIPOSTE_WINDOW
			block_stun = 0.0
			_gain(12.0)
			get_parent().impact(0.09, 0.5)
			_flash(Color(1, 1, 1), 0.08)
			return
		velocity += dir * 2.5
		block_stun = 0.15
		if guard_gauge:
			_gain(6.0)
		get_parent().impact(0.04, 0.2)
		_flash(Color(0.7, 0.8, 1.0), 0.05)
		return
	if attack in ["drop_land", "sm_land"]:   # au sol après un coup risqué : il encaisse mais reste couché (pas d'annulation)
		hp = maxf(hp - dmg, 0.0)
		get_parent().impact(0.05, 0.5)
		_flash(Color.WHITE, 0.07)
		return
	guarding = false
	_hado_orb(-1.0)   # touché pendant la charge : la boule d'énergie disparaît
	_drop_held()   # touché pendant une chope : on lâche celui qu'on tenait (sinon il restait figé)
	hp = maxf(hp - dmg, 0.0)
	attack = ""
	queued = false
	jump_wait = -1.0
	hurt = HURT_TIME
	velocity += dir * 5.0
	get_parent().impact(0.05, 0.5)
	_flash(Color.WHITE, 0.07)
	await get_tree().create_timer(0.07, true, false, true).timeout
	if hp <= 0 and get_parent().get("run") == null:
		hp = 100.0   # shortcut: pas encore de mort du joueur, la manche recommence (vie pleine, sbires neufs)
		get_parent().reset_enemies()


## Plongeon pantin : le héros devient un vrai ragdoll (un corps physique par membre, reliés par des articulations),
## projeté en avant avec une rotation aléatoire. Il fauche les sbires qu'il percute, puis se relève là où il est tombé.
const RAG_MASS := {"hips": 10.0, "spine": 12.0, "head": 4.0, "sh_l": 2.0, "el_l": 1.5, "sh_r": 2.0, "el_r": 1.5, "hip_l": 5.0, "kn_l": 4.0, "hip_r": 5.0, "kn_r": 4.0}
const RAG_LIMIT := {"spine": 35.0, "head": 45.0, "sh_l": 80.0, "sh_r": 80.0, "el_l": 70.0, "el_r": 70.0, "hip_l": 70.0, "hip_r": 70.0, "kn_l": 65.0, "kn_r": 65.0}


func _ragdoll_on() -> void:
	var launch := -global_basis.z * FLOP_SPEED + Vector3.UP * FLOP_JUMP
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * randf_range(3.0, 7.0) + global_basis.x * -randf_range(2.0, 6.0)   # rotation au hasard (plutôt vers l'avant)
	var com: Vector3 = j.spine.global_position
	for s in SKELETON:
		if s[3] == Vector3.ZERO:
			continue
		var b := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		if s[3].y == 0:
			cs.shape = SphereShape3D.new()
			cs.shape.radius = s[3].x
		else:
			cs.shape = BoxShape3D.new()
			cs.shape.size = s[3]
		b.add_child(cs)
		b.add_child(_cube(s[0], Vector3.ZERO))
		if s[0] in ["el_l", "el_r"]:   # le gant suit l'avant-bras
			b.add_child(_cube("fist_" + s[0].right(1), Vector3(0, -0.3, 0) - s[4]))
		_overlay(b)
		b.mass = RAG_MASS.get(s[0], 3.0)
		b.collision_layer = 16   # couche à part : il ne se cogne qu'au sol
		b.collision_mask = 1
		b.angular_damp = 1.0
		b.gravity_scale = 1.6
		get_parent().add_child(b)
		b.global_transform = j[s[0]].global_transform * Transform3D(Basis(), s[4])
		b.linear_velocity = launch + spin.cross(b.global_position - com)
		b.angular_velocity = spin
		rag[s[0]] = b
		rag_nodes.append(b)
	for s in SKELETON:
		if not rag.has(s[0]) or s[1] == "" or not rag.has(s[1]):
			continue
		var jt := Generic6DOFJoint3D.new()
		get_parent().add_child(jt)
		jt.global_position = j[s[0]].global_position
		jt.node_a = jt.get_path_to(rag[s[1]])
		jt.node_b = jt.get_path_to(rag[s[0]])
		var lim := deg_to_rad(RAG_LIMIT.get(s[0], 45.0))
		for ax in ["x", "y", "z"]:
			jt.call("set_param_" + ax, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -lim)
			jt.call("set_param_" + ax, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, lim)
		rag_nodes.append(jt)
	j.hips.visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	sweep_hits.clear()
	ragdoll_t = 0.0
	rag_top = 0.0
	attack = "flop"
	get_parent().impact(0.0, 0.3)


func _ragdoll_tick(dt: float) -> void:
	ragdoll_t += dt
	var pel: RigidBody3D = rag.hips
	rag_top = maxf(rag_top, pel.global_position.y)
	global_position = Vector3(pel.global_position.x, 0, pel.global_position.z)   # le perso (et la caméra) suivent le corps
	# Son corps percute et fauche les sbires (chacun une fois).
	for n in ["hips", "spine", "head", "kn_l", "kn_r"]:
		var b: RigidBody3D = rag[n]
		if b.linear_velocity.length() < 2.5:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = SphereShape3D.new()
		q.shape.radius = 0.6
		q.transform = Transform3D(Basis(), b.global_position)
		q.collision_mask = 2 | 8
		for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
			var victim = r.collider.get_parent()
			if not victim.has_method("hit") or sweep_hits.has(victim):
				continue
			sweep_hits[victim] = true
			var d := (b.linear_velocity * Vector3(1, 0, 1)).normalized()
			victim.hit(r.collider, (d + Vector3.UP * 0.7).normalized() * heavy_force * 0.9, r.collider.global_position, FLOP_DMG, 1.0, true)
			_gain(FLOP_DMG * 0.6)
			get_parent().impact(0.06, 0.6)
	if (ragdoll_t > 0.5 and pel.linear_velocity.length() < 1.2) or ragdoll_t > 2.2:
		_ragdoll_off()


func _ragdoll_off() -> void:
	var pel: RigidBody3D = rag.hips
	var fwd := -(pel.global_basis.z * Vector3(1, 0, 1))
	if fwd.length() < 0.1:
		fwd = -(pel.global_basis.y * Vector3(1, 0, 1))
	global_position = Vector3(pel.global_position.x, 0, pel.global_position.z)
	if fwd.length() > 0.05:
		rotation.y = atan2(-fwd.x, -fwd.z)
	for nd in rag_nodes:
		nd.queue_free()
	rag_nodes.clear()
	rag.clear()
	ragdoll_t = -1.0
	j.hips.visible = true
	collision_layer = 4
	attack = ""
	shown = _resolve(_pose("flop_lie"))
	start("flop_land")   # il se relève là où il est tombé
	from = shown


## Sprint : clic du stick gauche (L3), ou double tap du stick dans une direction. Il dure tant qu'on pousse le stick.
func _sprint_input(dir: Vector3) -> void:
	var m := dir.length()
	tap_t += get_physics_process_delta_time()
	if Input.is_action_just_pressed("sprint") and m > 0.3:
		sprinting = true
	if m > 0.8 and stick_was <= 0.8:   # le stick vient d'être poussé
		if tap_t < 0.28 and tap_dir.dot(dir.normalized()) > 0.7:
			sprinting = true   # double tap dans la même direction
		tap_dir = dir.normalized()
	if m < 0.3 and stick_was >= 0.3:
		tap_t = 0.0   # relâché : le prochain appui proche compte comme double tap
	if m < 0.3:
		sprinting = false
	stick_was = m


## Chope plongeante : il le tient devant lui, couché sur le dos, et pique vers le sol avec lui.
func _air_slam_hold() -> void:
	var f := -global_basis.z
	if t >= 0.1:
		velocity = f * 2.0 + Vector3.DOWN * AIR_SLAM_SPEED
	var u := smoothstep(0.0, 0.2, t)
	var b := Basis(Vector3.UP.cross(f), deg_to_rad(lerpf(15.0, 75.0, u))) * Basis(Vector3.UP, atan2(-f.x, -f.z))   # basculé sur le dos
	var hands: Vector3 = (j.fist_l.global_position + j.fist_r.global_position) * 0.5
	var at := hands + Vector3.DOWN * 0.15 * u
	at.y = maxf(at.y, 0.8)   # jamais dans le sol : couché, son buste reste au-dessus (sinon ses jambes s'enfoncent et tirent)
	enemy.hold(b, at)


## Shoryuken : l'ennemi monte collé au poing ; au sommet, il est lâché en ragdoll, juste au-dessus de toi, prêt à être jonglé.
func _sho_carry() -> void:
	if sho_victim == null or sho_victim.state != "held":
		sho_hold = false
		return
	if attack != "shoryu":   # coupé (atterri, touché...) : on le lâche
		sho_hold = false
		sho_victim.toss(Vector3.UP * 2.0, 2.0)
		return
	var f := -global_basis.z
	if velocity.y < 1.0 or t > 0.5:   # sommet de la montée : lâché
		sho_hold = false
		sho_victim.toss(Vector3.UP * SHORYU_POP * lerpf(0.4, 1.0, charge_power) + f * 0.8, 4.0)
		get_parent().impact(0.03, 0.3)
		return
	var b := Basis(Vector3.UP.cross(f), deg_to_rad(-25.0)) * Basis(Vector3.UP, atan2(-f.x, -f.z))   # tête renversée en arrière
	var fist: Vector3 = j.fist_r.global_position
	sho_victim.hold(b, fist + f * 0.15 + Vector3.DOWN * 0.35)   # le poing sous son menton


## Chope sur un objet du décor (table, chaise, banc, poubelle, caisse, tonneau) : il marche avec toutes les chopes.
func _try_prop() -> void:
	var hand := global_position - global_basis.z * 0.7
	var best: RigidBody3D = null
	var bd := 1.3
	for b in get_tree().get_nodes_in_group("reactive"):
		if not b is RigidBody3D or b.freeze:
			continue
		var d: float = ((b.global_position - hand) * Vector3(1, 0, 1)).length()
		if d < bd:
			bd = d
			best = b
	if best == null:
		return
	held_prop = best
	prop_rot = global_basis.inverse() * best.global_basis   # il garde son orientation par rapport à toi
	best.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	best.freeze = true
	best.collision_layer = 0
	prop_t = 0.0
	prop_wind = 0.0
	prop_sweep.clear()
	match throw_move:
		"swing":
			start("prop_swing")
			swing_w = 0.0
			swing_hold = 0.0
			swing_stick_ok = false
		"throw":
			start("prop_wind")
		_:
			start("prop_hold")
	get_parent().impact(0.03, 0.2)


## Objet tenu : soulevé au-dessus de la tête (chope de base : rappui R1 ou X = lancé droit devant), élan (lancer visé : R1 relâché le lance),
## ou grand tour (il tourne au bout de tes bras et fauche les sbires ; R1 relâché le lance).
func _prop_hold(dt: float, dir: Vector3) -> void:
	prop_t += dt
	queued = false
	heavy_buf = 0.0
	if held_prop == null or not is_instance_valid(held_prop):
		held_prop = null
		attack = ""
		return
	match attack:
		"prop_hold":
			if prop_t > 0.15 and Input.is_action_just_pressed("light"):
				prop_wind = 0.35
				start("prop_toss")   # X : lancé droit devant
			elif prop_t > 0.15 and Input.is_action_just_pressed("heavy"):
				start("prop_bash")   # Y : fracassé devant lui (coup de chaise ; au 3e, il vole en morceaux)
			elif prop_t > 0.15 and Input.is_action_just_pressed("grab"):
				grab_buf = 0.0
				shield_press = 0.0   # appui court = lancé ; maintenu = bouclier
			elif shield_press >= 0.0:
				shield_press += dt
				if not Input.is_action_pressed("grab"):
					shield_press = -1.0
					prop_wind = 0.2
					start("prop_toss")   # rappui : lancé droit devant lui
				# (objet-bouclier retiré en v0.212 : remplacé par l'amélioration Défense sur R1)
			elif prop_t > 5.0:
				_release_prop(Vector3.ZERO)
				attack = ""
		"prop_wind":
			if Input.is_action_pressed("grab") and prop_t < 3.0:
				prop_wind = minf(prop_t / THROW_WIND, 1.0)
			elif prop_t > 0.05:
				start("prop_toss")
		"prop_swing":
			_swing_spin(dt, dir)
			var f := -global_basis.z
			held_prop.global_transform = Transform3D(global_basis * prop_rot, global_position + f * 1.3 + Vector3.UP * 1.0)
			var tangent := global_basis.x * -swing_sign
			for e in enemies:
				if e.parts.is_empty() or prop_sweep.has(e) or e.state in ["held", "swung", "dead"]:
					continue
				var c: Vector3 = e.parts.chest.global_position
				if c.distance_to(held_prop.global_position) < 1.0:
					prop_sweep[e] = true
					e.hit(e.parts.chest, (tangent + Vector3.UP * 0.4).normalized() * heavy_force * 1.1, c, PROP_DMG, 1.0, true)
					get_parent().impact(0.06, 0.6)
			if not Input.is_action_pressed("grab") or prop_t >= SWING_HOLD:
				_release_prop(tangent * absf(swing_w) * 1.3 + Vector3.UP * 2.0)
				start("swing_finish")
				hit_done = true


## Rotation du grand tour (tourne tout seul, accélère avec des cercles au stick).
func _swing_spin(dt: float, dir: Vector3) -> void:
	swing_hold += dt
	var target := SWING_BASE * smoothstep(0.0, 0.4, swing_hold)
	if dir.length() > 0.5:
		var a := atan2(-dir.x, -dir.z)
		if swing_stick_ok:
			var ws := angle_difference(swing_stick, a) / dt
			if absf(ws) > 6.0 and signf(ws) != swing_sign:
				swing_sign = signf(ws)
			if absf(ws) > 2.0:
				target = clampf(SWING_BASE + absf(ws) * 0.8, SWING_BASE, SWING_TURN)
		swing_stick = a
		swing_stick_ok = true
	else:
		swing_stick_ok = false
	swing_w = lerpf(swing_w, swing_sign * target, 1.0 - exp(-6.0 * dt))
	rotation.y += swing_w * dt


## L'objet suit les mains (au-dessus de la tête, ou derrière l'épaule pendant l'élan).
func _place_prop() -> void:
	if not is_instance_valid(held_prop):
		held_prop = null
		return
	var hands: Vector3 = (j.fist_l.global_position + j.fist_r.global_position) * 0.5
	var b := global_basis * prop_rot
	held_prop.global_transform = Transform3D(b, hands + Vector3.UP * 0.1 - b.y * 0.45)


## Lâche l'objet avec cette vitesse ; en vol, il percute les sbires.
func _release_prop(v: Vector3) -> void:
	if held_prop == null or not is_instance_valid(held_prop):
		held_prop = null
		return
	var b := held_prop
	held_prop = null
	b.freeze = false
	b.collision_layer = 1
	b.linear_velocity = v
	b.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)) * clampf(v.length() / 10.0, 0.0, 1.0)
	if v.length() > 3.0:
		flying.append({"b": b, "t": 0.0, "hits": {}})


## Objets lancés : chacun percute les sbires qu'il croise (une fois chacun).
func _fly_props(dt: float) -> void:
	for fl in flying.duplicate():
		var b = fl.b
		fl.t += dt
		if not is_instance_valid(b) or fl.t > 2.5 or (fl.t > 0.2 and b.linear_velocity.length() < 2.5):
			flying.erase(fl)
			continue
		for e in enemies:
			if e.parts.is_empty() or fl.hits.has(e) or e.state in ["held", "swung"]:
				continue
			var c: Vector3 = e.parts.chest.global_position
			if minf(c.distance_to(b.global_position), e.parts.pelvis.global_position.distance_to(b.global_position)) < 0.9:
				fl.hits[e] = true
				var d: Vector3 = (b.linear_velocity + Vector3.UP * 2.0).normalized()
				e.hit(e.parts.chest, d * heavy_force * 1.1, c, PROP_DMG, 1.0, true)
				_gain(PROP_DMG * 0.6)
				get_parent().impact(0.07, 0.7)


## Coup de zone (objet fracassé) : tous les sbires autour de ce point.
func _area_hit(at: Vector3, radius: float, dmg: float, except: Node = null) -> void:
	for e in enemies:
		if e == except or e.parts.is_empty() or e.state in ["held", "swung"]:
			continue
		var c: Vector3 = e.parts.pelvis.global_position
		var d := (c - at) * Vector3(1, 0, 1)
		if d.length() < radius:
			e.hit(e.parts.chest, ((d.normalized() if d.length() > 0.05 else -global_basis.z) + Vector3.UP).normalized() * heavy_force, c, dmg, 1.0, true)
			_gain(dmg * 0.6)


## Jauge de spécial (R2).
func _gain(v: float) -> void:
	special = minf(special + v, SPECIAL_MAX)


func _flash(c: Color, d: float) -> void:
	flash_mat.albedo_color = Color(c.r, c.g, c.b, 0.8)
	await get_tree().create_timer(d, true, false, true).timeout
	flash_mat.albedo_color = Color(1, 1, 1, 0)


## Bloc bleu d'un membre (boîte, ou boule pour la tête et les poings), centré sur `center`.
func _cube(name: String, center: Vector3) -> MeshInstance3D:
	var size := Vector3.ZERO
	for s in SKELETON:
		if s[0] == name:
			size = s[3]
	var mi := MeshInstance3D.new()
	if size.y == 0:
		mi.mesh = SphereMesh.new()
		mi.mesh.radius = size.x
		mi.mesh.height = size.x * 2
	else:
		mi.mesh = BoxMesh.new()
		mi.mesh.size = size
	mi.position = center
	mi.material_override = mat
	return mi


## Calque de flash posé sur tous les morceaux du héros (coups reçus, parade, charge...).
func _overlay(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			c.material_overlay = flash_mat
		_overlay(c)


## Coup chargé : Y maintenu, planté sur place. Flash à charge pleine ; relâché juste après le flash = critique.
func _charge(dt: float) -> void:
	charge_t += dt
	var need: float = CHARGE_NEED[charge_move]
	var k := clampf(charge_t / need, 0.0, 1.0)   # plus il charge, plus c'est puissant
	if attack == "charge_hado":
		_hado_orb(k)   # la boule grossit dans ses mains
	if Input.is_action_pressed("heavy") and k < 1.0:
		return   # charge pleine : ça part tout seul
	_hado_orb(-1.0)
	charge_power = k
	match charge_move:
		"power":
			_start_heavy()   # le coup lourd en place (chassé, high kick, retourné, axe kick...), version chargée
			hit_mult = 1.0 + k   # jusqu'à 2× ; chargé au max, il passe la garde et met au sol
			hit_crit = k >= 0.99
		"shoryu":
			start("shoryu")
			sho_wait = true
			charge_power = k
			hit_mult = lerpf(0.6, 1.2, k)
		"hadoken":
			start("hadoken")
			charge_power = k


func _air_kick() -> void:
	start("bicycle" if air_heavy == "bicycle" else "air_kick")
	velocity.y = maxf(velocity.y, 3.5)   # petit rebond pour la vrille


## Lancement du Y normal (coup lourd au sol).
func _start_heavy() -> void:
	start(heavy_move)
	if heavy_move == "axe":
		velocity.y = FLIP_JUMP   # salto avant : il décolle


## Boule d'énergie en charge : une sphère lumineuse entre les paumes, qui grossit (u < 0 : on l'enlève).
func _hado_orb(u: float) -> void:
	if u < 0.0:
		if orb:
			orb.queue_free()
			orb = null
		return
	if orb == null:
		orb = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.32
		m.height = 0.64
		orb.mesh = m
		var om := StandardMaterial3D.new()
		om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		om.albedo_color = Color(0.55, 0.85, 1.0)
		orb.material_override = om
		add_child(orb)
	orb.global_position = (j.fist_l.global_position + j.fist_r.global_position) * 0.5
	orb.scale = Vector3.ONE * (0.15 + 0.85 * u) * (1.0 + 0.1 * sin(charge_t * 40.0))


## Plongeon : à l'atterrissage, onde de choc qui lance en l'air les sbires autour.
func _dive_shock() -> void:
	for e in enemies:
		if e.parts.is_empty() or e.state in ["held", "swung", "getup", "techroll", "rise"]:
			continue
		var c: Vector3 = e.parts.pelvis.global_position
		var d := (c - global_position) * Vector3(1, 0, 1)
		if d.length() > DIVE_RADIUS:
			continue
		var away := d.normalized() if d.length() > 0.05 else -global_basis.z
		e.hit(e.parts.chest, (away * 0.4 + Vector3.UP).normalized() * heavy_force * 0.9, c, DIVE_DMG, 1.0, true)
	_gain(8.0)
	_shock_ring(global_position - global_basis.z * 0.5)
	get_parent().impact(0.1, 1.1)


## Effet de zone : un anneau qui s'élargit au ras du sol et s'efface.
func _shock_ring(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = 0.85
	m.outer_radius = 1.0
	ring.mesh = m
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 0.95, 0.8, 0.9)
	ring.material_override = rm
	get_parent().add_child(ring)
	ring.global_position = Vector3(at.x, 0.05, at.z)
	ring.scale = Vector3(0.3, 0.15, 0.3)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(DIVE_RADIUS, 0.15, DIVE_RADIUS), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)


## Lâche l'ennemi tenu (chope, fracas en cours, grand tour) : il retombe en ragdoll au lieu de rester figé.
func _drop_held() -> void:
	if sho_hold and sho_victim and sho_victim.state == "held":
		sho_hold = false
		sho_victim.toss(Vector3.UP * 1.0, 1.0)
	if held_prop:
		_release_prop(Vector3.UP * 1.0)
	if enemy == null or enemy.parts.is_empty():
		return
	if attack in ["collar", "collar_punch", "slam", "headbutt", "air_slam", "shoryu"] and enemy.state == "held":
		enemy.toss(Vector3.UP * 1.0 - global_basis.z * 1.0, 1.0)
	elif attack in ["swing", "club_hold", "club_swing"] and enemy.state == "swung":
		enemy.swing_release(global_position + Vector3.UP, Vector3.DOWN * swing_w, 0.0)


## Un coup ennemi l'a manqué pendant son esquive (pas de côté : contre critique).
func on_evade(attacker: Node) -> void:
	if ups:
		ups.on_evade(attacker)


## Pendant le cœur de la roulade, il ne peut pas être touché (pour quand les ennemis attaqueront).
func is_invulnerable() -> bool:
	if lc and lc.invulnerable():
		return true
	if attack == "shoryu" and t < 0.12:
		return true   # shoryuken : invulnérable au départ
	match roll_kind:
		"step":
			return roll >= 0.0   # pas de côté : invulnérable tout du long
		"slide":
			return roll >= 0.0 and roll <= 0.32
		"dash":
			return roll >= 0.0 and roll <= DASH_TIME
	return roll >= 0.04 and roll <= (_dodge_time() - 0.13 if roll_kind == "sweep" else ROLL_TIME * 0.72)


func _animate(dt: float) -> void:
	if wind_key:
		wind_key.rotate_z(dt * (2.0 + 6.0 * clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.5)))   # la clé tourne, plus vite quand il court
	var moving := clampf(Vector2(velocity.x, velocity.z).length() / speed, 0.0, 1.0)
	run_mix = move_toward(run_mix, 1.0 if moving > 0.3 and attack == "" else 0.0, dt * 6.0)
	gait_v = Vector2(velocity.x, velocity.z).length()
	run_phase += dt * TAU * gait_v / _stride()   # cycle de course capturé (CMU) : un tour de phase = une foulée, les pieds ne patinent pas
	idle_t += dt
	var ig := _pose("guard")
	# Garde au repos : rebonds et respiration d'un boxeur capturé (CMU 13_17), ajoutés à la garde du jeu.
	var io := _cyc(CycleData.IDLE, idle_t / CycleData.IDLE_PERIOD)
	for n in ["hips_pos", "hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r"]:
		ig[n] = ig.get(n, Vector3.ZERO) + io[n] * IDLE_AMP
	base = _mix(_resolve(ig), _resolve(_run_pose(run_phase)), smoothstep(0.0, 1.0, run_mix))
	sprint_mix = move_toward(sprint_mix, 1.0 if sprinting and moving > 0.5 and attack == "" else 0.0, dt * 6.0)
	if sprint_mix > 0:   # sprint : buste très penché en avant, tête qui fonce
		base.spine = Quaternion(Vector3.RIGHT, deg_to_rad(-28.0) * sprint_mix) * base.spine
		base.head = Quaternion(Vector3.RIGHT, deg_to_rad(18.0) * sprint_mix) * base.head
	var r := base
	if attack != "":
		r = pose_at(attack, t)
		if attack == "swing":
			run_phase += dt * (1.6 * absf(swing_w) + 8.0 * moving)   # pas de pivot quand il tourne, pas de marche quand il avance
			r = _walk_legs(r, maxf(0.6 * clampf(absf(swing_w) / 3.0, 0.0, 1.0), smoothstep(0.05, 0.3, moving)))
		if attack == "collar" and throw_move == "throw" and throw_t > 0:
			r = _mix(r, _resolve(_pose("throw_hold")), smoothstep(0.0, 1.0, throw_t / THROW_WIND))   # élan du lancer
		if attack in ["collar", "collar_punch", "club_hold", "club_swing", "prop_shield", "prop_hold", "prop_wind"]:
			r = _walk_legs(r, smoothstep(0.05, 0.3, moving))
		if attack in ["cheese_grater", "cheese_grater_r"]:
			run_phase += dt * 12.0
			r = _walk_legs(r, 1.0)   # il court le long du mur
		if attack == "tackle":
			run_phase += dt * 15.0
			r = _walk_legs(r, 1.0)   # il court en le portant (jambes de la course)
			r.spine = Quaternion(Vector3.FORWARD, deg_to_rad(6.0 * sin(run_phase))) * r.spine
		if attack == "wall_run_h" and t < ATK.wall_run_h.active - 0.06:
			run_phase += dt * 16.0
			r = _walk_legs(r, 1.0)
			r.hips = Quaternion(Vector3.BACK, deg_to_rad(55.0) * wall_side * smoothstep(0.0, 0.08, t)) * r.hips   # couché sur le côté : les pieds courent sur le mur
	# Saut : flexion avant de décoller, pose en l'air selon qu'il monte ou descend, amorti à l'atterrissage.
	if jump_wait >= 0:
		r = _mix(r, _resolve(_pose("crouch")), 1.0 - jump_wait / JUMP_WINDUP)
	air_mix = move_toward(air_mix, 1.0 if air else 0.0, dt * (12.0 if air else 25.0))
	if air_mix > 0 and not ATK.get(attack, {}).get("air", false) and not attack in PENALTY:   # un coup aérien a sa propre pose de jambes
		var falling := clampf(0.5 - velocity.y / 8.0, 0.0, 1.0)
		r = _mix(r, _mix(_resolve(_pose("air_up")), _resolve(_pose("air_down")), falling), air_mix)
	if land > 0:
		land -= dt
		r = _mix(r, _resolve(_pose("crouch")), sin(PI * clampf(land / LAND_TIME, 0.0, 1.0)))
	guard_mix = move_toward(guard_mix, 1.0 if guarding else 0.0, dt * 14.0)
	if guard_mix > 0:
		var g := _resolve(_pose("block"))
		if block_stun > 0:
			g = _mix(g, _resolve(_pose("block_hit")), block_stun / 0.15)   # il encaisse dans sa garde
		r = _mix(r, _walk_legs(g, smoothstep(0.05, 0.3, moving)), guard_mix)
	if hurt > 0:
		r = _mix(r, _resolve(_pose("hurt")), smoothstep(0.0, 1.0, hurt / HURT_TIME))   # rejeté d'un coup, puis il se reprend
	if roll >= 0:
		var u := roll / _dodge_time()
		var dp: Dictionary = {"sweep": _sweep_pose(u), "slide": _slide_pose(u), "dash": _dash_pose(u), "step": _dash_pose(u)}.get(roll_kind, _roll_pose(u)) if roll_kind != "roll" else _roll_pose(u)
		r = _mix(_mix(from, _resolve(dp), smoothstep(0.0, 0.12, u)), r, smoothstep(0.85, 1.0, u))
	if lc and lc.w > 0.0 and lc.state != "":
		r = _mix(r, _resolve(GUARD.merged(lc.pose(), true)), lc.w)   # enjambée, rebord, glissade, atterrissage lourd
	apply_pose(r)
	if lc and lc.w > 0.0 and lc.state != "":
		var ht: Dictionary = lc.hand_targets()
		if not ht.is_empty():
			_arm_ik("l", ht.l, ht.out, ht.w)
			_arm_ik("r", ht.r, ht.out, ht.w)
	if attack == "collar" and throw_move == "throw" and enemy and enemy.state == "held":
		_hold_in_hands()
	if held_prop and attack in ["prop_hold", "prop_wind", "prop_slam", "prop_toss", "prop_bash", "prop_shield"]:
		_place_prop()


## Pose du coup `id` à l'instant `tt` : les clés de sa fiche, interpolées (courbe "lin", "in" ou amortie par défaut).
## Sert au jeu et à l'éditeur de poses de la salle de test.
func pose_at(id: String, tt: float) -> Dictionary:
	var keys: Array = ATK[id].keys
	for i in range(keys.size() - 1):
		if tt <= keys[i + 1][0] or i == keys.size() - 2:
			var u := clampf((tt - keys[i][0]) / maxf(keys[i + 1][0] - keys[i][0], 0.0001), 0.0, 1.0)
			match keys[i + 1][2] if keys[i + 1].size() > 2 else "":
				"lin":
					pass   # lente, constante (il charge)
				"in":
					u = u * u * u   # part lentement puis accélère d'un coup
				"inout":
					u = u * u * (3.0 - 2.0 * u)   # douce au départ et à l'arrivée
				"step":
					u = 0.0 if u < 1.0 else 1.0   # tenue, puis saut sec à la clé suivante
				_:
					u = 1.0 - (1.0 - u) * (1.0 - u)   # départ sec, arrivée amortie
			return _mix(_key(keys[i][1]), _key(keys[i + 1][1]), u)
	return _key(keys[0][1])


## Pose les articulations du squelette (pieds plantés par IK).
func apply_pose(r: Dictionary) -> void:
	shown = r
	j.hips.position = r.hips_pos
	for n in JOINTS:
		j[n].quaternion = r[n]
	for side in r.ik:
		var leg := _ik(r, side)
		j["hip_" + side].quaternion = leg[0]
		j["kn_" + side].quaternion = leg[1]


## Lancer visé : l'ennemi est accroché à tes mains (son col entre tes poings), où qu'elles soient pendant l'élan.
func _hold_in_hands() -> void:
	var f := -global_basis.z
	var w := smoothstep(0.0, 1.0, throw_t / THROW_WIND)
	var b := Basis(Vector3.UP.cross(f), deg_to_rad(lerpf(15.0, -35.0, w))) * Basis(Vector3.UP, atan2(-f.x, -f.z))
	var hands: Vector3 = (j.fist_l.global_position + j.fist_r.global_position) * 0.5
	enemy.hold(b, hands + b * Vector3(0, -0.2, -0.13))   # centre du buste : sous le col, derrière (son dos est vers -z)


## Remplace les jambes (et le rebond du bassin) d'une pose par celles de la course, dosé par w.
func _walk_legs(r: Dictionary, w: float) -> Dictionary:
	if w <= 0.0:
		return r
	var run := _resolve(_run_pose(run_phase))
	var out := r.duplicate()
	out.ik = {}
	for side in ["l", "r"]:
		var leg: Array = _ik(r, side) if r.ik.has(side) else [r["hip_" + side], r["kn_" + side]]
		out["hip_" + side] = leg[0].slerp(run["hip_" + side], w)
		out["kn_" + side] = leg[1].slerp(run["kn_" + side], w)
	out.hips_pos = r.hips_pos.lerp(Vector3(r.hips_pos.x, run.hips_pos.y, r.hips_pos.z), w)
	return out


func _key(pose_name: String) -> Dictionary:
	return from if pose_name == "from" else _resolve(_pose(pose_name))


func _pose(pose_name: String) -> Dictionary:
	if pose_name.begins_with("@"):
		return GUARD.merged(AnimStore.pose(pose_name), true)   # pose retouchée dans l'éditeur d'animation (version cochée)
	return GUARD.merged(POSE_DIFF[pose_name], true)


## Course et marche capturées (CMU 09_02 et 08_02, combat/cycles_data.gd) : la marche passe à la course avec la vitesse.
## ph = phase (2π par foulée) ; même départ pour les deux (pied gauche devant), donc le mélange reste en rythme.
func _run_pose(ph: float) -> Dictionary:
	var u := ph / TAU
	var w := _run_w()
	if w >= 1.0:
		return _cyc(CycleData.RUN, u)
	if w <= 0.0:
		return _cyc(CycleData.WALK, u)
	var a := _cyc(CycleData.WALK, u)
	var b := _cyc(CycleData.RUN, u)
	for k in a:
		a[k] = a[k].lerp(b[k], w)
	return a


func _run_w() -> float:
	return smoothstep(1.8, 3.6, gait_v) if gait_v > 0.0 else 1.0


## Longueur d'une foulée (m) à la vitesse actuelle : celle de la marche, de la course, entre les deux.
func _stride() -> float:
	return lerpf(CycleData.WALK_STRIDE, CycleData.RUN_STRIDE, _run_w())


## Image u (0..1, sans boucle) d'un geste capturé (enjambée, roulade…).
static func _clip(arr: Array, u: float) -> Dictionary:
	var x := clampf(u, 0.0, 1.0) * (arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	var a: Dictionary = arr[i]
	var b: Dictionary = arr[i + 1]
	var f := x - i
	var out := {}
	for k in a:
		out[k] = _mixv(k, a[k], b[k], f)
	return out


## Deux valeurs d'une pose : les angles par le plus court chemin entre les deux rotations (quaternions), le reste en ligne droite.
static func _mixv(k: String, a: Vector3, b: Vector3, f: float) -> Vector3:
	if not k in JOINTS:
		return a.lerp(b, f)
	return Quaternion.from_euler(a * (PI / 180)).slerp(Quaternion.from_euler(b * (PI / 180)), f).get_euler() * (180.0 / PI)


## Point u (0..1) d'une trajectoire capturée, depuis son départ.
static func _track(arr: Array, u: float) -> Vector3:
	var x := clampf(u, 0.0, 1.0) * (arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	return arr[i].lerp(arr[i + 1], x - i) - arr[0]


## Image u (0..1, boucle) d'un cycle capturé : interpolation entre ses deux images voisines.
static func _cyc(arr: Array, u: float) -> Dictionary:
	var x := fposmod(u, 1.0) * arr.size()
	var i := int(x) % arr.size()
	var a: Dictionary = arr[i]
	var b: Dictionary = arr[(i + 1) % arr.size()]
	var f := x - floorf(x)
	var out := {}
	for k in a:
		out[k] = _mixv(k, a[k], b[k], f)
	return out


## Tacle glissé : couché en arrière sur la hanche, jambe droite tendue devant au ras du sol, l'autre repliée, mains derrière.
func _slide_pose(u: float) -> Dictionary:
	var w := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.75, 1.0, u))
	return {
		"hips_pos": Vector3(0, -0.55 * w, 0.1 * w), "hips": Vector3(55 * w, 0, 0), "spine": Vector3(-25 * w, 0, 0), "head": Vector3(-15 * w, 0, 0),
		"hip_r": Vector3(30 * w, 0, 0), "kn_r": Vector3(0, 0, 0), "hip_l": Vector3(10 * w, 0, 0), "kn_l": Vector3(-100 * w, 0, 0),
		"sh_l": Vector3(-35 * w, 0, -35 * w), "el_l": Vector3(10 * w, 0, 0), "sh_r": Vector3(40 * w, 0, -20 * w), "el_r": Vector3(60 * w, 0, 0),
	}


## Strafe éclair : garde basse, buste penché dans le sens du déplacement.
func _dash_pose(u: float) -> Dictionary:
	var w := sin(PI * clampf(u, 0.0, 1.0))
	var ld := global_basis.inverse() * roll_dir
	var p := _pose("guard")
	p.hips_pos = p.hips_pos + Vector3(0, -0.12 * w, 0)
	p.spine = p.spine + Vector3(22 * ld.z * w, 0, -22 * ld.x * w)
	return p


## Balayage retourné : accroupi bas, jambe droite tendue à l'horizontale au ras du sol, il fait un tour complet sur lui-même
## autour de la jambe d'appui ; mains au sol de chaque côté.
func _sweep_pose(u: float) -> Dictionary:
	var w := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.8, 1.0, u))
	var angle := -360.0 * (3.0 if sweep_triple else 1.0) * smoothstep(0.05, 0.85, u)
	return {
		"hips_pos": Vector3(0, -0.48 * w, 0), "hips": Vector3(0, angle, 0), "spine": Vector3(-35 * w, 0, 0), "head": Vector3(15 * w, 0, 0),
		"foot_l": Vector3(0, 0.02, 0), "hip_r": Vector3(5 * w, 0, 85 * w), "kn_r": Vector3(0, 0, 0),
		"sh_l": Vector3(25 * w, 0, -40 * w), "el_l": Vector3(15 * w, 0, 0), "sh_r": Vector3(25 * w, 0, 40 * w), "el_r": Vector3(15 * w, 0, 0),
	}


## Roulade avant : il se met en boule et fait un tour complet sur lui-même, puis se redéplie.
func _roll_pose(u: float) -> Dictionary:
	if CycleData.ROLL.size() > 1:   # roulade capturée (CMU 127_23) : mains au sol, roulé sur le dos, relevé
		var pz := _clip(CycleData.ROLL, u)
		pz.hips_pos += Vector3(0, _track(CycleData.ROLL_ROOT, u).y, 0)
		return pz
	var w := sin(PI * clampf(u, 0.0, 1.0))   # 0 -> en boule -> 0
	var angle := -360.0 * smoothstep(0.1, 0.85, u)
	var upside := (1.0 - cos(deg_to_rad(angle))) / 2.0   # 1 quand il a la tête en bas : on remonte le pivot pour ne pas passer sous le sol
	return {
		"hips_pos": Vector3(0, -0.1 - 0.5 * w + 0.3 * upside, 0), "hips": Vector3(angle, 0, 0), "spine": Vector3(-70 * w, 0, 0), "head": Vector3(-40 * w, 0, 0),
		"hip_l": Vector3(130 * w, 0, 0), "kn_l": Vector3(-150 * w, 0, 0), "hip_r": Vector3(125 * w, 0, 0), "kn_r": Vector3(-150 * w, 0, 0),
		"sh_l": Vector3(60 * w, 0, 10 * w), "el_l": Vector3(120 * w, 0, 0), "sh_r": Vector3(60 * w, 0, -10 * w), "el_r": Vector3(120 * w, 0, 0),
	}


## Pose en degrés -> rotations, position du bassin, cibles de pieds.
func _resolve(p: Dictionary) -> Dictionary:
	var r := {"hips_pos": Vector3(0, 0.9, 0) + p.get("hips_pos", Vector3.ZERO), "ik": {}}
	for n in JOINTS:
		r[n] = Quaternion.from_euler(p.get(n, Vector3.ZERO) * (PI / 180))
	for side in ["l", "r"]:
		if p.get("foot_" + side) != null:
			r.ik[side] = p["foot_" + side]
	return r


## Interpolation de deux poses. Pieds plantés des deux côtés : on interpole la cible (le pied ne glisse pas sous le sol).
## Pied planté d'un seul côté : on convertit en angles puis on interpole.
func _mix(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var r := {"hips_pos": a.hips_pos.lerp(b.hips_pos, u), "ik": {}}
	for n in JOINTS:
		r[n] = a[n].slerp(b[n], u)
	for side in ["l", "r"]:
		if a.ik.has(side) and b.ik.has(side):
			r.ik[side] = a.ik[side].lerp(b.ik[side], u)
		elif a.ik.has(side) or b.ik.has(side):
			var la := _ik(a, side) if a.ik.has(side) else [a["hip_" + side], a["kn_" + side]]
			var lb := _ik(b, side) if b.ik.has(side) else [b["hip_" + side], b["kn_" + side]]
			r["hip_" + side] = la[0].slerp(lb[0], u)
			r["kn_" + side] = la[1].slerp(lb[1], u)
	return r


## IK deux os du bras (bras + avant-bras, 0,3 m chacun) : le poing va sur la cible (monde), le coude part vers `out`.
## Appliqué après la pose (rebords : les mains restent posées sur l'arête), dosé par k.
func _arm_ik(side: String, target: Vector3, out: Vector3, k: float) -> void:
	var sh: Node3D = j["sh_" + side]
	var sp: Basis = j.spine.global_basis.orthonormalized()
	var d: Vector3 = sp.inverse() * (target - sh.global_position)
	var reach := clampf(d.length(), 0.05, 0.599)
	var dir := d.normalized()
	var hint: Vector3 = sp.inverse() * (out + Vector3.DOWN * 0.4 + (sh.global_position - j.spine.global_position).normalized() * 0.6)
	hint = (hint - dir * dir.dot(hint)).normalized()
	var a := acos(clampf((0.09 + reach * reach - 0.09) / (2.0 * 0.3 * reach), -1.0, 1.0))
	var upper: Vector3 = dir * cos(a) + hint * sin(a)
	var fore: Vector3 = (dir * reach - upper * 0.3).normalized()
	var y: Vector3 = -upper
	var z: Vector3 = -(fore - upper * upper.dot(fore)).normalized()
	if z.length() < 0.5:
		z = Vector3.BACK
	var q := Basis(y.cross(z), y, z).orthonormalized().get_rotation_quaternion()
	sh.quaternion = sh.quaternion.slerp(q, k)
	j["el_" + side].quaternion = j["el_" + side].quaternion.slerp(Quaternion(Vector3.RIGHT, upper.angle_to(fore)), k)


## IK deux os (cuisse + tibia) : rotations de hanche et de genou pour que la cheville atteigne la cible, genou vers l'avant.
func _ik(r: Dictionary, side: String) -> Array:
	var pivot := Vector3(-0.1 if side == "l" else 0.1, 0, 0)
	var d: Vector3 = Transform3D(Basis(r.hips), r.hips_pos).affine_inverse() * r.ik[side] - pivot
	var reach := clampf(d.length(), 0.05, THIGH + SHIN - 0.001)
	var dir := d.normalized()
	var fwd := (Vector3.FORWARD - dir * dir.dot(Vector3.FORWARD)).normalized()
	var a := acos(clampf((THIGH * THIGH + reach * reach - SHIN * SHIN) / (2.0 * THIGH * reach), -1.0, 1.0))
	var thigh := dir * cos(a) + fwd * sin(a)
	var shin := (dir * reach - thigh * THIGH).normalized()
	var y := -thigh
	var z := -(fwd - thigh * thigh.dot(fwd)).normalized()
	var hip := Basis(y.cross(z), y, z)
	var sl := hip.inverse() * shin
	return [hip.get_rotation_quaternion(), Quaternion(Vector3.RIGHT, atan2(-sl.z, -sl.y))]


func start(kind: String) -> void:
	from = shown if not shown.is_empty() else base
	if orb and kind != "charge_hado":
		_hado_orb(-1.0)
	attack = kind
	approach = false
	attack_id += 1
	if kind == "collar":
		throw_t = 0.0
	if stick_dir.length() > 0.3 and (IDEAL.has(kind) or kind in ["hadoken", "quake", "charge", "charge_sho", "charge_hado"]):
		rotation.y = atan2(-stick_dir.x, -stick_dir.z)   # façon jeu de combat : le coup part là où tu pousses le stick
		_pick_target(stick_dir)
	elif lock_on and IDEAL.has(kind):
		_pick_target(Vector3.ZERO)   # aimantation sans stick : le sbire le plus proche devant
	t = 0.0
	hit_done = false
	connected = false
	sho_blocked = false
	if kind == "knee":
		velocity.y = KNEE_JUMP   # genou volant (3e coup du combo) : il décolle avec le genou
	hit_mult = 1.0
	hit_crit = false
	if ups and ups.evade_t > 0.0 and ATK[kind].has("tip"):
		ups.evade_t = 0.0   # pas de côté réussi : contre critique
		hit_mult = 2.0
		hit_crit = true
		_flash(Color(1, 0.85, 0.3), 0.06)
	if riposte and riposte_t > 0 and ATK[kind].has("tip"):
		riposte_t = 0.0   # riposte juste après une parade : coup critique
		hit_mult = 2.0
		hit_crit = true
	# Verrouillage : on se tourne vers l'ennemi et on se place à la bonne distance pour que le coup touche.
	var c := _lock_point()
	var to := (c - global_position) * Vector3(1, 0, 1)
	if not lock_on and kind == "grab" and c != Vector3.INF and to.length() > 0.05 and to.length() < 1.6 and (-global_basis.z).angle_to(to) < deg_to_rad(60.0):
		rotation.y = atan2(-to.x, -to.z)   # sans aimantation, la chope se tourne quand même vers un sbire tout proche
		approach = false
	elif lock_on and c != Vector3.INF and to.length() > 0.05 and (-global_basis.z).angle_to(to) < deg_to_rad(_lk(60.0, 120.0, 170.0) if kind == "grab" else _lk(25.0, LOCK_ANGLE, 150.0)) and IDEAL.has(kind):
		rotation.y = atan2(-to.x, -to.z)
		approach = true
		var gap := clampf(to.length() - IDEAL[kind], -0.4, _lk(0.4, 1.0, 4.0))
		var reach_time: float = ATK[kind].active / attack_speed
		if kind != "grab" and gap > _lk(5.0, APPROACH_MAX, 22.0) * reach_time * 0.8:   # trop loin pour y être à l'impact : petit dash avant le coup (pose de départ tenue)
			t = -(gap / _lk(5.0, DASH_SPEED, 18.0) - reach_time) * attack_speed
		if not is_on_floor():
			var dy := c.y - (global_position.y + 1.2)
			if dy > 0.2:
				velocity.y = maxf(velocity.y, sqrt(2.0 * GRAVITY * minf(dy, 1.0)))   # il est plus haut : on monte le chercher
	else:
		approach = false
		var push: float = ATK[kind].get("step", 0.0)
		if kind in ["jab", "cross"]:
			velocity.x *= 0.2   # les jabs ne font pas avancer : on ne traverse plus la salle en les spammant
			velocity.z *= 0.2
			push = _jab_magnet(kind)
		elif not lock_on and (IDEAL.has(kind) or kind in ["quake", "hadoken"]) and kind != "grab" and stick_dir.length() > 0.3:
			push += MOMENTUM   # élan : chaque coup avance dans la direction où tu te déplaces
		velocity += -global_basis.z * push
	_atelier_start(kind)


## Approche verrouillée : jusqu'à l'impact, la vitesse est réglée pour arriver à la bonne distance de l'ennemi pile au bon moment,
## même s'il bouge.
func _approach(dt: float) -> void:
	if not approach or attack == "" or attack == "slam" or not IDEAL.has(attack) or t >= ATK[attack].active:
		approach = false
		return
	var c := _lock_point()
	if c == Vector3.INF:
		approach = false
		return
	var to := (c - global_position) * Vector3(1, 0, 1)
	var spot: Vector3 = c - to.normalized() * IDEAL[attack]
	var rem := maxf((ATK[attack].active - t) / attack_speed, dt)
	var v: Vector3 = ((spot - global_position) * Vector3(1, 0, 1) / rem).limit_length(_lk(5.0, APPROACH_MAX, 22.0))
	velocity.x = v.x
	velocity.z = v.z
	if to.length() > 0.05:
		rotation.y = atan2(-to.x, -to.z)


## Centre de l'ennemi (entre bassin et buste), ou Vector3.INF s'il n'y a rien à verrouiller.
## Cible : le sbire le plus proche dans la direction voulue (stick, sinon là où on regarde) ; les vivants avant les corps.
func _pick_target(dir: Vector3) -> void:
	var look := dir.normalized() if dir.length() > 0.2 else -global_basis.z
	var best := INF
	for e in enemies:
		if e.parts.is_empty() or e.state in ["held", "swung"]:
			continue
		var c: Vector3 = (e.parts.pelvis.global_position + e.parts.chest.global_position) * 0.5
		var to := (c - global_position) * Vector3(1, 0, 1)
		var score := to.length() + look.angle_to(to) * 1.2 + (3.0 if e.state == "dead" else 0.0)
		if score < best:
			best = score
			enemy = e


func _lock_point() -> Vector3:
	if enemy == null or enemy.parts.is_empty():
		return Vector3.INF
	var c: Vector3 = (enemy.parts.pelvis.global_position + enemy.parts.chest.global_position) * 0.5
	if ((c - global_position) * Vector3(1, 0, 1)).length() > (_lk(1.4, LOCK_RANGE, 6.0) if lock_on else LOCK_RANGE):
		return Vector3.INF
	return c


## En l'air pendant un jongle : on reste collé à lui (à portée de poing, tourné vers lui) sans avoir à diriger.
func _air_lock(dt: float, grounded: bool) -> void:
	if grounded or roll >= 0 or hurt > 0 or attack == "dive_kick" or not enemy or not enemy.state in ["down", "crisp", "dead"]:
		return
	var c := _lock_point()
	if c == Vector3.INF or c.y < 0.8:
		return
	var to := (c - global_position) * Vector3(1, 0, 1)
	if to.length() > _lk(1.8, 3.0, 6.0) or to.length() < 0.01:
		return
	var spot := c - to.normalized() * IDEAL.air
	var want := ((spot - global_position) * Vector3(1, 0, 1) * 8.0).limit_length(_lk(3.5, 7.0, 14.0))
	var k := 1.0 - exp(-_lk(5.0, 12.0, 25.0) * dt)
	velocity.x = lerpf(velocity.x, want.x, k)
	velocity.z = lerpf(velocity.z, want.z, k)
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), k)


## Le coup touche là où se trouve vraiment le poing (ou le pied) au moment de l'impact.
func do_hit(a: Dictionary) -> void:
	if a.get("v212", false):
		ups.impact(attack)   # la vague, toile, tomoe nage, désarmer, pluie d'objets
		return
	if a.get("atelier", false):
		_atelier_hit()
		return
	if a.get("grab", false):
		_try_grab()
		return
	if a.get("collar_punch", false):
		_collar_punch()
		return
	if a.get("club", false):   # la massue touche le sol : elle aussi prend un coup
		club_hits += 1
		enemy.collar_hit(CLUB_DMG)
		get_parent().impact(0.06, 0.6)
		return
	if a.get("quake", false):   # poing dans le sol : onde de choc tout autour
		_dive_shock()
		return
	if a.get("prop_slam", false):   # objet fracassé au sol devant lui : tout ce qui est autour prend le coup
		var at := global_position - global_basis.z * 1.2
		_release_prop(-global_basis.z * 3.0 + Vector3.DOWN * 8.0)
		_area_hit(at, 1.7, PROP_DMG)
		_shock_ring(at)
		get_parent().impact(0.1, 1.0)
		return
	if a.get("prop_toss", false):   # objet jeté devant lui
		_release_prop(-global_basis.z * (8.0 + 10.0 * prop_wind) + Vector3.UP * (3.0 + prop_wind))
		get_parent().impact(0.04, 0.4)
		return
	if a.get("flop_launch", false):
		_ragdoll_on()
		return
	if a.get("projectile", false):   # hadoken : la boule part des paumes
		var ball := Node3D.new()
		ball.set_script(load("res://energy_ball.gd"))
		ball.dir = -global_basis.z
		ball.force = heavy_force * lerpf(0.4, 1.0, charge_power)
		ball.power = charge_power
		ball.owner_player = self
		get_parent().add_child(ball)
		ball.global_position = (j.fist_l.global_position + j.fist_r.global_position) * 0.5 - global_basis.z * 0.2
		get_parent().impact(0.0, 0.3)
		return
	if a.get("headbutt", false):
		if enemy and enemy.state == "held":
			enemy.headbutt(-global_basis.z, GRAB_DMG)
			connected = true
			_gain(GRAB_DMG * 0.6)
			get_parent().impact(0.1, 0.9)
		return
	if a.get("slam", false):
		enemy.slam(slam_f, GRAB_DMG)
		_area_hit(enemy.parts.pelvis.global_position, 1.3, GRAB_DMG * 0.8, enemy)   # ceux qui sont là où il s'écrase prennent le coup
		connected = true   # saut d'annulation : on part le jongler
		get_parent().impact(0.1, 0.9)
		return
	var fwd := -global_basis.z
	velocity += fwd * a.lunge
	var center: Vector3 = j[a.tip].global_position
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = SphereShape3D.new()
	q.shape.radius = a.get("r", 0.5) * ups.radius_mult()   # augmentation d'impact
	q.transform = Transform3D(Basis(), center)
	q.collision_mask = 2 | 8
	var part: RigidBody3D = null
	var best := INF
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var dd: float = r.collider.global_position.distance_to(center)
		if dd < best:
			best = dd
			part = r.collider
	if part == null:
		return
	var force: float = (heavy_force if a.get("heavy", false) else light_force) * a.get("mult", 1.0)
	var push: Vector3 = fwd + Vector3.UP * a.get("up", 0.0)
	if a.get("side", false):
		push = fwd * 0.35 - global_basis.x + Vector3.UP * a.get("up", 0.0)   # balayage : il part sur ta gauche
	elif a.get("side_r", false):
		push = fwd * 0.6 + global_basis.x + Vector3.UP * a.get("up", 0.0)   # crochet / coude du bras gauche : il part sur ta droite
	var victim = part.get_parent()   # le sbire réellement touché (pas forcément la cible)
	var fb: float = lc.fall_bonus() if lc else 1.0   # coup aérien après une grande chute : plus fort
	var dmg: float = a.get("dmg", 0.0) * hit_mult * fb * ups.dmg_mult()
	var drop: float = 1.0 if hit_crit else a.get("drop", 0.0)
	force *= hit_mult * fb
	if fb > 1.25:
		_flash(Color(1, 0.6, 0.2), 0.06)
	var crit := hit_crit
	if a.get("crush", false) and victim.state == "stand" and victim.ai != "block":
		victim.trip(-fwd, dmg, -3.0)   # axe kick sur un sbire debout : écrasé au sol, à plat sur le dos...
		victim.land_bounce = victim.bounce   # ... et il rebondit haut
		connected = true
		_gain(dmg * 0.6)
		get_parent().impact(a.get("stop", 0.0), a.get("shake", 0.0))
		return
	if victim.hit(part, push.normalized() * force, center, dmg, drop, crit or hit_mult >= 1.99 or a.get("guard_break", false)):   # 3e coup du combo : brise-garde   # charge pleine / critique : passe la garde
		sho_blocked = attack in ["shoryu", "dive_kick"]
		velocity -= fwd * (a.lunge + 3.0)   # paré : on rebondit sur sa garde
		get_parent().impact(0.04, 0.2)
		return
	connected = true
	ups.on_hit(victim)   # Tazer
	if attack in ["dive_kick", "wall_run", "wall_run_h"]:
		if victim.state == "down" and victim.parts.pelvis.global_position.y < 0.6:
			victim.toss(Vector3.UP * 9.0 + fwd * 2.0, 3.0)   # sbire couché : il rebondit en l'air sous le coup
		velocity = -fwd * 3.0 + Vector3.UP * 5.5   # tu rebondis sur lui
		attack = ""   # tu peux réattaquer en l'air tout de suite
	if attack == "shoryu" and victim.state in ["launch", "down", "stand"]:
		victim.collar_grab()   # il reste collé au poing pendant toute la montée
		victim.held_blend = 0.04   # raccord très court jusqu'au poing
		enemy = victim
		sho_victim = victim
		sho_hold = true
	if a.get("dropkick", false):
		velocity = -fwd * 4.0 + Vector3.UP * 4.5   # tu rebondis sur lui
	elif a.get("air", false) and not attack in ["knee", "axe", "shoryu"]:
		velocity.y = maxf(velocity.y, AIR_HIT_BOUNCE)   # coup aérien qui touche : tu rebondis vers le haut avec lui (enchaîner, monter plus haut)
	_gain(dmg * 0.6)
	if crit:
		get_parent().impact(a.get("stop", 0.0) * 2.0, a.get("shake", 0.0) * 1.6)
		_flash(Color(1, 0.85, 0.3), 0.08)
	else:
		get_parent().impact(a.get("stop", 0.0), a.get("shake", 0.0))


## Chope : essaie d'attraper la cible, sinon l'ennemi le plus proche à portée.
func _try_grab() -> void:
	var keep_target := enemy
	var cands := enemies.duplicate()
	cands.sort_custom(func(a, b): return _dist_to(a) < _dist_to(b))
	if keep_target and keep_target in cands:
		cands.erase(keep_target)
		cands.push_front(keep_target)
	for e in cands:
		if e.parts.is_empty():
			continue
		enemy = e
		if _grab_target():
			return
	enemy = keep_target
	_try_prop()   # pas de sbire à portée : un objet du décor ?


func _dist_to(e) -> float:
	return INF if e.parts.is_empty() else e.parts.pelvis.global_position.distance_to(global_position)


## Une cible (enemy) : par les pieds (grand tour), en l'air, au sol par le col, ou debout. Renvoie true si attrapé.
func _grab_target() -> bool:
	if not is_on_floor():   # en l'air : chope plongeante (amélioration de saut)
		if not air_slam or enemy.state in ["held", "swung", "getup", "techroll", "rise"]:
			return false
		var reach := global_position - global_basis.z * 0.7 + Vector3.UP * 1.0
		var d3 := minf(enemy.parts.chest.global_position.distance_to(reach), enemy.parts.pelvis.global_position.distance_to(reach))
		if d3 > 1.3:
			return false
		enemy.collar_grab()
		start("air_slam")
		velocity = Vector3.UP * 2.0   # un instant suspendu en l'attrapant
		get_parent().impact(0.05, 0.3)
		return true
	if throw_move == "club" and (enemy.ragdolled() or enemy.grabbable()):   # massue : par les pieds, debout ou au sol
		var fwd0 := -global_basis.z
		var feet0: Vector3 = (enemy.parts.shin_l.global_position + enemy.parts.shin_r.global_position) * 0.5
		var hand0 := global_position + fwd0 * 0.6
		var close0 := feet0.distance_to(hand0 + Vector3.UP * 0.3) < 1.3 if is_on_floor() else feet0.distance_to(hand0 + Vector3.UP * 0.9) < 1.4
		if close0:
			var to0 := (feet0 - global_position) * Vector3(1, 0, 1)
			if to0.length() > 0.05:
				rotation.y = atan2(-to0.x, -to0.z)
			swap_feet = enemy.parts.shin_l.global_position.dot(global_basis.x) > enemy.parts.shin_r.global_position.dot(global_basis.x)
			enemy.feet_grab()   # debout, il bascule : on le tient par les chevilles
			swing_hold = 0.0
			collar_q = false
			club_hits = 0
			start("club_hold")
			get_parent().impact(0.05, 0.3)
			return true
		return false
	var fwd := -global_basis.z
	if enemy.ragdolled() and throw_move == "swing":   # amélioration : ennemi en ragdoll (au sol ou en l'air) attrapé par les pieds -> grand tour
		var hand := global_position + fwd * 0.6
		var feet: Vector3 = (enemy.parts.shin_l.global_position + enemy.parts.shin_r.global_position) * 0.5
		var close := ((feet - hand) * Vector3(1, 0, 1)).length() < 1.2 if is_on_floor() and feet.y < 0.6 else feet.distance_to(hand + Vector3.UP * 0.9) < 1.4
		if close:
			var to := (feet - global_position) * Vector3(1, 0, 1)
			if to.length() > 0.05:
				rotation.y = atan2(-to.x, -to.z)   # face à ses pieds
			# Chaque main prend la cheville qui est de son côté.
			var right := global_basis.x
			swap_feet = enemy.parts.shin_l.global_position.dot(right) > enemy.parts.shin_r.global_position.dot(right)
			enemy.feet_grab()
			swing_angle = 0.0
			swing_w = 0.0
			swing_hold = 0.0
			swing_stick_ok = false
			start("swing")
			get_parent().impact(0.05, 0.3)
			return true
		return false
	if enemy.air_grabbable() and not throw_move in ["swing", "club"]:   # en l'air : on le rattrape au vol, puis mêmes choix qu'au sol
		var reach := global_position + fwd * 0.7 + Vector3.UP * 1.2
		var d3 := minf(enemy.parts.chest.global_position.distance_to(reach), enemy.parts.pelvis.global_position.distance_to(reach))
		if d3 < 1.1:
			enemy.collar_grab()
			collar_limit = COLLAR_HOLD_RAGDOLL * (2.0 if btn_ups.has("defense") else 1.0)   # temps avant qu'il se dégage (bouclier humain : 2×)
			collar_held = 0.0
			collar_hits = 0
			collar_q = false
			start("collar")
			get_parent().impact(0.05, 0.3)
			return true
		return false
	if enemy.collar_grabbable():   # au sol : par le col
		var hand := global_position + fwd * 0.7
		var d := minf(((enemy.parts.chest.global_position - hand) * Vector3(1, 0, 1)).length(), ((enemy.parts.pelvis.global_position - hand) * Vector3(1, 0, 1)).length())
		if d < 0.9:
			enemy.collar_grab()
			collar_limit = COLLAR_HOLD_RAGDOLL * (2.0 if btn_ups.has("defense") else 1.0)   # temps avant qu'il se dégage (bouclier humain : 2×)
			collar_held = 0.0
			collar_hits = 0
			collar_q = false
			start("collar")
			get_parent().impact(0.04, 0.25)
			return true
		return false
	if not enemy.grabbable():
		return false
	var c: Vector3 = enemy.parts.chest.global_position
	if ((c - global_position - fwd * GRAB_REACH) * Vector3(1, 0, 1)).length() > 0.75:
		return false
	if enemy.ai == "block":   # en garde : projection de hanche
		enemy.collar_grab()
		start("hip_throw")
		get_parent().impact(0.05, 0.3)
		return true
	# Même logique que la chope au sol : on le tient ; poing = droites, rechope = fracas au sol.
	enemy.collar_grab()
	collar_limit = COLLAR_HOLD_STAND * (2.0 if btn_ups.has("defense") else 1.0)   # temps avant qu'il se dégage (bouclier humain : 2×)
	collar_held = 0.0
	collar_hits = 0
	collar_q = false
	start("collar")
	get_parent().impact(0.05, 0.3)
	return true


## Tenu par le col : on le place devant soi, et on choisit (poing = droite, chope = fracas, rien = on le lâche).
func _collar(_dt: float) -> void:
	collar_held += _dt
	queued = false
	var hb := heavy_buf > 0
	heavy_buf = 0.0
	var f := -global_basis.z
	var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
	if throw_move == "throw" and attack == "collar":
		# Lancer visé : R1 maintenu = il prend de l'élan tout seul (l'ennemi passe derrière son épaule) ; on vise en tournant au stick.
		if Input.is_action_pressed("grab") and collar_held < collar_limit:
			throw_t = minf(throw_t + _dt, THROW_WIND)
		elif t >= 0.05:
			_throw()
			return
		var w := smoothstep(0.0, 1.0, throw_t / THROW_WIND)
		var chest := (global_position + f * 0.62 + Vector3.UP * 1.25).lerp(global_position - f * 0.4 + global_basis.x * 0.25 + Vector3.UP * 1.7, w)
		enemy.hold(Basis(Vector3.UP.cross(f), deg_to_rad(lerpf(15.0, -35.0, w))) * face, chest)
		return
	enemy.hold(Basis(Vector3.UP.cross(f), deg_to_rad(15)) * face, global_position + f * 0.62 + Vector3.UP * 1.25)
	if Input.is_action_just_pressed("light"):
		collar_q = true   # gardé en mémoire : part dès que possible (prise en place, ou droite précédente finie)
	if collar_q and attack == "collar" and t >= 0.12:
		collar_q = false
		start("collar_punch")
	elif hb and attack in ["collar", "collar_punch"] and t >= 0.06:   # coup de tête : il le lâche au moment de l'impact
		start("headbutt")
	elif roll_buf > 0 and attack == "collar" and t >= 0.12:   # B : suplex (ou tomoe nage, variante v0.212)
		roll_buf = 0.0
		if collar_b == "tomoe":
			ups.start_tomoe()
		else:
			start("suplex")
	elif jump_buf > 0 and attack == "collar" and t >= 0.12:   # A : soulevé par le cou, saut, écrasé sur le dos
		jump_buf = 0.0
		start("piledriver")
	elif grab_buf > 0 and attack == "collar" and t >= 0.12 and _grater_wall():   # près d'un mur : râpe à fromage
		grab_buf = 0.0
	elif grab_buf > 0 and attack == "collar" and t >= 0.12:   # à deux mains, comme la chope : soulevé et fracassé
		grab_buf = 0.0
		slam_o = global_position
		slam_f = f
		slam_c0 = enemy.parts.chest.global_position
		enemy.grab()
		start("slam")
	elif collar_held > collar_limit and attack in ["collar", "collar_punch"]:   # trop long : il se dégage (vite s'il était debout)
		if collar_limit <= COLLAR_HOLD_STAND:
			enemy.break_free(f)   # il se dégage et retombe sur ses pieds
			velocity -= f * 3.0   # en te repoussant
		else:
			enemy.toss(Vector3.UP * 1.5 + f * 1.0, 1.0)
		attack = ""


## Lancer visé : il part devant, plus vite et plus loin selon l'élan ; en vol, son corps percute les autres sbires.
func _throw() -> void:
	var frac := throw_t / THROW_WIND
	var f := -global_basis.z
	enemy.throw_body(f * lerpf(5.0, 16.0, frac) + Vector3.UP * lerpf(2.0, 3.5, frac), THROW_DMG * (0.5 + frac))
	get_parent().impact(0.04 + 0.04 * frac, 0.3 + 0.4 * frac)
	start("throw_release")
	hit_done = true
	connected = true


## Massue humaine : tenu par les chevilles tant que R1 est maintenu (on marche en le traînant) ; X = il l'abat par-dessus sa tête
## sur ce qui est devant ; son corps percute les sbires pendant la descente. R1 relâché : on le lâche.
func _club(dt: float) -> void:
	queued = false
	heavy_buf = 0.0
	swing_hold += dt
	var f := -global_basis.z
	var hang := (f * 0.5 - Vector3.UP).normalized()   # au repos : il pend devant, traîne au sol
	var out := hang
	var sweep := false
	if attack == "club_swing":
		# Trajectoire du corps (direction cheville -> genou) : devant en bas, puis côté droit, arrière, au-dessus de la tête, et abattu devant.
		var right := global_basis.x
		var path := [hang, (right - Vector3.UP * 0.4 + f * 0.2).normalized(), (-f * 0.8 + right * 0.5 - Vector3.UP * 0.1).normalized(),
			(Vector3.UP - f * 0.4).normalized(), (f - Vector3.UP * 0.4).normalized()]
		var times := [0.0, 0.16, 0.32, 0.46, ATK.club_swing.active]
		out = path[4]
		for i in 4:
			if t <= times[i + 1]:
				var u := clampf((t - times[i]) / (times[i + 1] - times[i]), 0.0, 1.0)
				if i == 3:
					u = u * u   # il accélère en s'abattant
				out = (path[i] as Vector3).slerp(path[i + 1], u)
				break
		sweep = t > 0.12 and t <= ATK.club_swing.active + 0.02   # le corps percute tout le long du cercle
	var l: Vector3 = j.fist_l.global_position
	var r: Vector3 = j.fist_r.global_position
	enemy.feet_hold(r if swap_feet else l, l if swap_feet else r, out, dt, sweep)
	if Input.is_action_just_pressed("light"):
		collar_q = true
	if collar_q and attack == "club_hold" and t >= 0.15:
		collar_q = false
		enemy.swing_victims.clear()   # chaque coup de massue peut retoucher les mêmes sbires
		start("club_swing")
	if attack == "club_hold" and club_hits >= CLUB_HITS:   # 3 coups : il est lâché tout seul, projeté devant
		enemy.swing_release(global_position + Vector3.UP, Vector3.ZERO, 0.0)
		enemy.toss(f * 5.0 + Vector3.UP * 3.0, 2.0)
		attack = ""
		return
	if not Input.is_action_pressed("grab") or swing_hold >= CLUB_HOLD:   # R1 relâché : on le lâche
		enemy.swing_release(global_position + Vector3.UP, Vector3.ZERO, 0.0)
		attack = ""


## Grand tour : tenu par les chevilles tant que R1 est maintenu ; le stick fait tourner, R1 relâché le lance.
func _swing(dt: float, dir: Vector3) -> void:
	# Il tourne tout seul (vitesse de base, prise en ~0,4 s) ; faire des cercles au stick accélère la rotation
	# (jusqu'à SWING_TURN) ; des cercles dans l'autre sens inversent le tour.
	var target := SWING_BASE * smoothstep(0.0, 0.4, swing_hold)
	if dir.length() > 0.5:
		var a := atan2(-dir.x, -dir.z)
		if swing_stick_ok:
			var ws := angle_difference(swing_stick, a) / dt   # vitesse de rotation du stick
			if absf(ws) > 6.0 and signf(ws) != swing_sign:
				swing_sign = signf(ws)
			if absf(ws) > 2.0:
				target = clampf(SWING_BASE + absf(ws) * 0.8, SWING_BASE, SWING_TURN)
		swing_stick = a
		swing_stick_ok = true
	else:
		swing_stick_ok = false
	swing_w = lerpf(swing_w, swing_sign * target, 1.0 - exp(-6.0 * dt))
	rotation.y += swing_w * dt
	swing_angle += absf(swing_w) * dt
	swing_hold += dt
	var f := -global_basis.z
	# Ses chevilles sont collées à nos poings ; le reste de son corps est en ragdoll et suit (il traîne, puis s'envole à l'horizontale).
	var out := (f - Vector3.UP * 0.25).normalized()
	var l: Vector3 = j.fist_l.global_position
	var r: Vector3 = j.fist_r.global_position
	enemy.feet_hold(r if swap_feet else l, l if swap_feet else r, out, dt)
	if not Input.is_action_pressed("grab") or swing_hold >= SWING_HOLD:   # R1 relâché (ou tenu trop longtemps) : il part avec la vitesse du moment
		var power := clampf(absf(swing_w) / SWING_TURN, 0.2, 1.0)
		enemy.swing_release(global_position + Vector3.UP * 1.0, Vector3.UP * swing_w, SWING_DMG * (0.4 + power))
		get_parent().impact(0.05 + 0.04 * power, 0.3 + 0.5 * power)
		start("swing_finish")
		hit_done = true
		connected = true


## Droite pendant qu'on le tient ; la 3e le renvoie en l'air (saut d'annulation possible pour le jongler).
func _collar_punch() -> void:
	collar_hits += 1
	enemy.collar_hit(7.0)
	get_parent().impact(0.06, 0.5)
	if collar_hits >= 3 or enemy.hp <= 0:
		var f := -global_basis.z
		enemy.toss(Vector3.UP * 8.0 + f * 1.2, 4.0)
		start("collar_finish")
		hit_done = true
		connected = true
		collar_q = false


## Pendant le slam : où est son buste et comment son corps est tourné. Soulevé au-dessus de la tête en basculant vers nous,
## puis abattu en arc devant, de plus en plus vite, jusqu'à finir sur le dos.
func _hold() -> void:
	var up := Vector3.UP
	var axis := up.cross(slam_f)   # tourner autour de cet axe = basculer en arrière (tête vers l'avant du joueur)
	var face := Basis(up, atan2(-slam_f.x, -slam_f.z))   # il nous fait face
	var top := slam_o + up * 2.3 + slam_f * 0.1
	var chest: Vector3
	var tilt: float
	if t < SLAM_LIFT:
		var u := smoothstep(0.0, 1.0, t / SLAM_LIFT)
		chest = slam_c0.lerp(top, u)
		tilt = lerpf(0.0, -40.0, u)
	else:
		var u := clampf((t - SLAM_LIFT) / (ATK.slam.active - SLAM_LIFT), 0.0, 1.0)
		u *= u   # il accélère vers le sol
		var ctrl := slam_o + up * 2.4 + slam_f * 1.4
		var ground := Vector3(slam_o.x, 0.18, slam_o.z) + slam_f * 1.6   # toujours au sol, même si on l'a chopé en l'air
		chest = top.lerp(ctrl, u).lerp(ctrl.lerp(ground, u), u)
		tilt = lerpf(-40.0, 90.0, u)
	enemy.hold(Basis(axis, deg_to_rad(tilt)) * face, chest)


# =====================================================================================================================
# Coups de l'atelier (statut « À tester » sur le site). Chaque coup a sa fiche dans moves/ ; ici, ce qu'il fait.
# =====================================================================================================================

const ATELIER_HOLDS := ["tackle", "suplex", "piledriver", "hip_throw", "cheese_grater", "cheese_grater_r", "prop_shield", "prop_bash", "tomoe"]
const PENALTY := ["drop_land", "sm_land", "tackle_slam", "pd_land"]   # au sol après un coup risqué : rien ne coupe ces temps-là
const AIR_LOCKED := ["drop_kick", "superman", "piledriver", "sj_grab", "wall_run_h"]   # coups aériens qu'aucune esquive ne coupe
const AFTER_ROLL := 0.3      # contre de sortie de roulade : fenêtre après la fin de l'esquive
const XY_WINDOW := 0.1       # X et Y « en même temps »
const SUPER_HOLD := 0.2      # A maintenu ce temps : super saut
const SUPER_JUMP := 12.5
const TACKLE_SPEED := 9.0
const TACKLE_TIME := 0.34    # plus court qu'avant (0,5 s) : il emporte moins loin
const GRATER_TIME := 1.3
const GRATER_SPEED := 5.5
const SHIELD_HOLD := 0.22    # R1 maintenu ce temps avec un objet : bouclier
const SHIELD_HITS := 3
const BASH_HITS := 3
const WALL_REACH := 1.5

@export_enum("dropkick", "bicycle") var air_heavy := "dropkick"   # Y en l'air : chassé sauté (base) ou bicyclette (forme)

var clock := 0.0
var since_roll := 9.0
var last_light_t := -9.0
var last_heavy_t := -9.0
var move_dir := Vector3.FORWARD
var spin_left := 0.0
var spin_speed := 0.0
var spin_hits := {}
var jump_held := 0.0
var super_used := false
var super_air := false
var tramp_cd := 0.0
var hold_o := Vector3.ZERO
var hold_f := Vector3.FORWARD
var hold_c0 := Vector3.ZERO
var tackle_victim: Node3D = null
var last_tackle_dmg := 0.0   # (tests) dégâts du dernier plaquage
var tackle_into := ""   # plaquage (v0.212) : "wall" = écrasé contre un mur (le dos casse), "table" = fracassé sur une table
var wall_n := Vector3.ZERO
var wall_p := Vector3.ZERO
var wall_tan := Vector3.ZERO
var wall_flip := false
var wall_dive := false
var prop_hits := 0
var shield_hits := 0
var shield_press := -1.0
var spark_t := 0.0
var spin_turn := 0
var hold_yaw := 0.0
var idle_t := 0.0
var sj_target: Node3D = null
var wall_side := 1.0
var wall_hit_t := 0.0
@export var tackle_up := false   # amélioration : R1 en plein sprint = plaquage
@export var counter_triple := false   # amélioration du contre tournant : 3 tours en sortie de roulade
@export_range(1, 3) var air_dodges := 1   # esquives aériennes par saut (améliorations : 2, puis 3)
var air_dash_n := 0


## X + Y ensemble (superman punch). Appelé à chaque image avant le traitement des boutons.
func _atelier_inputs(grounded: bool, holding: bool) -> void:
	clock += get_physics_process_delta_time()
	tramp_cd -= get_physics_process_delta_time()
	if Input.is_action_pressed("jump"):
		jump_held += get_physics_process_delta_time()
	else:
		jump_held = 0.0
	var lp := Input.is_action_just_pressed("light")
	var hp_ := Input.is_action_just_pressed("heavy")
	if hurt > 0 or roll >= 0 or holding:
		if lp: last_light_t = clock
		if hp_: last_heavy_t = clock
		return
	# X + Y ensemble : superman punch (le coup parti au premier appui est coupé).
	if grounded and ((lp and hp_ and (attack == "" or ((attack in ["jab", "cross"] or ATK.get(attack, {}).get("heavy", false)) and t < 0.06)))
			or (lp and clock - last_heavy_t < XY_WINDOW and (attack == "" or (ATK.get(attack, {}).get("heavy", false) and t < 0.06) or y_hold >= 0.0))
			or (hp_ and clock - last_light_t < XY_WINDOW and (attack == "" or (attack in ["jab", "cross"] and t < 0.06)))):
		y_hold = -1.0
		queued = false
		light_buf = 0.0
		heavy_buf = 0.0
		x_fired = true
		start("superman")
	if lp:
		last_light_t = clock
	if hp_:
		last_heavy_t = clock


## X (appui, au sol) dans une situation particulière. Renvoie true s'il a lancé un coup de l'atelier.
func _atelier_light(grounded: bool) -> bool:
	if not grounded or attack in PENALTY or attack == "superman":
		return attack in PENALTY or attack == "superman"
	if form_counter and since_roll < AFTER_ROLL and attack == "":
		start("spin_counter3" if counter_triple else "spin_counter")   # juste à la sortie d'une roulade : revers tournant
		return true
	return false


## Y (appui, au sol) dans une situation particulière. Renvoie true s'il a lancé un coup de l'atelier.
func _atelier_heavy() -> bool:
	if attack == "superman" or attack in PENALTY:
		return true
	if form_dropkick and sprinting and attack == "":
		sprinting = false
		start("drop_kick")   # Y en plein sprint : drop kick
		return true
	if form_capoeira and since_roll < AFTER_ROLL and attack == "":
		start("capoeira")   # sortie de roulade : retourné bas, mains au sol
		return true
	if _downed_in_front() != null:
		enemy = _downed_in_front()
		start("soccer_kick")   # ennemi couché devant : shoot
		return true
	if _prop_in_front() != null:
		held_prop = null
		start("prop_kick")   # objet au sol devant : shoot d'objet
		return true
	if stick_dir.length() > 0.5 and _find_wall(stick_dir):
		start("wall_run")   # stick vers un mur tout proche : course au mur
		return true
	if stick_dir.length() > 0.5 and _side_wall(stick_dir):
		start("wall_run_h")   # mur tout proche sur le côté, stick le long du mur : course au mur horizontale
		return true
	return false


## Sbire couché juste devant (bassin bas, à portée de pied / de poing).
func _downed_in_front() -> Node3D:
	var f := -global_basis.z
	var best: Node3D = null
	var bd := 2.0
	for e in enemies:
		if e.parts.is_empty() or not e.state in ["down", "dead"]:
			continue
		var p: Vector3 = e.parts.pelvis.global_position
		if p.y > 0.6:
			continue
		var d := (p - global_position) * Vector3(1, 0, 1)
		if d.length() < bd and (d.length() < 0.5 or f.angle_to(d) < deg_to_rad(70)):
			bd = d.length()
			best = e
	return best


## Objet du décor posé au sol, juste devant.
func _prop_in_front() -> RigidBody3D:
	var f := -global_basis.z
	var best: RigidBody3D = null
	var bd := 1.3
	for b in get_tree().get_nodes_in_group("reactive"):
		if not b is RigidBody3D or b.freeze or b == held_prop:
			continue
		var d: Vector3 = (b.global_position - global_position) * Vector3(1, 0, 1)
		if d.length() < bd and f.angle_to(d) < deg_to_rad(60) and b.global_position.y < 1.0:
			bd = d.length()
			best = b
	return best


## Mur (décor fixe) devant, dans cette direction ; garde son point et sa normale.
func _find_wall(dir: Vector3) -> bool:
	var from_p := global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(from_p, from_p + dir.normalized() * WALL_REACH, 1)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or not r.collider is StaticBody3D or absf(r.normal.y) > 0.5:
		return false
	wall_p = r.position
	wall_n = (r.normal * Vector3(1, 0, 1)).normalized()
	return true


## Au début de chaque coup de l'atelier.
func _atelier_start(kind: String) -> void:
	var f := -global_basis.z
	match kind:
		"superman":
			velocity = f * 9.0 + Vector3.UP * 4.5
		"drop_kick":
			velocity = f * 9.5 + Vector3.UP * 5.0
		"tackle":
			tackle_victim = null
			move_dir = f
		"spin_counter3":
			spin_left = TAU * 3.0
			spin_speed = TAU / 0.22
			spin_hits.clear()
			spin_turn = 0
		"spin_counter":
			spin_left = TAU
			spin_speed = TAU / 0.26
			spin_hits.clear()
		"capoeira":
			spin_left = TAU
			spin_speed = TAU / 0.34
			spin_hits.clear()
		"wall_run_h":
			rotation.y = atan2(-wall_tan.x, -wall_tan.z)   # il court le long du mur
			wall_side = 1.0 if global_basis.x.dot(-wall_n) > 0.0 else -1.0   # mur à droite (1) ou à gauche (-1)
			spin_hits.clear()
			global_position.y = maxf(global_position.y, 0.05)
		"sj_grab":
			sj_target = _sj_pick()
			super_air = false
		"wall_run":
			rotation.y = atan2(wall_n.x, wall_n.z)   # face au mur
			wall_flip = false
			wall_dive = false
		"suplex", "hip_throw", "piledriver":
			hold_o = global_position
			hold_f = f
			hold_yaw = rotation.y
			if enemy and enemy.state == "held":
				hold_c0 = enemy.parts.chest.global_position
				enemy.grab()
		"prop_bash", "prop_shield":
			pass


## Chaque image (après les déplacements) : ce que font les coups de l'atelier en cours.
func _atelier_tick(dt: float) -> void:
	var f := -global_basis.z
	if spin_left > 0.0 and attack in ["spin_counter", "spin_counter3", "capoeira"]:   # coups tournants : le perso entier fait un tour
		var step := minf(spin_left, spin_speed * dt)
		rotation.y -= step
		spin_left -= step
		if attack == "spin_counter3" and int((TAU * 3.0 - spin_left) / TAU) != spin_turn:
			spin_turn = int((TAU * 3.0 - spin_left) / TAU)
			spin_hits.clear()   # chaque tour peut retoucher
	elif not attack in ["spin_counter", "spin_counter3", "capoeira"]:
		spin_left = 0.0
	match attack:
		"spin_counter":
			velocity.x *= 0.8
			velocity.z *= 0.8
			if t >= ATK.spin_counter.active and t < 0.32:
				_ring_hit(1.85, heavy_force * 0.75, 0.35, 12.0)
		"spin_counter3":
			velocity.x *= 0.8
			velocity.z *= 0.8
			if t >= ATK.spin_counter3.active and spin_left > 0.0:
				_ring_hit(1.85, heavy_force * 0.6, 0.35, 9.0)
		"wall_run_h":
			_wall_run_h_tick(dt)
		"sj_grab":
			_sj_grab_tick()
		"capoeira":
			velocity.x = 0.0
			velocity.z = 0.0
			if t >= ATK.capoeira.active and t < 0.42:
				_ring_hit(1.7, 0.0, 0.0, 10.0, true)
		"tackle":
			_tackle_tick(dt)
		"tackle_slam":
			if t < ATK.tackle_slam.active:
				velocity.x = f.x * 4.0   # il plonge sur lui
				velocity.z = f.z * 4.0
				if tackle_victim and is_instance_valid(tackle_victim) and tackle_victim.state == "held":
					var u := smoothstep(0.0, 1.0, t / ATK.tackle_slam.active)
					var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
					var top := global_position + f * 0.55 + Vector3.UP * 1.25
					var floor_p := global_position + f * 0.75 + Vector3.UP * 0.32
					tackle_victim.hold(Basis(Vector3.UP.cross(f), deg_to_rad(lerpf(-75.0, 88.0, u))) * face, top.lerp(floor_p, u))
		"suplex":
			_suplex_hold()
		"tomoe":
			ups.tomoe_tick()
		"hip_throw":
			_hip_throw_hold()
		"piledriver":
			_piledriver_tick()
		"cheese_grater", "cheese_grater_r":
			_grater_tick(dt)
		"prop_shield":
			velocity.x *= 0.3
			velocity.z *= 0.3
			if not Input.is_action_pressed("grab"):
				attack = "prop_hold"   # R1 relâché : il le tient de nouveau au-dessus de la tête
				t = 0.15
				prop_t = 0.2
		"wall_run":
			if t < 0.34:
				velocity = -wall_n * 0.8 + Vector3.UP * 7.0   # il court sur le mur
			elif not wall_flip:
				wall_flip = true
				velocity = wall_n * 5.0 + Vector3.UP * 4.0   # salto arrière en se repoussant
			elif t >= ATK.wall_run.active and not wall_dive:
				wall_dive = true
				rotation.y = atan2(-wall_n.x, -wall_n.z)   # il se retrouve face à la salle : le piqué part vers l'avant
				velocity = wall_n * 6.5 + Vector3.DOWN * 9.0
			elif wall_dive:
				velocity = wall_n * 6.5 + Vector3.DOWN * 9.0
	if attack in ["soccer_kick", "prop_kick", "hip_throw", "drop_land", "pd_land", "suplex", "sm_land"] or (attack == "tackle_slam" and t >= ATK.tackle_slam.active):
		velocity.x = 0.0
		velocity.z = 0.0
	# Super saut : A maintenu juste après le décollage.
	if form_superjump and air and not super_used and jump_held >= SUPER_HOLD and velocity.y > 0.0 and attack == "" and not is_on_floor():
		super_used = true
		super_air = true
		velocity.y = SUPER_JUMP
		start("super_jump")
	# Trampoline : en retombant sur un sbire couché, on rebondit (de plus en plus haut) et lui aussi.
	if trampoline and air and velocity.y < -1.0 and tramp_cd <= 0.0 and attack in ["", "tramp", "super_jump", "air"]:
		for e in enemies:
			if e.parts.is_empty() or not e.state in ["down", "dead"]:
				continue
			var p: Vector3 = e.parts.pelvis.global_position
			var lying: bool = p.y < 0.45 and e.parts.pelvis.linear_velocity.length() < 2.0   # vraiment couché, pas en plein jongle
			if lying and ((p - global_position) * Vector3(1, 0, 1)).length() < 0.7 and global_position.y < 0.9 and global_position.y > 0.15:
				tramp_cd = 0.3
				velocity.y = clampf(-velocity.y * 1.15, 9.0, 15.0)
				e.toss(Vector3.UP * 7.0 + f * 0.5, 2.0)
				e.hp = maxf(e.hp - 5.0, 0.0)
				start("tramp")
				air_hits = 0
				air_heavy_used = false
				get_parent().impact(0.05, 0.5)
				break


## À l'atterrissage d'un coup aérien de l'atelier. Renvoie true s'il a pris la main.
func _atelier_land(was: String) -> bool:
	if super_air:
		super_air = false
		start("dive_land")
		land = 0.0
		_dive_shock()
		return true
	match was:
		"superman":
			start("sm_land")   # punitif : il retombe à plat ventre, puis se relève vite
			land = 0.0
			velocity.x *= 0.3
			velocity.z *= 0.3
			return true
		"sj_grab":
			_shock_ring(global_position)
			_area_hit(global_position, 1.4, 6.0)
			start("dive_land")
			land = 0.0
			return true
		"wall_run_h":
			start("dive_land")
			land = 0.0
			return true
		"drop_kick":
			start("drop_land")   # gros risque : il retombe sur le dos
			land = 0.0
			return true
		"piledriver":
			if enemy and enemy.state == "held":
				enemy.slam(hold_f, 24.0, 0.6)
				_area_hit(enemy.parts.pelvis.global_position, 1.3, 10.0, enemy)
				_shock_ring(global_position + hold_f * 0.6)
				connected = true
				_gain(15.0)
				get_parent().impact(0.14, 1.2)
			start("pd_land")
			land = 0.0
			return true
		"wall_run":
			_shock_ring(global_position)
			_area_hit(global_position, 1.4, 8.0)
			start("dive_land")
			land = 0.0
			return true
	return false


## Coups de l'atelier qui frappent autrement qu'avec un poing ou un pied (do_hit, à l'instant de l'impact).
func _atelier_hit() -> void:
	var f := -global_basis.z
	match attack:
		"soccer_kick":
			var e := _downed_in_front()
			if e:
				e.hp = maxf(e.hp - 6.0, 0.0)
				e.throw_body(f * 16.0 + Vector3.UP * 1.6, 12.0)   # boulet au ras du sol : il fauche tout sur sa ligne
				connected = true
				_gain(8.0)
				get_parent().impact(0.1, 0.9)
		"prop_kick":
			var b := _prop_in_front()
			if b:
				b.freeze = false
				b.linear_velocity = f * 15.0 + Vector3.UP * 3.0
				b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
				flying.append({"b": b, "t": 0.0, "hits": {}})
				get_parent().impact(0.05, 0.5)
		"prop_bash":
			var at := global_position + f * 1.1 + Vector3.UP * 0.8
			var hit_any := false
			for e in enemies:
				if e.parts.is_empty() or e.state in ["held", "swung"]:
					continue
				var c: Vector3 = e.parts.chest.global_position
				if c.distance_to(at) < 1.1 or e.parts.pelvis.global_position.distance_to(at) < 1.1:
					e.hit(e.parts.chest, (f + Vector3.UP * 0.3).normalized() * heavy_force, c, PROP_DMG, 1.0, true)
					hit_any = true
			prop_hits += 1
			connected = hit_any
			get_parent().impact(0.09 if hit_any else 0.04, 0.8 if hit_any else 0.3)
			if prop_hits >= BASH_HITS:
				_break_prop()   # 3e coup : l'objet vole en morceaux
		"suplex":
			if enemy and enemy.state == "held":
				enemy.slam(-hold_f, 22.0)   # derrière lui, la tête la première
				_area_hit(enemy.parts.pelvis.global_position, 1.3, 8.0, enemy)
				_shock_ring(global_position - hold_f * 1.2)
				connected = true
				_gain(13.0)
				get_parent().impact(0.13, 1.1)
		"hip_throw":
			if enemy and enemy.state == "held":
				enemy.slam(-hold_f, 18.0, 0.8)
				connected = true
				_gain(11.0)
				_shock_ring(hold_o - hold_f * 1.1)
				get_parent().impact(0.11, 0.9)
		"tackle_slam":
			if tackle_victim and is_instance_valid(tackle_victim) and tackle_victim.state == "held":
				var at: Vector3 = tackle_victim.parts.pelvis.global_position
				var extra := 0.0
				for b in get_tree().get_nodes_in_group("reactive"):   # une table sous lui : elle vole en éclats (façon catch)
					if b.has_meta("breakable") and is_instance_valid(b) and ((b.global_position - at) * Vector3(1, 0, 1)).length() < 1.5:
						if TestMap.shatter(b, -global_basis.z * 4.0):
							tackle_into = "table"
							extra = 14.0
				if tackle_into == "wall":
					extra = 16.0   # écrasé contre le mur : le dos casse
					_flash(Color(1, 0.4, 0.3), 0.08)
				tackle_victim.slam(-global_basis.z, 20.0 + extra, 0.12 if extra == 0.0 else 0.35)   # plaqué : il reste au sol, sous toi
				last_tackle_dmg = 20.0 + extra
				if extra > 0.0:
					get_parent().impact(0.18, 1.5)
				_area_hit(tackle_victim.parts.pelvis.global_position, 1.4, 8.0, tackle_victim)
				_shock_ring(global_position - global_basis.z * 0.8)
				connected = true
				_gain(12.0)
				get_parent().impact(0.13, 1.1)
			tackle_victim = null
			tackle_into = ""


## Tous les sbires autour (une fois chacun par coup, sauf si spin_hits est vidé) : projetés vers l'extérieur, ou fauchés.
func _ring_hit(radius: float, force: float, up: float, dmg: float, trip := false) -> void:
	for e in enemies:
		if e.parts.is_empty() or spin_hits.has(e) or e.state in ["held", "swung", "getup", "techroll", "rise"]:
			continue
		var c: Vector3 = e.parts.chest.global_position
		var d := (c - global_position) * Vector3(1, 0, 1)
		if d.length() > radius or (c.y > 2.2):
			continue
		spin_hits[e] = true
		var out := d.normalized() if d.length() > 0.05 else -global_basis.z
		if trip and e.state == "stand":
			e.trip(out, dmg)
		else:
			e.hit(e.parts.chest, (out + Vector3.UP * up).normalized() * maxf(force, light_force), c, dmg, 1.0, true)
		connected = true
		_gain(dmg * 0.6)
		get_parent().impact(0.05, 0.5)


## Plaquage : il fonce ; le premier sbire debout croisé est emporté sur l'épaule, puis écrasé au sol ; les autres sur la route sont bousculés.
func _tackle_tick(_dt: float) -> void:
	var f := move_dir
	velocity.x = f.x * TACKLE_SPEED
	velocity.z = f.z * TACKLE_SPEED
	for e in enemies:
		if e.parts.is_empty() or e == tackle_victim or e.state in ["held", "swung"]:
			continue
		var c: Vector3 = e.parts.chest.global_position
		var d := (c - global_position) * Vector3(1, 0, 1)
		if d.length() < 1.0 and f.angle_to(d) < deg_to_rad(60):
			if tackle_victim == null and e.state == "stand":
				tackle_victim = e
				enemy = e
				e.collar_grab()
				e.grab()
				get_parent().impact(0.05, 0.5)
			elif e.state == "stand":
				e.hit(e.parts.chest, (f + global_basis.x * signf(d.dot(global_basis.x)) + Vector3.UP * 0.4).normalized() * heavy_force * 0.8, c, 8.0, 1.0, true)
	if tackle_victim and is_instance_valid(tackle_victim) and tackle_victim.state == "held":
		var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
		tackle_victim.hold(Basis(Vector3.UP.cross(f), deg_to_rad(-75)) * face, global_position + f * 0.55 + Vector3.UP * 1.25)   # plié sur l'épaule
	if tackle_victim and is_instance_valid(tackle_victim) and tackle_victim.state == "held" and tackle_into == "":
		var pr := lc.probe(f, 1.1) if lc else {}
		if not pr.is_empty() and (pr.top == INF or pr.rel > 1.4):
			tackle_into = "wall"   # un mur droit devant : il l'y écrase
			start("tackle_slam")
			return
	if t >= TACKLE_TIME * attack_speed or (tackle_victim and t >= 0.3 * attack_speed):
		if tackle_victim:
			start("tackle_slam")
		else:
			attack = ""   # raté : il s'arrête


## Suplex : le buste de l'ennemi passe de devant, à au-dessus de la tête, à derrière au sol, la tête en bas.
func _suplex_hold() -> void:
	if enemy == null or enemy.state != "held" or hit_done:
		return
	var f := hold_f
	var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
	var axis := Vector3.UP.cross(f)
	var p0 := hold_c0
	var p1 := hold_o + f * 0.4 + Vector3.UP * 1.15
	var p2 := hold_o + f * 0.1 + Vector3.UP * 2.15
	var p3 := hold_o - f * 1.15 + Vector3.UP * 0.4
	var chest: Vector3
	var tilt := 0.0
	if t < 0.1:
		chest = p0.lerp(p1, smoothstep(0.0, 1.0, t / 0.1))
	elif t < 0.3:
		var u := smoothstep(0.0, 1.0, (t - 0.1) / 0.2)
		chest = p1.lerp(p2, u)
		tilt = lerpf(0.0, -60.0, u)
	else:
		var u := clampf((t - 0.3) / (ATK.suplex.active - 0.3), 0.0, 1.0)
		u *= u
		chest = p2.lerp(p3, u)
		tilt = lerpf(-60.0, -175.0, u)
	enemy.hold(Basis(axis, deg_to_rad(tilt)) * face, chest)


## Projection de hanche : le héros pivote d'un demi-tour (dos au sbire), le charge sur sa hanche, puis le bascule
## par-dessus lui : le sbire fait un tour en l'air et retombe sur le dos de l'autre côté, devant le héros.
func _hip_throw_hold() -> void:
	var f := hold_f
	rotation.y = hold_yaw + PI * smoothstep(0.0, 1.0, t / 0.12)   # il se retourne dans le sbire
	if enemy == null or enemy.state != "held" or hit_done:
		return
	var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
	var axis := Vector3.UP.cross(f)
	var p0 := hold_c0
	var p1 := hold_o + f * 0.3 + Vector3.UP * 1.3             # chargé sur la hanche, plaqué contre son dos
	var pc := hold_o - f * 0.1 + Vector3.UP * 2.5             # sommet : il passe au-dessus du héros
	var p3 := hold_o - f * 1.05 + Vector3.UP * 0.3           # au ras du sol, de l'autre côté
	var chest: Vector3
	var tilt := 0.0
	if t < 0.12:
		var u := smoothstep(0.0, 1.0, t / 0.12)
		chest = p0.lerp(p1, u)
		tilt = lerpf(0.0, -35.0, u)
	else:
		var u := clampf((t - 0.12) / (ATK.hip_throw.active - 0.12), 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u) * 0.35 + u * u * 0.65   # il accélère en retombant
		chest = p1.lerp(pc, u).lerp(pc.lerp(p3, u), u)
		tilt = lerpf(-35.0, -268.0, u)   # tête la première par-dessus, il finit sur le dos
	enemy.hold(Basis(axis, deg_to_rad(tilt)) * face, chest)


## Prise de catch : bras enroulé autour du cou, il saute avec lui ; en l'air, le héros se couche à l'horizontale pieds devant
## et son bras force le sbire à se coucher aussi, dans l'autre sens (tête vers l'avant, sur le dos) ; tous deux s'écrasent au sol.
func _piledriver_tick() -> void:
	if t >= 0.3 and t - get_physics_process_delta_time() * attack_speed < 0.3:
		velocity.y = 7.0   # il saute avec lui
		velocity.x = hold_f.x * 1.5
		velocity.z = hold_f.z * 1.5
	if t < 0.3:
		velocity.x = 0.0
		velocity.z = 0.0
	if enemy == null or enemy.state != "held":
		return
	var f := hold_f
	var face := Basis(Vector3.UP, atan2(-f.x, -f.z))
	var axis := Vector3.UP.cross(f)
	var side := Vector3.UP.cross(f).normalized() * -1.0   # à droite du héros (côté du bras qui serre)
	var lock_p := global_position + f * 0.5 + Vector3.UP * 1.05   # tête bloquée sous son bras, plié en avant
	var flat_p := global_position + Vector3.UP * 0.62 + side * 0.42 - f * 0.12   # couché à côté de lui, à la même hauteur
	var chest: Vector3
	var tilt: float
	if t < 0.15:
		var u := smoothstep(0.0, 1.0, t / 0.15)
		chest = hold_c0.lerp(lock_p, u)
		tilt = lerpf(0.0, -50.0, u)
	elif t < 0.34:
		chest = lock_p
		tilt = -50.0
	else:
		var u := smoothstep(0.0, 1.0, (t - 0.34) / 0.26)   # le bras le force à l'horizontale, en même temps que le héros se couche
		chest = lock_p.lerp(flat_p, u)
		tilt = lerpf(-50.0, 90.0, u)
	enemy.hold(Basis(axis, deg_to_rad(tilt)) * face, chest)


## Râpe à fromage : il court le long du mur en frottant la tête de l'ennemi dessus (étincelles), puis le lâche.
func _grater_tick(dt: float) -> void:
	if enemy == null or enemy.state != "held":
		attack = ""
		return
	velocity.x = wall_tan.x * GRATER_SPEED
	velocity.z = wall_tan.z * GRATER_SPEED
	rotation.y = atan2(-wall_tan.x, -wall_tan.z)
	var face := Basis(Vector3.UP, atan2(-wall_n.x, -wall_n.z))   # son dos contre le mur, il nous regarde
	var c := global_position + Vector3.UP * 1.2
	var on_wall := wall_p + (c - wall_p).slide(wall_n)
	on_wall.y = 1.25
	enemy.hold(Basis(Vector3.UP.cross(wall_n), deg_to_rad(-25)) * face, on_wall + wall_n * 0.32)
	spark_t -= dt
	if spark_t <= 0.0:
		spark_t = 0.12
		enemy.collar_hit(2.5)
		_sparks(enemy.parts.head.global_position - wall_n * 0.1)
		get_parent().impact(0.0, 0.25)
	if t >= GRATER_TIME * attack_speed:
		enemy.toss(wall_n * 6.0 + Vector3.UP * 3.0, 3.0)   # lâché, projeté loin du mur
		start("collar_finish")
		hit_done = true
		connected = true


## Petite gerbe d'étincelles.
func _sparks(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -12, 0)
	var m := BoxMesh.new()
	m.size = Vector3(0.03, 0.03, 0.03)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1.0, 0.85, 0.3)
	m.material = sm
	p.mesh = m
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


## L'objet tenu vole en morceaux (coup de chaise ou bouclier cassé).
func _break_prop() -> void:
	if held_prop == null or not is_instance_valid(held_prop):
		held_prop = null
		attack = ""
		return
	var b := held_prop
	held_prop = null
	var col := Color(0.55, 0.4, 0.25)
	for c in b.get_children():
		if c is MeshInstance3D and c.material_override is StandardMaterial3D:
			col = c.material_override.albedo_color
			break
	var at := b.global_position
	for i in 6:
		var piece := RigidBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = BoxShape3D.new()
		var sz := Vector3(randf_range(0.08, 0.22), randf_range(0.05, 0.12), randf_range(0.08, 0.3))
		cs.shape.size = sz
		piece.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.mesh.size = sz
		var pm := StandardMaterial3D.new()
		pm.albedo_color = col
		mi.material_override = pm
		piece.add_child(mi)
		piece.collision_layer = 1
		piece.collision_mask = 1
		piece.mass = 0.5
		get_parent().add_child(piece)
		piece.global_position = at + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.3), randf_range(-0.2, 0.2))
		piece.linear_velocity = (-global_basis.z * 3.0 + Vector3(randf_range(-3, 3), randf_range(2, 5), randf_range(-3, 3)))
		piece.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
		get_tree().create_timer(6.0).timeout.connect(piece.queue_free)
	b.queue_free()
	prop_hits = 0
	shield_hits = 0
	attack = ""
	get_parent().impact(0.08, 0.7)


## Mur tout proche (devant, à gauche ou à droite) pendant qu'on tient un sbire par le col : lance la râpe à fromage.
func _grater_wall() -> bool:
	var f := -global_basis.z
	for d in [f, -global_basis.x, global_basis.x]:
		if _find_wall(d):
			var tan := wall_n.cross(Vector3.UP).normalized()
			if tan.dot(f) < 0.0:
				tan = -tan
			if absf(tan.dot(f)) < 0.2:   # mur droit devant : on part sur la droite
				tan = global_basis.x if global_basis.x.dot(tan) >= 0.0 else -global_basis.x
				tan = wall_n.cross(Vector3.UP).normalized() * signf(wall_n.cross(Vector3.UP).dot(tan))
			wall_tan = tan
			var right := tan.cross(Vector3.UP).normalized()   # à droite de la course
			start("cheese_grater_r" if wall_n.dot(right) < 0.0 else "cheese_grater")
			spark_t = 0.0
			hold_f = tan
			return true
	return false


## Mur tout proche à gauche ou à droite, à peu près parallèle à la direction du stick : course au mur horizontale.
func _side_wall(dir: Vector3) -> bool:
	var d := dir.normalized()
	var right := d.cross(Vector3.UP).normalized()
	for side in [right, -right]:
		if _find_wall(side) and absf(wall_n.dot(d)) < 0.5 and (wall_p - global_position).slide(Vector3.UP).length() < 1.3:
			wall_tan = (d - wall_n * wall_n.dot(d)).normalized()
			return true
	return false


## Course au mur horizontale : il court à l'horizontale le long du mur (en fauchant ceux qu'il croise), puis s'en repousse
## en coup de pied sauté vers la salle.
func _wall_run_h_tick(dt: float) -> void:
	var run_end: float = ATK.wall_run_h.active - 0.06
	if t < run_end:
		var on_wall := wall_p + (global_position - wall_p).slide(wall_n)
		var want := on_wall + wall_n * 0.8   # collé au mur, pieds dessus
		velocity.x = wall_tan.x * 9.5 + (want.x - global_position.x) * 10.0
		velocity.z = wall_tan.z * 9.5 + (want.z - global_position.z) * 10.0
		velocity.y = (0.75 - global_position.y) * 8.0 + GRAVITY * dt   # à mi-hauteur du mur
		wall_hit_t -= dt
		if wall_hit_t <= 0.0:
			wall_hit_t = 0.05
			for e in enemies:
				if e.parts.is_empty() or spin_hits.has(e) or e.state in ["held", "swung"]:
					continue
				var c: Vector3 = e.parts.chest.global_position
				if ((c - global_position) * Vector3(1, 0, 1)).length() < 1.15:
					spin_hits[e] = true
					e.hit(e.parts.chest, (wall_n * 0.8 + wall_tan * 0.6 + Vector3.UP * 0.4).normalized() * heavy_force * 0.7, c, 9.0, 1.0, true)
					connected = true
					_gain(6.0)
					get_parent().impact(0.05, 0.5)
	elif t - dt * attack_speed < run_end:
		rotation.y = atan2(-(wall_n.x + wall_tan.x * 0.4), -(wall_n.z + wall_tan.z * 0.4))   # il se tourne vers la salle
		velocity = wall_n * 6.5 + wall_tan * 2.5 + Vector3.UP * 4.0   # il se repousse du mur
		connected = false


## Super saut -> chope plongeante : le sbire le plus proche devant (au sol ou debout), dans un rayon raisonnable.
func _sj_pick() -> Node3D:
	var best: Node3D = null
	var bd := 7.0
	var look := stick_dir.normalized() if stick_dir.length() > 0.3 else -global_basis.z
	for e in enemies:
		if e.parts.is_empty() or e.state in ["held", "swung", "dead"]:
			continue
		var d: Vector3 = (e.parts.chest.global_position - global_position) * Vector3(1, 0, 1)
		var score := d.length() + look.angle_to(d) * 1.5
		if d.length() < 7.0 and score < bd:
			bd = score
			best = e
	return best


## Plongeon vers le sbire visé ; arrivé à portée de bras, il l'attrape et la chope plongeante prend le relais (plaqué au sol).
func _sj_grab_tick() -> void:
	if t < 0.08:
		velocity = velocity * 0.5   # un instant suspendu en se retournant
		return
	var to := Vector3.DOWN
	if sj_target and is_instance_valid(sj_target) and not sj_target.parts.is_empty() and not sj_target.state in ["held", "swung"]:
		var c: Vector3 = sj_target.parts.chest.global_position
		to = (c + Vector3.UP * 0.3) - (global_position + Vector3.UP * 1.0)
		var flat := to * Vector3(1, 0, 1)
		if flat.length() > 0.05:
			rotation.y = atan2(-flat.x, -flat.z)
		if to.length() < 1.2:
			enemy = sj_target
			sj_target.collar_grab()
			start("air_slam")
			velocity = Vector3.UP * 1.0
			get_parent().impact(0.06, 0.4)
			return
	velocity = to.normalized() * AIR_SLAM_SPEED

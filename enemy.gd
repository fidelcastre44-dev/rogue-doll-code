extends Node3D
## Ennemi : le sbire de base. Debout, son corps est cinématique et animé (garde, marche, coup) ; il tourne autour
## du joueur en gardant ses distances, puis vient frapper : il recule d'un pas en armant, s'élance, frappe, reste ouvert.
## Les coups le font vaciller ; quand son équilibre tombe à 0 il passe en ragdoll, est éjecté, puis se relève.

@export var eject := 5.0        # m/s, vitesse d'éjection quand il tombe
@export var sway := 1.0           # amplitude du vacillement debout
@export var stagger_mult := 1.0   # multiplie la perte d'équilibre des coups
@export var recovery := 0.8       # équilibre regagné par seconde
@export var uplift := 5.5         # m/s, décollage vertical des coups montants (uppercut) : règle la hauteur et la distance
@export var chaos := 1.0          # variété des chutes (0 = toujours la même)
@export var lift_speed := 1.4     # vitesse de ce vol (1 = flottant, plus = plus sec), sans changer la trajectoire
@export var max_chain := 3        # coups enchaînés au plus par série
@export var attack_pause := 0.4   # s, pause moyenne entre deux séries
@export var block_chance := 0.5   # chance qu'il lève la garde quand tu lances un coup devant lui
@export var bounce := 11.0        # m/s, rebond après la chope (hauteur du jongle qui suit)
@export var ground_bounce := 0.6  # rebond exagéré de tout corps qui s'écrase au sol (part de la vitesse de chute rendue vers le haut)
@export var air_pop := 6.5        # m/s, chaque coup en l'air le remonte de ça (un peu moins à chaque coup)
@export var trip_spin := 7.0       # rad/s, bascule quand le balayage lui fauche les jambes
@export var spike_speed := 14.0    # m/s vers le sol quand le marteau l'écrase
@export var crisp_time := 0.12    # s, il se crispe (figé, tendu, qui tremble) quand on le touche en l'air...
@export var spin := 11.0          # rad/s, ... puis repart en tournoyant
@export var jolt := 9.0           # m/s, secousse du corps touché en l'air (il plie autour du coup, sans changer de trajectoire)

const COLOR := Color(0.85, 0.3, 0.25)
const BOUNCE_MIN := 6.0  # m/s : en dessous, il ne rebondit plus (il se pose)
const DOWN_TIME := 1.5   # secondes au sol avant de se relever
const REACT := 0.07      # secondes de réaction "normale" avant que le ragdoll prenne le relais
const STUN := 0.4       # secondes sans récupération d'équilibre après chaque coup
const RESPAWN := 5.0     # secondes après la mort avant reset : on peut encore taper le corps pendant ce temps
const RESPAWN_KEEP := 1.5  # chaque coup sur le corps lui laisse au moins ce temps avant de disparaître
const KEEP := 1.8        # distance qu'il garde en tournant autour du joueur (chaque sbire a la sienne, autour de ça)
const MAX_ATTACKERS := 2 # en groupe : au plus 2 sbires attaquent en même temps, les autres tournent autour (sinon injouable)
const GROUP_GAP := 1.4   # en groupe : une nouvelle série d'attaque ne démarre qu'au moins ce temps après la précédente (tous sbires confondus)
const SPACING := 1.4     # les sbires s'écartent les uns des autres en dessous de cette distance
const RAGDOLL_LAYER := 8 # couche des corps en ragdoll : ils ne poussent plus le joueur
const REACH := 1.15      # distance à laquelle il commence à armer son coup
const WINDUP := 0.38     # armé : il recule d'un pas, bras en arrière (c'est ce qui prévient le joueur)
const WINDUP_CHAIN := 0.24  # armé des coups enchaînés (et de la contre-attaque après sa garde) : plus court, sans recul
const STRIKE := 0.14     # il s'élance et frappe
const RECOVER := 0.4     # bras qui revient : il est ouvert
const RECOVER_CHAIN := 0.1  # entre deux coups d'une série
const PUNCH_DMG := 12.0
const LAND_BLEND := 0.18  # lancé par un uppercut : il se rattrape en l'air en ce temps-là, juste avant de toucher le sol
const LANDED := 0.45      # puis reste accroupi, vulnérable
const LAND_DROP := 0.18   # de combien le bassin descend quand il est accroupi
const GATHER := 0.3       # relevé en roulade : il se ramasse en boule...
const ROLL := 0.45        # ... fait une roulade arrière...
const RISE := 0.25        # ... et se relève en garde
const UP_SPEED := 3.0     # v0.214 : relevé capturé (CMU), joué 3× plus vite que la capture (remplace boule + roulade arrière)
const UP_BLEND := 0.22    # passage du ragdoll au début du relevé capturé
const BALL_R := 0.38      # rayon de la boule qu'il forme en roulade
const TUCK_CENTER := Vector3(0, 1.05, 0.18)   # centre de cette boule, dans son repère debout
const MAX_JUGGLES := 3    # coups en l'air avant qu'il s'écrase pour de bon
const BLOCK_RANGE := 2.2  # il ne lève la garde que si tu frappes à cette distance, devant lui
const BLOCK_HOLD := 0.45  # il garde la garde ce temps-là après ton dernier coup, puis contre-attaque
const BLOCK_RAISE := 0.06 # temps pour monter la garde (visuel ; la garde protège dès qu'il la lève)
const HELD_MAX := 1.2     # sécurité : tenu plus longtemps que ça, il est relâché
const LOCK := 0.12       # il fige sa direction ce temps-là avant de frapper (au-delà, il te suit)
const HIT_FROM := 0.05   # fenêtre active du coup, dans la frappe
const HIT_TO := 0.13
const HIT_RADIUS := 0.4  # épaisseur de la zone de frappe (le bras fait 0.09)
const HIT_EXTRA := 0.25  # la zone dépasse le poing de cette longueur
# Terrain (v0.212, carte de test) : il suit le sol (escalier, rampe), ne monte pas plus haut qu'une marche, ne se jette pas dans le vide,
# contourne ce qui est trop haut ; un corps qui tombe de haut prend des dégâts.
const STEP_UP := 0.45     # m : il monte une marche, une rampe ; plus haut = obstacle
const LEDGE_DROP := 0.7   # m : plus bas = le vide (il s'arrête au bord, sauf s'il est poussé)
const FALL_HURT := 1.0    # m de dénivelé (sol de départ -> sol d'arrivée) au-delà duquel la chute fait mal
const FALL_DMG := 7.0     # dégâts par mètre de chute (un rebond sur place ne compte pas : seul le sol perdu compte)
# v0.218 (bilans de Thibaud)
const RAG_GRAV := 3.0       # gravité des corps qui tombent (était 2,5) : plus lourds, moins flottants
const RAG_ANG_DAMP := 1.2   # les corps en ragdoll tournoient moins longtemps
const REACT_T := 0.28       # réaction au coup d'un sbire debout (tête et buste qui partent, bras qui lâchent)
const IMPACT_SPEED := 6.0   # m/s : lancé par une chope, il se fait mal en percutant le décor, un objet ou un sbire au-delà de cette vitesse
const IMPACT_DMG := 9.0     # dégâts de ce choc (et pour le sbire percuté)

# Poses en degrés, par articulation (rotation par rapport au parent). L'ennemi regarde vers +Z :
# bras/jambes, x négatif = vers l'avant ; buste/tête, x positif = penché en avant ; buste, y négatif = côté du bras qui frappe vers l'arrière.
# Toutes les valeurs restent dans les limites des articulations : le passage en ragdoll se fait sans à-coup.
const E_POSES := {
	"guard": {"chest": Vector3(8, 0, 0), "head": Vector3(-6, 0, 0), "arm_l": Vector3(-45, 0, 15), "fore_l": Vector3(-110, 0, 0), "arm_r": Vector3(-50, 0, -15), "fore_r": Vector3(-115, 0, 0)},
	"windup": {"chest": Vector3(-8, -25, 0), "head": Vector3(4, 20, 0), "arm_l": Vector3(25, 0, 25), "fore_l": Vector3(-130, 0, 0), "arm_r": Vector3(-55, 0, -20), "fore_r": Vector3(-120, 0, 0)},
	"tuck": {"chest": Vector3(30, 0, 0), "head": Vector3(35, 0, 0), "arm_l": Vector3(-60, 0, 20), "fore_l": Vector3(-125, 0, 0), "arm_r": Vector3(-60, 0, -20), "fore_r": Vector3(-125, 0, 0),
		"thigh_l": Vector3(-100, 0, 0), "shin_l": Vector3(130, 0, 0), "thigh_r": Vector3(-100, 0, 0), "shin_r": Vector3(130, 0, 0)},
	"land": {"chest": Vector3(22, 0, 0), "head": Vector3(-10, 0, 0), "arm_l": Vector3(-30, 0, 35), "fore_l": Vector3(-90, 0, 0), "arm_r": Vector3(-30, 0, -35), "fore_r": Vector3(-90, 0, 0),
		"thigh_l": Vector3(-40, 0, 0), "shin_l": Vector3(70, 0, 0), "thigh_r": Vector3(-40, 0, 0), "shin_r": Vector3(70, 0, 0)},
	# Sonné (parade du joueur) : buste renversé, tête en arrière, bras ballants.
	"stunned": {"chest": Vector3(-18, 0, 0), "head": Vector3(-28, 0, 0), "arm_l": Vector3(5, 0, 30), "fore_l": Vector3(-25, 0, 0), "arm_r": Vector3(8, 0, -30), "fore_r": Vector3(-20, 0, 0),
		"thigh_l": Vector3(-18, 0, 0), "shin_l": Vector3(28, 0, 0), "thigh_r": Vector3(-10, 0, 0), "shin_r": Vector3(18, 0, 0)},
	# Garde haute : avant-bras croisés devant le visage, buste et tête rentrés.
	"block": {"chest": Vector3(18, 0, 0), "head": Vector3(16, 0, 0), "arm_l": Vector3(-78, 0, 28), "fore_l": Vector3(-128, 0, 0), "arm_r": Vector3(-74, 0, -28), "fore_r": Vector3(-132, 0, 0),
		"thigh_l": Vector3(-14, 0, 0), "shin_l": Vector3(22, 0, 0), "thigh_r": Vector3(-14, 0, 0), "shin_r": Vector3(22, 0, 0)},
	# Tenu par le col : sonné, bras et jambes qui pendent.
	"collar": {"chest": Vector3(-6, 0, 0), "head": Vector3(-12, 0, 0), "arm_l": Vector3(-10, 0, -22), "fore_l": Vector3(-35, 0, 0), "arm_r": Vector3(-8, 0, 22), "fore_r": Vector3(-30, 0, 0),
		"thigh_l": Vector3(-25, 0, 0), "shin_l": Vector3(55, 0, 0), "thigh_r": Vector3(-15, 0, 0), "shin_r": Vector3(45, 0, 0)},
	# Grand tour : tout le corps tendu par la force, bras vers le joueur.
	"swung": {"chest": Vector3(0, 0, 0), "head": Vector3(-12, 0, 0), "arm_l": Vector3(-85, 0, -18), "fore_l": Vector3(-5, 0, 0), "arm_r": Vector3(-85, 0, 18), "fore_r": Vector3(-5, 0, 0),
		"thigh_l": Vector3(0, 0, -8), "shin_l": Vector3(0, 0, 0), "thigh_r": Vector3(0, 0, 8), "shin_r": Vector3(0, 0, 0)},
	# Tenu par le joueur : bras et jambes ballants qui gigotent.
	"held": {"chest": Vector3(-10, 0, 0), "head": Vector3(-20, 0, 0), "arm_l": Vector3(-40, 0, -50), "fore_l": Vector3(-40, 0, 0), "arm_r": Vector3(-40, 0, 50), "fore_r": Vector3(-40, 0, 0),
		"thigh_l": Vector3(-30, 0, 0), "shin_l": Vector3(40, 0, 0), "thigh_r": Vector3(-20, 0, 0), "shin_r": Vector3(50, 0, 0)},
	# Crispé : touché en l'air, tout le corps se contracte en boule.
	"crisp": {"chest": Vector3(28, 0, 0), "head": Vector3(32, 0, 0), "arm_l": Vector3(-70, 0, 35), "fore_l": Vector3(-135, 0, 0), "arm_r": Vector3(-70, 0, -35), "fore_r": Vector3(-135, 0, 0),
		"thigh_l": Vector3(-75, 0, 0), "shin_l": Vector3(105, 0, 0), "thigh_r": Vector3(-65, 0, 0), "shin_r": Vector3(115, 0, 0)},
	"strike": {"chest": Vector3(14, 25, 0), "head": Vector3(-6, -20, 0), "arm_l": Vector3(-88, 0, 8), "fore_l": Vector3(-3, 0, 0), "arm_r": Vector3(-40, 0, -25), "fore_r": Vector3(-125, 0, 0)},
}

# nom, parent, taille (rayon en x pour la tête), centre, ancre du joint, masse, limites min/max (degrés)
# Construit dans la pose debout : les rotations relatives au repos sont l'identité.
const BODY := [
	["pelvis", "", Vector3(0.32, 0.2, 0.2), Vector3(0, 1.0, 0), Vector3.ZERO, 10.0, Vector3.ZERO, Vector3.ZERO],
	["chest", "pelvis", Vector3(0.38, 0.42, 0.22), Vector3(0, 1.33, 0), Vector3(0, 1.1, 0), 12.0, Vector3(-30, -30, -20), Vector3(30, 30, 20)],
	["head", "chest", Vector3(0.13, 0, 0), Vector3(0, 1.7, 0), Vector3(0, 1.56, 0), 4.0, Vector3(-40, -60, -30), Vector3(40, 60, 30)],
	["arm_l", "chest", Vector3(0.1, 0.3, 0.1), Vector3(-0.26, 1.38, 0), Vector3(-0.26, 1.53, 0), 3.0, Vector3(-90, -60, -90), Vector3(90, 60, 90)],
	["fore_l", "arm_l", Vector3(0.09, 0.28, 0.09), Vector3(-0.26, 1.08, 0), Vector3(-0.26, 1.23, 0), 2.0, Vector3(-140, -5, -5), Vector3(0, 5, 5)],
	["arm_r", "chest", Vector3(0.1, 0.3, 0.1), Vector3(0.26, 1.38, 0), Vector3(0.26, 1.53, 0), 3.0, Vector3(-90, -60, -90), Vector3(90, 60, 90)],
	["fore_r", "arm_r", Vector3(0.09, 0.28, 0.09), Vector3(0.26, 1.08, 0), Vector3(0.26, 1.23, 0), 2.0, Vector3(-140, -5, -5), Vector3(0, 5, 5)],
	["thigh_l", "pelvis", Vector3(0.13, 0.42, 0.13), Vector3(-0.1, 0.69, 0), Vector3(-0.1, 0.9, 0), 7.0, Vector3(-100, -30, -30), Vector3(30, 30, 30)],
	["shin_l", "thigh_l", Vector3(0.11, 0.45, 0.11), Vector3(-0.1, 0.225, 0), Vector3(-0.1, 0.47, 0), 4.0, Vector3(0, -5, -5), Vector3(140, 5, 5)],
	["thigh_r", "pelvis", Vector3(0.13, 0.42, 0.13), Vector3(0.1, 0.69, 0), Vector3(0.1, 0.9, 0), 7.0, Vector3(-100, -30, -30), Vector3(30, 30, 30)],
	["shin_r", "thigh_r", Vector3(0.11, 0.45, 0.11), Vector3(0.1, 0.225, 0), Vector3(0.1, 0.47, 0), 4.0, Vector3(0, -5, -5), Vector3(140, 5, 5)],
]

var target: Node3D   # vers qui il se tourne (le joueur)
const MAX_HP := 70.0      # vie d'un sbire
var hp := MAX_HP
var poise := 1.0     # équilibre : à 0 il tombe
var state := "stand" # stand / down / getup / dead
var timer := 0.0
var root := Transform3D()   # pose debout : origine = entre les pieds, au sol
var lean := Vector3.ZERO    # vacillement (vecteur rotation autour des pieds)
var lean_v := Vector3.ZERO
var slide := Vector3.ZERO
var quake := 0.0            # secondes (temps réel) de vibration restante
var launch_dir := Vector3.ZERO
var launch_strength := 0.0
var launch_up := 0.0      # part verticale du coup (uppercut)
var getup_from := {}
var can_respawn := true   # false en partie : un sbire mort reste mort (son corps reste là)
var ai_on := true    # false = sac de frappe immobile (tests)
var ai := "circle"   # circle / windup / strike / recover
var ai_t := 0.0
var stun_len := 0.0   # sonné (parade) : durée
var cooldown := 2.0  # avant sa prochaine attaque
var strafe := 1.0    # sens dans lequel il tourne autour du joueur
var strafe_t := 2.0
var walk_phase := 0.0
var gait_v := 0.0          # vitesse au sol (m/s) : marche ou course capturées, rythme des pas
var gait_yaw := 0.0        # direction du déplacement par rapport à son buste (pas de côté)
var gait_back := false
var gait_w := 0.0          # poids des jambes de la marche (monte et descend en douceur)
var up_clip := []          # relevé capturé en cours (à plat ventre ou sur le dos)
var punched := false
var lunge := 0.6      # distance de son élan, calculée au début de la frappe
var anim := {}       # pose courante (degrés par articulation)
var rest_center := {}
var air_recover := false   # lancé sans être KO : il se rattrapera sur ses pieds, sauf si on le retouche en l'air
var juggles := 0
var drop := 0.0            # bassin abaissé (accroupi après réception)
var blend_kind := ""       # "land" ou "gather" : vers quoi on passe du ragdoll à l'animation
var blend_len := 0.3
var blend_x := Transform3D()
var blend_anim := {}
var roll_start := Vector3.ZERO
var rise_from := Transform3D()
var seen_attack := 0       # dernier coup du joueur auquel il a réagi
var block_t := 0.0         # temps de garde restant
var windup_pose := {}      # pose de départ de l'armé (garde, garde haute, fin du coup précédent)
var windup_len := WINDUP
var chain_left := 0        # coups qui restent dans la série en cours
var held_t := 0.0
static var group_ready := 0.0   # instant (temps de jeu) à partir duquel le groupe peut lancer une nouvelle série
var keep := KEEP           # distance à laquelle ce sbire tourne autour du joueur
var bar: MeshInstance3D    # barre de vie au-dessus de la tête
var bar_bg: MeshInstance3D
var swing_victims := {}
var fall_vy := 0.0          # vitesse de chute à l'image précédente (rebond au sol)
var bounce_cd := 0.0
var land_bounce := 0.0     # coup de tête : il rebondit en touchant le sol (vitesse de rebond)
var land_dmg := 0.0        # grand tour : dégâts pris quand il s'écrase au sol (pas au lâcher)
var land_t := 0.0
var projectile_t := 0.0   # lancé : son corps percute les autres sbires pendant le vol    # grand tour : ennemis déjà percutés pendant ce tour
var corpse := false        # déjà mort une fois (le délai avant disparition ne repart pas à zéro)
var held_blend := 0.0      # chope au sol : temps pour le relever du ragdoll jusqu'à la main du joueur
var held_pose := "held"
var held_hit := 0.0        # tête et buste qui partent en arrière sous un coup, pendant qu'il est tenu
var crisp_v := Vector3.ZERO      # vitesse qu'il reprendra en se détendant
var crisp_x := Transform3D()     # repère du corps pendant la crispation
var crisp_axis := Vector3.RIGHT  # axe de la vrille qui suit
var crisp_part: RigidBody3D
var crisp_imp := Vector3.ZERO
var crisp_point := Vector3.ZERO
var parts := {}
var parent_of := {}
var nodes := []
var mat := StandardMaterial3D.new()
var detour := 0.0          # contournement en cours (+1 / -1), gardé un moment
var detour_t := 0.0
var fall_hurt_last := 0.0  # dégâts de la dernière chute (tests)
var fall_g0 := INF         # sol le plus haut depuis le dernier contact (chute du haut d'un rebord)
# États (v0.212) : nom -> temps restant. "elec" = électrifié (il convulse, tombe, prend des dégâts) ; "elec_chain" = il électrifie
# bientôt ses voisins (électrification de zone). Prévu pour d'autres états plus tard (feu, gel…).
var status := {}
const ELEC_DPS := 6.0
const ELEC_SPREAD := 3.0   # m : électrification de zone
var knockdown := false       # v0.218 : le prochain envol ne se rattrape pas sur ses pieds (uppercut de fin de combo)
var react_t := -1.0          # v0.218 : réaction au coup (debout), temps écoulé ; -1 = aucune
var react_dir := Vector3.ZERO  # d'où vient le coup (repère monde)
var react_side := 1.0
var impact_t := 0.0          # v0.218 : lancé par une chope, il percute ce qu'il touche (temps restant)
var impact_hits := {}        # ce qu'il a déjà percuté pendant ce vol
var impact_count := 0        # (tests) chocs pris
var last_good := Vector3.ZERO  # dernier point debout valable (secours si un corps coincé donne des positions infinies)
var weapon: Node3D = null   # arme tenue (bâton) : la parade + X la lui arrache (désarmer)


func _ready() -> void:
	add_to_group("enemies")
	build()


func build() -> void:
	for n in nodes:
		n.queue_free()
	nodes.clear()
	parts.clear()
	parent_of.clear()
	hp = MAX_HP
	poise = 1.0
	corpse = false
	land_dmg = 0.0
	land_bounce = 0.0
	fall_vy = 0.0
	projectile_t = 0.0
	state = "stand"
	timer = 0.0
	fall_g0 = INF
	status.clear()
	weapon = null
	mat.emission_enabled = false
	lean = Vector3.ZERO
	lean_v = Vector3.ZERO
	slide = Vector3.ZERO
	root = global_transform
	ai = "circle"
	cooldown = randf_range(1.0, 1.4) + randf_range(0.0, 1.5) * float(get_tree().get_nodes_in_group("enemies").size() > 1)
	keep = KEEP + randf_range(0.0, 1.4) * float(get_tree().get_nodes_in_group("enemies").size() > 1)
	anim = E_POSES.guard.duplicate()
	if target:
		seen_attack = target.attack_id
	mat.albedo_color = COLOR
	for d in BODY:
		var b := RigidBody3D.new()
		b.mass = d[5]
		b.can_sleep = false
		b.continuous_cd = true   # v0.218 : un corps lancé vite ne traverse plus les murs ni les objets
		b.angular_damp = RAG_ANG_DAMP   # v0.218 (Thibaud) : corps plus lourds, moins « volants »
		b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		b.freeze = true
		b.collision_layer = 2
		b.collision_mask = 1 | 4   # shortcut: pas de collision entre membres ni entre ennemis, à revoir quand il y aura plusieurs ennemis
		var cs := CollisionShape3D.new()
		var mi := MeshInstance3D.new()
		if d[0] == "head":
			cs.shape = SphereShape3D.new()
			cs.shape.radius = d[2].x
			mi.mesh = SphereMesh.new()
			mi.mesh.radius = d[2].x
			mi.mesh.height = d[2].x * 2
		else:
			cs.shape = BoxShape3D.new()
			cs.shape.size = d[2]
			mi.mesh = BoxMesh.new()
			mi.mesh.size = d[2]
		mi.material_override = mat
		b.add_child(cs)
		b.add_child(mi)
		b.position = d[3]
		rest_center[d[0]] = d[3]
		add_child(b)
		nodes.append(b)
		parts[d[0]] = b
		if d[1] == "":
			continue
		var j := Generic6DOFJoint3D.new()
		j.position = d[4]
		add_child(j)
		nodes.append(j)
		j.node_a = j.get_path_to(parts[d[1]])
		j.node_b = j.get_path_to(b)
		# Le joint mesure la rotation dans le sens inverse de nos poses : on inverse les bornes.
		var lo: Vector3 = -d[7] * (PI / 180)
		var hi: Vector3 = -d[6] * (PI / 180)
		j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo.x)
		j.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi.x)
		j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo.y)
		j.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi.y)
		j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, lo.z)
		j.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, hi.z)
		parent_of[d[0]] = parts[d[1]]


func _physics_process(dt: float) -> void:
	if not parts.is_empty() and (not root.origin.is_finite() or not parts.pelvis.global_position.is_finite()):
		_rescue()   # v0.218 : sécurité, ne doit plus arriver
	_sync_layer()
	if impact_t > 0.0:
		_impact_tick(dt)
	if not status.is_empty():
		_status_tick(dt)
	match state:
		"crisp":   # figé et tendu une fraction de seconde (il dérive à peine), puis il se détend en tournoyant
			timer += dt
			crisp_x.origin += crisp_v * 0.2 * dt
			var j := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.035
			blend_x = Transform3D(crisp_x.basis, crisp_x.origin + j)
			blend_anim = {}
			for n in E_POSES.crisp:
				blend_anim[n] = E_POSES.crisp[n] + Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-3, 3))   # muscles qui tremblent
			_getup_pose(minf(timer / 0.03, 1.0))
			if timer >= crisp_time:
				_release_crisp()
		"swung":   # grand tour : tenu par les chevilles (cinématiques), le reste du corps est en ragdoll
			if held_t > 30.0:
				swing_release(parts.pelvis.global_position, Vector3.ZERO, 0.0)   # sécurité
		"held":   # c'est le joueur qui le place (hold), puis le fracasse au sol (slam) ou le relâche (toss)
			held_t += dt
			held_hit = maxf(held_hit - dt, 0.0)
			if held_t > (HELD_MAX if held_pose == "held" else 6.0):
				toss(Vector3.UP, 0.0)   # sécurité : le joueur ne le tient plus
		"down", "dead":
			_terrain_fall()
			if bowl_t >= 0.0:
				_bowl_tick(dt)
			if land_dmg > 0:
				_land_hit(dt)
			if land_bounce > 0:
				_bounce()
			else:
				_ground_bounce(dt)
			if projectile_t > 0:
				projectile_t -= dt
				if parts.pelvis.linear_velocity.length() > 4.0:
					_swing_sweep()
			if state == "dead":
				timer += dt
				if timer > RESPAWN and can_respawn:
					_respawn()
				return
			var pel: RigidBody3D = parts.pelvis
			if air_recover and pel.linear_velocity.y < 0 and height_above(pel.global_position) < 1.15:
				_start_blend("land")   # il redescend : il se rattrape avant de toucher le sol
			elif height_above(pel.global_position) < 0.4 or pel.linear_velocity.length() < 0.4:   # le temps au sol ne compte qu'une fois retombé (ou posé sur un objet : table, chaise…)
				timer -= dt
			if state == "down" and timer <= 0:
				_start_getup()
		"getup":   # du ragdoll vers une pose animée (réception sur ses pieds, ou boule avant la roulade)
			timer += dt
			_getup_pose(minf(timer / blend_len, 1.0))
			if timer >= blend_len:
				timer = 0.0
				if blend_kind == "land":
					state = "stand"
					ai = "landed"
					ai_t = 0.0
					poise = 1.0
					drop = LAND_DROP
					anim = E_POSES.land.duplicate()
				elif blend_kind == "mup":
					state = "rise"
					rise_from = Transform3D()
				else:
					state = "techroll"
		"techroll":   # roulade arrière : la boule roule sans glisser en s'éloignant du joueur
			timer += dt
			var u := smoothstep(0.0, 1.0, minf(timer / ROLL, 1.0))
			anim = E_POSES.tuck.duplicate()
			_fk(_roll_x(lerpf(-90.0, -360.0, u)))
			if timer >= ROLL:
				state = "rise"
				timer = 0.0
				rise_from = _roll_x(-360.0)
		"rise":
			timer += dt
			if not up_clip.is_empty() and rise_from == Transform3D():   # relevé capturé
				var len := (CycleData.GETUP_FRONT_PERIOD if up_clip == E_UP_FRONT else CycleData.GETUP_BACK_PERIOD) / UP_SPEED
				var k := minf(timer / len, 1.0)
				anim = _clip_e(up_clip, k)
				if k > 0.85:   # fin : il se remet en garde
					var gw := smoothstep(0.85, 1.0, k)
					for n in E_POSES.guard:
						anim[n] = anim.get(n, Vector3.ZERO).lerp(E_POSES.guard[n], gw)
				_fk(root)
				if k >= 1.0:
					up_clip = []
					state = "stand"
					ai = "circle"
					cooldown = _pause()
					anim = E_POSES.guard.duplicate()
					_pose()
				return
			var u := smoothstep(0.0, 1.0, minf(timer / RISE, 1.0))
			anim = _blend(E_POSES.tuck, E_POSES.guard, u)
			var stand := Transform3D(root.basis, _roll_origin(-360.0))
			_fk(rise_from.interpolate_with(stand, u))
			if timer >= RISE:
				root = stand
				state = "stand"
				ai = "circle"
				cooldown = _pause()
				anim = E_POSES.guard.duplicate()
		"stand":
			fall_g0 = root.origin.y   # le sol sur lequel il se tient (s'il est poussé dans le vide, la chute part d'ici)
			if root.origin.is_finite():
				last_good = root.origin
			if react_t >= 0.0:
				react_t += dt
				if react_t > REACT_T:
					react_t = -1.0
			timer -= dt
			if timer <= 0:
				poise = minf(poise + recovery * dt, 1.0)
			if target and (ai_on or ai in ["landed", "block", "stunned"]):
				_ai(dt)
			_sway_step(dt)
		"launch":   # il joue la réaction au coup sans ressort de retour (il part), puis le ragdoll prend le relais
			lean += lean_v * dt
			if ground_y(root.origin + slide * dt, STEP_UP) != INF:
				root.origin += slide * dt   # v0.218 : jamais poussé dans un mur ou un bloc (il en ressortait en ragdoll coincé)
			_pose()
			timer -= dt
			if timer <= 0:
				_launch()


func _sway_step(dt: float) -> void:
	lean_v += (-lean * 260.0 - lean_v * 18.6) * dt   # ressort ~2.6 Hz, un peu sous-amorti : il oscille avant de se poser
	lean += lean_v * dt
	_walk(slide * dt, true)
	slide *= exp(-10.0 * dt)
	_pose()


## Vibration pendant le hitstop : tourne en temps réel, même quand le jeu est quasi gelé.
func _process(dt: float) -> void:
	_update_bar()
	if quake <= 0 or not state in ["stand", "launch"]:
		return
	quake -= dt / maxf(Engine.time_scale, 0.001)
	_pose(Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * 0.05 * maxf(quake, 0.0) / 0.1)


## Le sbire : il tourne autour du joueur à distance, puis vient frapper. Touché pendant qu'il arme, il est interrompu.
func _ai(dt: float) -> void:
	var to := target.global_position - root.origin
	to.y = 0
	var dist := to.length()
	var dirn := to / maxf(dist, 0.001)
	var fwd := root.basis.z
	var vel := Vector3.ZERO
	var face := true
	ai_t += dt
	# Il voit partir tes coups : s'il est en garde il la garde, sinon il a une chance de la lever (pas s'il est sonné ou ouvert).
	if target.attack_id != seen_attack:
		seen_attack = target.attack_id
		if not target.attack in ["grab", "slam"]:
			if ai == "block":
				block_t = BLOCK_HOLD
			elif ai == "circle" and timer <= 0 and dist < BLOCK_RANGE and fwd.dot(dirn) > 0.5 and randf() < block_chance:
				ai = "block"
				ai_t = 0.0
				block_t = BLOCK_HOLD
	match ai:
		"circle":
			cooldown -= dt
			strafe_t -= dt
			if strafe_t < 0:
				strafe = -strafe
				strafe_t = randf_range(1.2, 2.8)
			vel = dirn * clampf(dist - keep, -1.0, 1.0) * 2.0 + Vector3.UP.cross(dirn) * strafe * 1.4
			if cooldown <= 0 and (_attackers() >= MAX_ATTACKERS or _now() < group_ready):
				cooldown = _pause()   # trop de monde sur le joueur : il repart tourner (pas de file d'attente qui attaque en continu)
			if cooldown <= 0:
				vel = dirn * 4.0   # il fonce sur toi
				if dist <= REACH + 0.3:
					chain_left = _series()
					_claim_series()
					_start_windup(WINDUP)
		"block":   # garde haute : il encaisse sans rien perdre, puis contre-attaque dès que tu arrêtes
			block_t -= dt
			if block_t <= 0:
				if dist <= REACH + 0.6 and _attackers() < MAX_ATTACKERS:
					chain_left = _series()
					_claim_series()
					_start_windup(WINDUP_CHAIN)   # contre-attaque sèche
				else:
					ai = "circle"
					cooldown = 0.0
					ai_t = 0.0
		"windup":
			if windup_len >= WINDUP:
				vel = -dirn * 0.5   # premier coup d'une série : petit pas en arrière pendant qu'il arme
			face = ai_t < windup_len - LOCK   # il te suit pendant l'armé, puis verrouille sa direction juste avant de frapper
			if ai_t >= windup_len:
				ai = "strike"
				ai_t = 0.0
				punched = false
				lunge = clampf(dist - 0.95, 0.15, 1.1)   # son élan comble l'écart (dans la limite d'un grand pas)
		"strike":
			face = false
			vel = fwd * (2.0 * lunge / STRIKE) * (1.0 - ai_t / STRIKE)   # parcourt exactement `lunge` mètres sur STRIKE
			if not punched and ai_t >= HIT_FROM and ai_t <= HIT_TO:   # coup actif sur plusieurs images, pas une seule
				punched = _punch()
			if ai_t >= STRIKE:
				ai = "recover"
				ai_t = 0.0
		"stunned":   # parade du joueur : sonné, grand ouvert
			face = false
			if ai_t >= stun_len:
				ai = "circle"
				cooldown = _pause()
		"landed":   # accroupi après la réception : ouvert, il ne bouge pas
			if ai_t >= LANDED:
				ai = "circle"
				cooldown = _pause() * 0.5
		"recover":
			face = false
			if chain_left > 0 and ai_t >= RECOVER_CHAIN:
				chain_left -= 1
				if dist <= REACH + 0.8:
					_start_windup(WINDUP_CHAIN)   # coup suivant de la série
				else:
					chain_left = 0
			if ai == "recover" and ai_t >= RECOVER:
				ai = "circle"
				cooldown = _pause()
	if timer > 0:   # sonné par un coup : il ne bouge plus
		vel = Vector3.ZERO
	vel += _separation()
	if dist < 0.8 and vel.dot(dirn) > 0:
		vel -= dirn * vel.dot(dirn)   # il ne rentre pas dans le joueur
	_walk(vel * dt)
	if face:
		root.basis = root.basis.slerp(Basis(Vector3.UP, atan2(to.x, to.z)), 1.0 - exp(-(10.0 if ai == "windup" else 6.0) * dt))
	var moving := clampf(vel.length() / 1.5, 0.0, 1.0)
	gait_v = vel.length()
	var lv := root.basis.inverse() * vel
	gait_back = lv.z < -0.3 * gait_v   # il recule : le cycle se joue à l'envers
	var ang := atan2(lv.x, lv.z if not gait_back else -lv.z)
	gait_yaw = lerp_angle(gait_yaw, clampf(ang, -1.4, 1.4), 1.0 - exp(-10.0 * dt))
	walk_phase += dt * TAU * gait_v / _stride() * (-1.0 if gait_back else 1.0)   # marche capturée (CMU) : une foulée par tour de phase
	anim = _anim_pose(moving)


## Sbires en train d'attaquer le joueur (armé, frappe, ou série en cours), sans compter celui-ci.
func _attackers() -> int:
	var n := 0
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self and o.state == "stand" and (o.ai in ["windup", "strike"] or (o.ai == "recover" and o.chain_left > 0)):
			n += 1
	return n


## Les sbires debout s'écartent les uns des autres au lieu de s'empiler.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or o.state != "stand":
			continue
		var d: Vector3 = (root.origin - o.root.origin) * Vector3(1, 0, 1)
		var l := d.length()
		if l < SPACING:
			push += (d / maxf(l, 0.01) if l > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()) * (SPACING - l) * 6.0
	return push


## Debout (cinématique) : couche 2, il bloque le joueur. En ragdoll : couche à part, il ne le pousse plus. Tenu : aucune.
func _sync_layer() -> void:
	if parts.is_empty():
		return
	var want := 0 if state in ["held", "swung"] else (2 if state == "stand" else RAGDOLL_LAYER)
	if parts.pelvis.collision_layer != want:
		for b in parts.values():
			b.collision_layer = want


## Mort depuis un moment : il réapparaît au bord de l'arène, loin du joueur.
func _respawn() -> void:
	if target:
		var a := randf() * TAU
		var p: Vector3 = target.global_position + Vector3(cos(a), 0, sin(a)) * 7.0
		global_position = Vector3(clampf(p.x, -40, 40), 0, clampf(p.z, -40, 40))
	build()


## Barre de vie flottante au-dessus de la tête (cachée une fois mort).
func _update_bar() -> void:
	if parts.is_empty():
		return
	if bar == null or not is_instance_valid(bar):
		bar_bg = _make_bar(Color(0.15, 0.15, 0.15), 0.0)
		bar = _make_bar(Color(0.95, 0.3, 0.25), 0.001)
	var top: Vector3 = parts.head.global_position + Vector3.UP * 0.35
	bar_bg.visible = state != "dead"
	bar.visible = state != "dead"
	bar_bg.global_position = top
	var cam := get_viewport().get_camera_3d()
	var right: Vector3 = cam.global_basis.x if cam else Vector3.RIGHT
	bar.global_position = top - right * 0.35 + (cam.global_basis.z * 0.01 if cam else Vector3.ZERO)   # ancrée à gauche : elle se vide vers la gauche
	bar.scale = Vector3(maxf(hp / MAX_HP, 0.001), 1, 1)


func _make_bar(c: Color, _z: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = QuadMesh.new()
	m.mesh.size = Vector2(0.7, 0.07)
	if _z > 0:
		m.mesh.center_offset = Vector3(0.35, 0, 0)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mt.billboard_keep_scale = true
	mt.albedo_color = c
	mt.render_priority = 1 if _z > 0 else 0
	mt.no_depth_test = true
	m.material_override = mt
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _start_windup(len: float) -> void:
	ai = "windup"
	ai_t = 0.0
	windup_len = len
	windup_pose = anim.duplicate()   # il part de la pose où il est : pas de saut dans l'animation


## Coups supplémentaires dans la série : le plus souvent il enchaîne.
func _series() -> int:
	var most := int(max_chain) if _crowd() <= 1 else mini(int(max_chain), 2)   # en groupe : séries de 2 coups au plus
	if most <= 1 or randf() < 0.2:
		return 0
	return randi_range(1, most - 1)


func _crowd() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


## Il lance une série : en groupe, les autres attendront GROUP_GAP avant d'en lancer une.
func _claim_series() -> void:
	if _crowd() > 1:
		group_ready = _now() + GROUP_GAP


func _pause() -> float:
	var crowd := get_tree().get_nodes_in_group("enemies").size()
	return attack_pause * randf_range(0.5, 1.5) * (1.0 + 0.35 * (crowd - 1))   # en groupe, chacun attend plus longtemps entre ses séries


func _anim_pose(moving: float) -> Dictionary:
	var a: Dictionary = E_POSES.guard.duplicate()
	match ai:
		"block":
			a = _blend(E_POSES.guard, E_POSES.block, 1.0 - pow(1.0 - minf(ai_t / BLOCK_RAISE, 1.0), 2.0))
		"windup":
			a = _blend(windup_pose, E_POSES.windup, smoothstep(0.0, 0.7, ai_t / windup_len))
		"strike":   # direct capturé (CMU 144_20) : de l'armé du jeu au bras tendu
			var k := minf(ai_t / (STRIKE * 0.6), 1.0)
			a = _blend(E_POSES.windup, _punch_pose(lerpf(0.16, PUNCH_HIT, k)), smoothstep(0.0, 0.5, k))
		"recover":   # retour capturé, puis la garde
			var k := minf(ai_t / RECOVER, 1.0)
			a = _blend(_punch_pose(lerpf(PUNCH_HIT, 1.0, k)), E_POSES.guard, smoothstep(0.6, 1.0, k))
		"landed":
			a = _blend(E_POSES.land, E_POSES.guard, smoothstep(0.0, 1.0, ai_t / LANDED))
	if ai == "stunned":
		var wob := sin(ai_t * 9.0) * 6.0
		a = _blend(E_POSES.strike, E_POSES.stunned, smoothstep(0.0, 0.15, ai_t))
		a.chest = a.chest + Vector3(0, wob, wob * 0.5)
		a.head = a.head + Vector3(wob, wob, 0)
		drop = 0.06
		return a
	drop = LAND_DROP * (1.0 - smoothstep(0.0, 1.0, ai_t / LANDED)) if ai == "landed" else 0.0
	if ai == "block":
		drop = 0.05   # garde haute : il se tasse un peu
		return a
	# jambes de la marche / course capturées (CMU), dans la direction où il se déplace (pas de côté, recul) ; le haut reste en garde
	gait_w = move_toward(gait_w, clampf(gait_v / 0.4, 0.0, 1.0), get_physics_process_delta_time() * 5.0)
	moving = gait_w   # foulée entière dès qu'il bouge un peu (sinon les pieds patinent) ; à l'arrêt, les jambes se reposent en douceur
	if moving > 0.0:
		var c := _gait_pose(walk_phase / TAU)
		var turn := Quaternion(Vector3.UP, gait_yaw)
		for n in ["thigh_l", "thigh_r"]:
			var q := turn * Quaternion.from_euler(c[n] * (PI / 180)) * turn.inverse()   # plan du pas tourné vers le déplacement
			a[n] = Vector3.ZERO.lerp(q.get_euler() * (180.0 / PI), moving)
		for n in ["shin_l", "shin_r"]:
			a[n] = Vector3.ZERO.lerp(c[n], moving)
		a.chest = a.chest + c.chest * 0.5 * moving
		drop = maxf(drop, -c.pelvis_off.y * moving)
	return a


## Image u (0..1, boucle) de la marche ou de la course capturées, mélangées selon sa vitesse ; repère du sbire.
func _gait_pose(u: float) -> Dictionary:
	_cycles()
	var w := smoothstep(1.8, 3.6, gait_v)
	var a := _cyc_e(E_WALK, u)
	if w <= 0.0:
		return a
	var b := _cyc_e(E_RUN, u)
	for k in a:
		a[k] = a[k].lerp(b[k], w)
	return a


func _stride() -> float:
	return lerpf(CycleData.WALK_STRIDE, CycleData.RUN_STRIDE, smoothstep(1.8, 3.6, gait_v))


static func _cyc_e(arr: Array, u: float) -> Dictionary:
	var x := fposmod(u, 1.0) * arr.size()
	var i := int(x) % arr.size()
	var a: Dictionary = arr[i]
	var b: Dictionary = arr[(i + 1) % arr.size()]
	var f := x - floorf(x)
	var out := {}
	for k in a:
		out[k] = _mixv(k, a[k], b[k], f)
	return out


static func _clip_e(arr: Array, u: float) -> Dictionary:
	var x := clampf(u, 0.0, 1.0) * (arr.size() - 1)
	var i := mini(int(x), arr.size() - 2)
	var out := {}
	for k in arr[i]:
		out[k] = _mixv(k, arr[i][k], arr[i + 1][k], x - i)
	return out


## Deux valeurs d'une pose : les angles par le plus court chemin entre les deux rotations (quaternions), le reste en ligne droite.
static func _mixv(k: String, a: Vector3, b: Vector3, f: float) -> Vector3:
	if k == "pelvis_off" or k == "hips_pos" or k.begins_with("foot_"):
		return a.lerp(b, f)
	var qa := Quaternion.from_euler(a * (PI / 180))
	var qb := Quaternion.from_euler(b * (PI / 180))
	return qa.slerp(qb, f).get_euler() * (180.0 / PI)


## Pose du héros (degrés, repère du héros qui regarde -Z) -> pose du sbire (il regarde +Z) : même mouvement, tourné d'un
## demi-tour (x et z changent de signe), bras et jambes échangés (le bras gauche du héros est du côté +X du sbire).
static func to_enemy(p: Dictionary) -> Dictionary:
	const MAP := {"spine": "chest", "head": "head", "sh_l": "arm_r", "el_l": "fore_r", "sh_r": "arm_l", "el_r": "fore_l",
		"hip_l": "thigh_r", "kn_l": "shin_r", "hip_r": "thigh_l", "kn_r": "shin_l", "hips": "pelvis", "hips_pos": "pelvis_off"}
	var out := {}
	for k in MAP:
		var v: Vector3 = p.get(k, Vector3.ZERO)
		out[MAP[k]] = Vector3(-v.x, v.y, -v.z)
	return out


static var E_WALK := []
static var E_RUN := []
static var E_UP_FRONT := []
static var E_UP_BACK := []
static var E_PUNCH := []
const PUNCH_HIT := 0.526   # instant de l'impact dans la capture du direct


## Pose du direct capturé (haut du corps seulement : les jambes restent celles du jeu, le pas d'élan est géré à part).
func _punch_pose(u: float) -> Dictionary:
	_cycles()
	var p := _clip_e(E_PUNCH, u)
	var out := {}
	for n in ["chest", "head", "arm_l", "fore_l", "arm_r", "fore_r"]:
		out[n] = p[n]
	# exagéré : il plonge le buste dans le coup et vise plus bas (la capture frappe à hauteur de tête, le héros est plus petit)
	var w := smoothstep(0.2, PUNCH_HIT, u) * (1.0 - smoothstep(0.6, 0.95, u))
	out.chest = out.chest + Vector3(25.0 * w, 0, 0)
	out.arm_l = out.arm_l + Vector3(40.0 * w, 0, 0)
	return out


static func _cycles() -> void:
	if not E_WALK.is_empty():
		return
	for pair in [[CycleData.WALK, E_WALK], [CycleData.RUN, E_RUN], [CycleData.GETUP_FRONT, E_UP_FRONT], [CycleData.GETUP_BACK, E_UP_BACK], [CycleData.PUNCH, E_PUNCH]]:
		for p in pair[0]:
			pair[1].append(to_enemy(p))


func _blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var r := {}
	for n in a.merged(b):   # une articulation absente d'une pose = au repos
		r[n] = a.get(n, Vector3.ZERO).lerp(b.get(n, Vector3.ZERO), u)
	return r


## Son coup : une zone généreuse (gélule le long de l'avant-bras, prolongée devant le poing, bien plus épaisse que le bras).
## Renvoie true s'il a touché.
## Parade du joueur : il est sonné, il ne bouge plus et ne peut ni frapper ni parer.
func stun(t: float) -> void:
	if state != "stand":
		return
	ai = "stunned"
	ai_t = 0.0
	stun_len = t
	chain_left = 0
	punched = true


func _punch() -> bool:
	var elbow: Vector3 = parts.fore_l.global_transform * Vector3(0, 0.14, 0)
	var tip: Vector3 = parts.fore_l.global_transform * Vector3(0, -0.14 - HIT_EXTRA, 0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = CapsuleShape3D.new()
	q.shape.radius = HIT_RADIUS
	q.shape.height = elbow.distance_to(tip) + 2.0 * HIT_RADIUS
	q.transform = Transform3D(Basis(Quaternion(Vector3.UP, (tip - elbow).normalized())), (elbow + tip) * 0.5)
	q.collision_mask = 4
	for r in get_world_3d().direct_space_state.intersect_shape(q, 4):
		if r.collider == target and target.is_invulnerable():
			if target.has_method("on_evade"):
				target.on_evade(self)   # pas de côté réussi (le coup l'a manqué de peu)
		elif r.collider == target:
			target.take_hit(root.basis.z, PUNCH_DMG * (1.5 if weapon else 1.0), self)
			return true
	return false


## Pose debout : le corps pivote autour des pieds (vacillement), puis chaque membre suit l'animation
## autour de son articulation (cinématique directe) ; le buste fouette en plus quand il encaisse.
func _pose(jitter := Vector3.ZERO) -> void:
	var tilt := Basis(lean.normalized(), lean.length()) if lean.length() > 0.0001 else Basis()
	_fk(Transform3D(tilt * root.basis, root.origin + jitter - Vector3.UP * drop))


## Repère du corps entier pour une pose debout `r` (sans vacillement) : celui que _fk recevrait.
func _body_x(r: Transform3D) -> Transform3D:
	var x := r
	if anim.has("pelvis") or anim.has("pelvis_off"):
		var c := Vector3(0, 1.0, 0)
		var b := Basis(Quaternion.from_euler(anim.get("pelvis", Vector3.ZERO) * (PI / 180)))
		x = Transform3D(x.basis, x.origin + x.basis * anim.get("pelvis_off", Vector3.ZERO)) * Transform3D(b, c - b * c)
	return x


## Place chaque membre : x = repère du corps entier, puis chaque membre tourne autour de son articulation selon `anim`.
func _fk(x: Transform3D) -> void:
	if anim.has("pelvis") or anim.has("pelvis_off"):   # bassin animé (relevé capturé) : tourné autour de son centre, décalé
		var c := Vector3(0, 1.0, 0)
		var b := Basis(Quaternion.from_euler(anim.get("pelvis", Vector3.ZERO) * (PI / 180)))
		x = Transform3D(x.basis, x.origin + x.basis * anim.get("pelvis_off", Vector3.ZERO)) * Transform3D(b, c - b * c)
	if not x.origin.is_finite():
		return   # v0.218 : sécurité (corps coincé dans le décor) : on ne place jamais un membre à l'infini
	var xf := {}
	var rx := _react_offsets(x)
	for d in BODY:
		var q := Quaternion.from_euler((anim.get(d[0], Vector3.ZERO) + rx.get(d[0], Vector3.ZERO)) * (PI / 180))
		if d[0] == "chest" and lean.length() > 0.0001:
			q = Quaternion((x.basis.inverse() * lean).normalized(), lean.length() * 0.8) * q
		var rest := Transform3D(Basis(), d[3])
		if d[1] == "":
			xf[d[0]] = x * rest
		else:
			var b := Basis(q)
			xf[d[0]] = xf[d[1]] * Transform3D(Basis(), d[4] - rest_center[d[1]] - b * d[4]) * Transform3D(b, Vector3.ZERO) * rest
		parts[d[0]].global_transform = xf[d[0]]


## Réaction au coup d'un sbire debout (v0.218, Thibaud) : la tête claque en arrière, le buste part dans le sens du coup et tourne,
## les bras lâchent la garde ; ça monte d'un coup puis revient en douceur (degrés ajoutés à la pose).
func _react_offsets(x: Transform3D) -> Dictionary:
	if react_t < 0.0 or state != "stand":
		return {}
	var u := react_t / REACT_T
	var w := minf(u / 0.12, 1.0) * pow(1.0 - u, 2.0)
	var ld := x.basis.inverse() * react_dir
	var back := clampf(-ld.z, -0.4, 1.0)
	var side := clampf(ld.x, -1.0, 1.0)
	var s := react_side
	return {"chest": Vector3(-24.0 * back, 16.0 * s, -14.0 * side) * w, "head": Vector3(-34.0 * back, -22.0 * s, -10.0 * side) * w,
		"arm_l": Vector3(38, 0, 12) * w, "fore_l": Vector3(45, 0, 0) * w, "arm_r": Vector3(30, 0, -12) * w, "fore_r": Vector3(40, 0, 0) * w,
		"thigh_l": Vector3(-8, 0, 0) * w, "shin_l": Vector3(14, 0, 0) * w}


## Avancement du relevé (0 -> 1).
func _rise_progress() -> float:
	if not up_clip.is_empty() and rise_from == Transform3D():
		return timer / ((CycleData.GETUP_FRONT_PERIOD if up_clip == E_UP_FRONT else CycleData.GETUP_BACK_PERIOD) / UP_SPEED)
	return timer / RISE


## Touché presque relevé : il finit de se relever tout de suite (puis encaisse debout).
func _finish_rise() -> void:
	up_clip = []
	if rise_from != Transform3D():
		root = Transform3D(root.basis, _roll_origin(-360.0))
	state = "stand"
	ai = "circle"
	cooldown = _pause()
	anim = E_POSES.guard.duplicate()
	_pose()


## Touché pendant qu'il se relève (ou se rattrape) : il redevient un ragdoll, là où il est, sans vitesse.
func _to_ragdoll() -> void:
	for b in parts.values():
		b.freeze = false
		b.gravity_scale = RAG_GRAV
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
	up_clip = []
	state = "down"
	timer = DOWN_TIME
	air_recover = false


## Renvoie true si le coup a été paré.
func hit(part: RigidBody3D, impulse: Vector3, point: Vector3, dmg: float, drop: float, unblockable := false) -> bool:
	if state == "crisp":
		_release_crisp()   # retouché pendant sa crispation : il repart, et ce coup-ci le recrispe
	# v0.218 (Thibaud) : plus d'immunité pendant qu'il se relève. Presque debout, il finit de se relever d'un coup et encaisse
	# debout ; sinon il redevient un ragdoll (là où il est) et le coup compte comme sur un sbire au sol / en l'air.
	if state == "rise" and _rise_progress() > 0.6:
		_finish_rise()
	elif state in ["getup", "techroll", "rise"]:
		_to_ragdoll()
	if state in ["held", "swung"]:
		return false
	var flat := Vector3(impulse.x, 0, impulse.z)
	if state == "stand" and ai == "block" and not unblockable and flat.normalized().dot(root.basis.z) < -0.3:
		_block(flat)   # garde : seulement de face
		return true
	_flash()
	if state == "dead":   # le corps reste un punching-ball : jongle, relance à l'uppercut, comme vivant (sans crispation)
		timer = minf(timer, RESPAWN - RESPAWN_KEEP)
		if impulse.normalized().y > 0.72:
			_relaunch()
			_jolt(part, impulse, point)
		elif height_above(parts.pelvis.global_position) > 0.6 and impulse.normalized().y < -0.3:
			_spike(impulse)
			_jolt(part, impulse, point)
		elif height_above(parts.pelvis.global_position) > 0.6:
			_juggle(impulse)
			_jolt(part, impulse, point)
		else:
			_push(part, impulse, point)
		return false
	if state == "launch":
		hp = maxf(hp - dmg, 0.0)
		return false   # shortcut: un 2e coup pendant les 70 ms de réaction (coups horizontaux) ne change pas l'éjection
	hp = maxf(hp - dmg, 0.0)
	if state == "down":
		if height_above(parts.pelvis.global_position) > 0.6:
			if impulse.normalized().y > 0.72:
				_relaunch()   # uppercut sur un ennemi en l'air : vrai nouveau décollage
			elif impulse.normalized().y < -0.3:
				_spike(impulse)   # coup vers le bas (marteau) : écrasé au sol, fin du jongle
			else:
				_juggle(impulse)   # touché en l'air
			_crisp(part, impulse, point)
		else:
			_push(part, impulse, point)
		if hp <= 0:
			state = "dead"
			timer = _dead_timer()
		return false
	poise -= drop * stagger_mult
	timer = STUN
	if ai in ["windup", "strike", "block"]:
		ai = "circle"   # interrompu : il faut le toucher pendant qu'il arme
		chain_left = 0
		cooldown = maxf(cooldown, 0.5)
	var dir := Vector3(impulse.x, 0, impulse.z).normalized()
	if hp <= 0 or poise <= 0:
		state = "launch"
		timer = REACT
		launch_dir = dir
		launch_strength = impulse.length()
		launch_up = maxf(impulse.normalized().y, 0.0)
	# Réaction instantanée : il est déjà plié et reculé sur l'image du hitstop, puis le ressort continue le mouvement.
	var axis := Vector3.UP.cross(dir)
	var push := Vector2(impulse.x, impulse.z).length()   # seule la part horizontale du coup fait reculer et basculer
	lean = (lean + axis * impulse.length() * 0.005 * sway).limit_length(0.7)   # la pose d'impact, elle, encaisse tout le coup
	lean_v += axis * push * 0.05 * sway
	root.origin += dir * push * 0.004
	slide += dir * push * 0.03
	quake = 0.1
	if state == "stand":   # v0.218 : petite réaction au coup (tête et buste qui partent, bras qui lâchent la garde)
		react_t = 0.0
		react_dir = dir if dir.length() > 0.1 else -root.basis.z
		react_side = -react_side
	_pose()
	if state == "launch" and _lift() > 0.5:
		_launch()   # coup montant : il décolle dès l'impact, sinon on voit le coup puis le décollage
	return false


## Coup dans la garde : ni vie ni équilibre perdus, il recule juste un peu et tremble.
func _block(flat: Vector3) -> void:
	block_t = BLOCK_HOLD
	var dir := flat.normalized()
	var push := flat.length()
	slide += dir * minf(push * 0.025, 2.5)
	lean_v += Vector3.UP.cross(dir) * push * 0.012 * sway
	quake = 0.06
	_pose()


## Temps de mort au moment où il (re)devient un corps : 0 à la première mort, sinon on garde le délai entamé
## (au plus RESPAWN - RESPAWN_KEEP : chaque coup lui laisse un sursis, sans le garder indéfiniment).
func _dead_timer() -> float:
	var t0 := minf(timer, RESPAWN - RESPAWN_KEEP) if corpse else 0.0
	corpse = true
	return t0


## Coup au ras du sol sur un sbire couché (balayage, capoeira ; v0.216, retour de Thibaud) : il prend les dégâts,
## décolle un peu et repart en roulant, pour qu'on voie bien que le coup a porté.
var ground_kicks := 0   # (tests) coups au sol reçus
var bowl_t := -1.0      # lancé « boule de bowling » (v0.217) : lourd, peu de courbe, retombe avec fracas sans glisser
var bowl_lands := 0     # (tests) réceptions lourdes
var bowl_air := false   # il a vraiment décollé depuis le lancer (sinon on ne compte pas la réception)
var bowl_h0 := 0.0      # hauteur du bassin au moment du lancer


## Lancé lourd (shoot de foot, grand tour) : vitesse horizontale × k, peu de montée, forte gravité ; à la réception il s'écrase
## sur place (plus de glissade), avec une secousse.
func bowl(k: float, grav := 4.5, max_up := 3.5) -> void:
	bowl_t = 0.0
	bowl_air = false
	bowl_h0 = height_above(parts.pelvis.global_position)
	for b in parts.values():
		b.linear_velocity = Vector3(b.linear_velocity.x * k, minf(b.linear_velocity.y, max_up), b.linear_velocity.z * k)
		b.gravity_scale = grav


func _bowl_tick(dt: float) -> void:
	bowl_t += dt
	var pel: RigidBody3D = parts.pelvis
	var h := height_above(pel.global_position)
	if h > minf(bowl_h0, 0.4) + 0.2:
		bowl_air = true
	if (bowl_air and h < minf(bowl_h0, 0.4) + 0.12 and pel.linear_velocity.y <= 0.5) or bowl_t > 2.5:
		bowl_t = -1.0
		bowl_lands += 1
		for b in parts.values():
			b.linear_velocity = Vector3(b.linear_velocity.x * 0.12, minf(b.linear_velocity.y, 0.0), b.linear_velocity.z * 0.12)
			b.angular_velocity *= 0.3
			b.gravity_scale = RAG_GRAV
		_flash()
		if get_parent().has_method("impact"):
			get_parent().impact(0.08, 0.9)


func ground_kick(dir: Vector3, dmg: float) -> void:
	if state in ["getup", "techroll", "rise", "held", "swung"]:
		return
	ground_kicks += 1
	if state == "crisp":
		_release_crisp()
	hp = maxf(hp - dmg, 0.0)
	_flash()
	if state != "dead":
		state = "dead" if hp <= 0 else "down"
		timer = _dead_timer() if hp <= 0 else DOWN_TIME
	air_recover = false
	var w := dir.cross(Vector3.UP).normalized() * -5.0
	for b in parts.values():
		b.freeze = false
		b.linear_velocity += dir * 3.0 + Vector3.UP * 4.0
		b.angular_velocity += w


## Fauché : ses pieds partent dans le sens du balayage, le buste bascule à l'opposé, il décolle un peu et tombe à plat.
func trip(dir: Vector3, dmg: float, up := 2.6) -> void:
	hp = maxf(hp - dmg, 0.0)
	_flash()
	state = "dead" if hp <= 0 else "down"
	timer = _dead_timer() if hp <= 0 else DOWN_TIME
	air_recover = false
	juggles = 0
	poise = 1.0
	lean = Vector3.ZERO
	lean_v = Vector3.ZERO
	slide = Vector3.ZERO
	var c := Vector3.ZERO
	var m := 0.0
	for b in parts.values():
		c += b.global_position * b.mass
		m += b.mass
	c /= m
	# Rotation autour de cet axe : les pieds (sous le centre) partent vers dir, la tête vers -dir.
	var w := dir.cross(Vector3.UP).normalized() * trip_spin * (1.0 + randf_range(-0.15, 0.15) * chaos) + Vector3.UP * randf_range(-1.5, 1.5) * chaos
	for b in parts.values():
		b.freeze = false
		b.gravity_scale = RAG_GRAV
		b.linear_velocity = dir * 1.2 + Vector3.UP * up + w.cross(b.global_position - c)
		b.angular_velocity = w


func grabbable() -> bool:
	return state == "stand"


## Chope : il ne réagit plus, son corps passe là où le joueur le tient.
func grab() -> void:
	state = "held"
	held_t = 0.0
	held_blend = 0.0
	held_pose = "held"
	held_hit = 0.0
	ai = "circle"
	timer = 0.0
	lean = Vector3.ZERO
	lean_v = Vector3.ZERO
	slide = Vector3.ZERO
	quake = 0.0
	drop = 0.0
	for b in parts.values():
		b.collision_layer = 0   # il traverse le joueur pendant qu'il est soulevé


## Tenu : le joueur donne l'orientation du corps et la position du buste.
func hold(b: Basis, chest: Vector3) -> void:
	root.basis = Basis(Vector3.UP, root.basis.get_euler().y)
	anim = E_POSES[held_pose].duplicate()
	if held_pose == "held":
		var w := sin(held_t * 30.0) * 15.0   # il gigote
		for n in ["arm_l", "arm_r", "thigh_l", "thigh_r"]:
			anim[n] += Vector3(w if n.ends_with("l") else -w, 0, 0)
	var k := held_hit / 0.15
	anim.head += Vector3(-38, randf_range(-10, 10), 0) * k   # la tête part en arrière sous le coup
	anim.chest += Vector3(-16, 0, 0) * k
	chest -= b.z * 0.14 * k   # tout le corps recule un peu (il te fait face : son dos est vers -z)
	var x := Transform3D(b, chest - b * rest_center.chest)
	if held_t < held_blend:   # chope au sol : on le relève depuis là où il gisait
		blend_x = x
		blend_anim = anim
		_getup_pose(held_t / held_blend)
	else:
		_fk(x)


## En ragdoll (au sol, en l'air, crispé, KO) : le grand tour peut l'attraper par les pieds.
func ragdolled() -> bool:
	return state in ["down", "crisp", "dead"]


func air_grabbable() -> bool:
	return state in ["down", "crisp", "dead"] and height_above(parts.pelvis.global_position) >= 0.6


func collar_grabbable() -> bool:
	return state in ["down", "dead"] and height_above(parts.pelvis.global_position) < 0.6


## Chope au sol : attrapé par le col, relevé jusqu'à la main du joueur.
func collar_grab() -> void:
	state = "held"
	held_t = 0.0
	held_blend = 0.14
	held_pose = "collar"
	held_hit = 0.0
	getup_from.clear()
	for n in parts:
		parts[n].freeze = true
		parts[n].gravity_scale = 1.0
		parts[n].collision_layer = 0
		getup_from[n] = parts[n].global_transform


## Chopé debout et tenu trop longtemps : il se dégage et retombe direct sur ses pieds, un pas en arrière.
func break_free(away: Vector3) -> void:
	_start_blend("land")
	var off := (away * Vector3(1, 0, 1)).normalized() * 0.45
	root.origin += off
	blend_x.origin += off


## Frappé pendant qu'il est tenu par le col.
func collar_hit(dmg: float) -> void:
	hp = maxf(hp - dmg, 0.0)
	held_hit = 0.15
	_flash()


## Lâché à la fin du grand tour : chaque membre garde la vitesse de la rotation (les pieds, plus loin, partent plus vite).
func swing_release(pivot: Vector3, w: Vector3, dmg: float) -> void:
	thrown()
	land_dmg = dmg   # le coup, il le prendra en s'écrasant au sol
	land_t = 0.0
	state = "dead" if hp <= 0 else "down"
	timer = _dead_timer() if hp <= 0 else DOWN_TIME
	air_recover = false
	juggles = 0
	for n in parts:
		var b: RigidBody3D = parts[n]
		b.collision_layer = 2
		b.gravity_scale = RAG_GRAV
		b.freeze = false
		b.linear_velocity = (b.linear_velocity + Vector3.UP * 2.5).limit_length(18.0)
	for d in BODY:
		parts[d[0]].mass = d[5]   # masses d'origine


## Projeté par une chope (v0.218, Thibaud) : pendant le vol, ce qu'il percute fait mal (mur, décor, objet, autre sbire).
func thrown(t := 1.6) -> void:
	impact_t = t
	impact_hits.clear()


## Chocs du vol : rayons dans le sens du mouvement depuis le buste, le bassin et la tête ; chaque chose n'est percutée qu'une fois.
func _impact_tick(dt: float) -> void:
	impact_t -= dt
	if not state in ["down", "dead"] or parts.is_empty():
		impact_t = 0.0
		return
	var v: Vector3 = parts.pelvis.linear_velocity
	var sp := v.length()
	if sp < IMPACT_SPEED:
		return
	var own := []
	for b in parts.values():
		own.append(b.get_rid())
	var space := get_world_3d().direct_space_state
	for n in ["chest", "pelvis", "head"]:
		var from_p: Vector3 = parts[n].global_position
		var q := PhysicsRayQueryParameters3D.create(from_p, from_p + v.normalized() * (sp * dt * 1.5 + 0.35), 1 | 2 | RAGDOLL_LAYER)
		q.exclude = own
		var r := space.intersect_ray(q)
		if r.is_empty() or impact_hits.has(r.collider):
			continue
		var c = r.collider
		var other = c.get_parent()
		if other != self and other.has_method("hit"):   # un autre sbire
			if projectile_t > 0.0 or impact_hits.has(other):
				continue   # déjà percuté par le lancer visé (_swing_sweep)
			impact_hits[other] = true
			impact_hits[c] = true
			other.hit(c, (v.normalized() + Vector3.UP * 0.3).normalized() * 120.0, r.position, IMPACT_DMG, 1.0, true)
		elif c is StaticBody3D:
			if r.normal.y > 0.6:
				continue   # le sol : c'est la réception (land_dmg), pas un choc
			impact_hits[c] = true
		elif c is RigidBody3D:   # objet du décor : il le bouscule, une table se brise
			impact_hits[c] = true
			if not TestMap.shatter(c, v * 0.5):
				c.apply_central_impulse(v * 18.0)
		else:
			continue
		var k := clampf(sp / 10.0, 0.6, 1.6)
		hp = maxf(hp - IMPACT_DMG * k, 0.0)
		impact_count += 1
		_flash()
		if get_parent().has_method("impact"):
			get_parent().impact(0.06, 0.6)
		if hp <= 0 and state != "dead":
			state = "dead"
			timer = _dead_timer()
		return


## Sécurité (v0.218) : positions devenues infinies (corps coincé dans le décor) : il est remis debout à son dernier point valable.
func _rescue() -> void:
	var keep_hp := hp
	global_position = _free_spot(last_good if last_good.is_finite() else Vector3.ZERO)
	global_basis = Basis()
	build()
	hp = keep_hp


## Lancer visé : ragdoll projeté (il tournoie), qui percute les autres sbires en vol et prend le coup en touchant le sol.
func throw_body(v: Vector3, dmg: float) -> void:
	toss(v, 3.0)
	thrown()
	land_dmg = dmg
	land_t = 0.0
	projectile_t = 1.2
	swing_victims.clear()


## Lancé par le grand tour : dès qu'il touche le sol (en redescendant), il prend le coup : dégâts, flash, secousse.
func _land_hit(dt: float) -> void:
	land_t += dt
	var low := INF
	for b in parts.values():
		low = minf(low, b.global_position.y)
	if (land_t > 0.1 and height_above(parts.pelvis.global_position) < 0.35 and parts.pelvis.linear_velocity.y <= 0.5) or land_t > 3.0:
		hp = maxf(hp - land_dmg, 0.0)
		land_dmg = 0.0
		_flash()
		if get_parent().has_method("impact"):
			get_parent().impact(0.07, 0.7)
		if hp <= 0 and state != "dead":
			state = "dead"
			timer = _dead_timer()


## Grand tour : attrapé par les pieds. Tout le corps reste en ragdoll ; les tibias sont menés en vitesse jusqu'à nos mains.
func feet_grab() -> void:
	_hand_prev = {}
	state = "swung"
	held_t = 0.0
	air_recover = false
	juggles = 0
	getup_from.clear()
	for n in parts:
		var b: RigidBody3D = parts[n]
		b.freeze = false
		b.gravity_scale = 1.0
		b.collision_layer = 0   # il traverse le joueur
		getup_from[n] = b.global_transform
	swing_victims.clear()
	parts.shin_l.mass = 80.0   # tenus : lourds, le reste du corps ne les fait pas traîner derrière nos mains
	parts.shin_r.mass = 80.0
	for n in ["arm_l", "arm_r", "fore_l", "fore_r", "head"]:
		parts[n].mass = 1.0   # le bout de la chaîne (le plus loin du centre) allégé : la force centrifuge n'arrache pas les coudes


## Place ses chevilles dans nos mains, tibias tendus vers l'extérieur (le premier instant : on les ramène depuis le sol).
var _hand_prev := {}   # mains du grand tour à l'image d'avant (pour anticiper leur mouvement)

func feet_hold(hand_l: Vector3, hand_r: Vector3, out: Vector3, dt: float, sweep := true) -> void:
	held_t += dt
	# v0.217 : le grand tour tourne plus vite ; on vise là où seront les mains à l'image suivante, sinon les chevilles traînent.
	var pl: Vector3 = _hand_prev.get("l", hand_l)
	var pr: Vector3 = _hand_prev.get("r", hand_r)
	_hand_prev = {"l": hand_l, "r": hand_r}
	if held_t > dt * 1.5 and pl.distance_to(hand_l) < 0.5 and pr.distance_to(hand_r) < 0.5:
		hand_l += hand_l - pl
		hand_r += hand_r - pr
	var u := smoothstep(0.0, 1.0, minf(held_t / 0.25, 1.0))
	var y := out.normalized()   # cheville -> genou : vers l'extérieur
	var z := (Vector3.UP - y * y.dot(Vector3.UP)).normalized()
	var b := Basis(y.cross(z), y, z).orthonormalized()
	for side in [["shin_l", hand_l], ["shin_r", hand_r]]:
		var shin: RigidBody3D = parts[side[0]]
		var goal := Transform3D(b, side[1] + b.y * 0.225)   # la cheville (bas du tibia) dans la main
		if u < 1.0:
			goal = getup_from[side[0]].interpolate_with(goal, u)
		# Pas de téléportation (qui étire les articulations) : on donne au tibia la vitesse qui l'amène pile au but à la prochaine image.
		# Vitesses bornées : si le corps retient le tibia (sol, articulation), on ne demande pas une vitesse folle qui ferait tout exploser.
		shin.linear_velocity = ((goal.origin - shin.global_position) / dt).limit_length(22.0)   # v0.217 : grand tour plus rapide
		var dq := (goal.basis.orthonormalized() * shin.global_basis.orthonormalized().inverse()).get_rotation_quaternion()
		shin.angular_velocity = (dq.get_axis() * dq.get_angle() / dt).limit_length(25.0) if dq.get_angle() > 0.0001 else Vector3.ZERO
	_tighten(dt)
	if u >= 1.0 and sweep:
		_swing_sweep()


## Grand tour : la force centrifuge étire les bras et la tête ; on ramène chaque bout de chaîne vers son articulation.
func _tighten(dt: float) -> void:
	for d in BODY:
		if d[1] == "" or not d[0] in ["arm_l", "arm_r", "fore_l", "fore_r", "head"]:
			continue
		var at_parent: Vector3 = parts[d[1]].to_global(d[4] - rest_center[d[1]])
		var at_child: Vector3 = parts[d[0]].to_global(d[4] - d[3])
		var gap := at_parent - at_child
		if gap.length() > 0.02:
			parts[d[0]].linear_velocity += gap / dt * 0.9


## Pendant le grand tour, son corps sert de massue : il percute (une fois) chaque autre ennemi qu'il traverse.
func _swing_sweep() -> void:
	var own := []
	for b in parts.values():
		own.append(b.get_rid())
	var space := get_world_3d().direct_space_state
	for n in ["head", "chest", "pelvis", "arm_l", "arm_r", "fore_l", "fore_r"]:
		var b: RigidBody3D = parts[n]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = SphereShape3D.new()
		q.shape.radius = 0.35
		q.transform = Transform3D(Basis(), b.global_position)
		q.collision_mask = 2 | RAGDOLL_LAYER
		q.exclude = own
		for r in space.intersect_shape(q, 8):
			var other = r.collider.get_parent()
			if other == self or not other.has_method("hit") or swing_victims.has(other):
				continue
			swing_victims[other] = true
			var dir := (b.linear_velocity * Vector3(1, 0, 1)).normalized()
			other.hit(r.collider, (dir + Vector3.UP * 0.4).normalized() * 130.0, r.collider.global_position, 12.0, 1.0, true)
			if get_parent().has_method("impact"):
				get_parent().impact(0.06, 0.6)


## Relâché par le joueur avec une vitesse donnée : ragdoll qui part (jongle possible), ou s'écrase s'il est KO.
func toss(v: Vector3, spin_amount: float) -> void:
	state = "dead" if hp <= 0 else "down"
	timer = _dead_timer() if hp <= 0 else DOWN_TIME
	air_recover = false
	juggles = 0
	var c: Vector3 = parts.pelvis.global_position
	var w := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * spin_amount
	for b in parts.values():
		b.collision_layer = 2
		b.freeze = false
		b.gravity_scale = RAG_GRAV
		b.linear_velocity = v + w.cross(b.global_position - c)
		b.angular_velocity = w


## Coup de tête : lâché, la tête part en arrière, il tombe sur le dos et rebondit au sol.
func headbutt(fwd: Vector3, dmg: float) -> void:
	hp = maxf(hp - dmg, 0.0)
	_flash()
	state = "dead" if hp <= 0 else "down"
	timer = _dead_timer() if hp <= 0 else DOWN_TIME
	air_recover = false
	juggles = 0
	land_bounce = bounce * 0.9
	var c: Vector3 = parts.pelvis.global_position
	var w := Vector3.UP.cross(fwd) * 7.0   # bascule en arrière : la tête part loin de toi
	for b in parts.values():
		b.collision_layer = 2
		b.freeze = false
		b.gravity_scale = RAG_GRAV
		b.linear_velocity = fwd * 2.5 + Vector3.DOWN * 3.0 + w.cross(b.global_position - c)
		b.angular_velocity = w
	var head: RigidBody3D = parts.head
	head.linear_velocity += fwd * 4.0   # la tête encaisse : elle part plus vite que le reste (le corps plie)


## Électrifié : il convulse, tombe au sol et prend des dégâts tant que ça dure. chain : il électrifie ses voisins (zone).
func electrify(t: float, chain := false) -> void:
	if parts.is_empty() or state == "dead":
		return
	var fresh := not status.has("elec")
	status["elec"] = maxf(status.get("elec", 0.0), t)
	if chain and fresh:
		status["elec_chain"] = 0.2
	if state == "stand":
		var away := (root.origin - target.global_position) * Vector3(1, 0, 1) if target else root.basis.z
		trip(away.normalized() if away.length() > 0.01 else root.basis.z, 3.0, 1.0)
	if state == "down":
		timer = maxf(timer, t + 0.3)
	_flash()


func has_status(n: String) -> bool:
	return status.has(n)


func _status_tick(dt: float) -> void:
	if status.has("elec"):
		status.elec -= dt
		hp = maxf(hp - ELEC_DPS * dt, 0.0)
		if state == "down":
			timer = maxf(timer, 0.4)
			for b in parts.values():   # convulsions
				if not b.freeze:
					b.angular_velocity += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 30.0 * dt
					b.linear_velocity += Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 12.0 * dt
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.7, 1.0) * (0.4 + randf() * 1.2)
		if hp <= 0 and state != "dead":
			state = "dead"
			timer = _dead_timer()
		if status.has("elec_chain"):
			status.elec_chain -= dt
			if status.elec_chain <= 0.0:
				status.erase("elec_chain")
				for o in get_tree().get_nodes_in_group("enemies"):
					if o != self and is_instance_valid(o) and not o.parts.is_empty() and not o.status.has("elec") and o.parts.pelvis.global_position.distance_to(parts.pelvis.global_position) < ELEC_SPREAD:
						o.electrify(status.elec * 0.8 + 0.6, false)
		if status.elec <= 0.0:
			status.erase("elec")
			status.erase("elec_chain")
			mat.emission_enabled = false


## Lui donne une arme (bâton) dans la main droite.
func give_weapon() -> void:
	if weapon or parts.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(0.07, 0.95, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.3, 0.16)
	mi.material_override = m
	parts.fore_r.add_child(mi)
	mi.position = Vector3(0, -0.2, -0.32)
	mi.rotation = Vector3(deg_to_rad(90), 0, 0)
	weapon = mi


## Désarmé : l'arme quitte sa main et devient un objet que le héros peut tenir.
func drop_weapon() -> RigidBody3D:
	if weapon == null:
		return null
	var at: Vector3 = weapon.global_position
	var bas: Basis = weapon.global_basis
	weapon.queue_free()
	weapon = null
	var b := RigidBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 1 | 4 | 8
	b.add_to_group("reactive")
	b.set_meta("kind", "bat")
	b.mass = 3.0
	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = Vector3(0.07, 0.95, 0.07)
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.mesh.size = Vector3(0.07, 0.95, 0.07)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.3, 0.16)
	mi.material_override = m
	b.add_child(mi)
	get_parent().add_child(b)
	b.global_transform = Transform3D(bas, at)
	return b


## Hauteur du sol (décor, couche 1) sous p, en partant de `up` au-dessus. INF si le point de départ est dans un bloc (trop haut).
func ground_y(p: Vector3, up := 0.6) -> float:
	if not is_inside_tree():
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * up, p + Vector3.DOWN * 12.0, 1)
	q.hit_from_inside = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return 0.0
	if r.normal == Vector3.ZERO:
		return INF
	return r.position.y


## Hauteur d'un point au-dessus du sol qui est sous lui (le sol peut être l'escalier, la plateforme, une table…).
func height_above(p: Vector3) -> float:
	var g := ground_y(p, 0.25)
	return p.y - (g if g != INF else p.y)


## Couché sur un objet du décor (table, caisse…) plutôt que sur le sol.
func _on_prop(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.25, p + Vector3.DOWN * 3.0, 1)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return not r.is_empty() and r.collider is RigidBody3D


## Déplacement debout sur le terrain : il suit le sol, ne monte pas plus haut qu'une marche, ne se jette pas dans le vide
## (sauf poussé par un coup : il bascule par-dessus le bord), et contourne un obstacle trop haut.
func _walk(d: Vector3, knock := false) -> void:
	detour_t -= get_physics_process_delta_time()
	if detour_t <= 0.0:
		detour = 0.0
	var o := root.origin
	if d.length_squared() < 1e-10:
		var g0 := ground_y(o, STEP_UP)
		if g0 != INF and absf(g0 - o.y) > 0.01 and g0 > o.y - LEDGE_DROP:
			root.origin.y = move_toward(o.y, g0, 6.0 * get_physics_process_delta_time())
		return
	var tries := [d]
	if not knock:
		var sgn := detour if detour != 0.0 else (1.0 if (get_instance_id() % 2) == 0 else -1.0)
		for a in [50.0, 90.0, 130.0]:
			tries.append(d.rotated(Vector3.UP, deg_to_rad(a * sgn)) * 0.85)
			tries.append(d.rotated(Vector3.UP, deg_to_rad(-a * sgn)) * 0.85)
	for i in tries.size():
		var n: Vector3 = o + tries[i]
		var g := ground_y(n, STEP_UP)
		if g == INF:
			continue   # mur, bloc trop haut
		if g < o.y - LEDGE_DROP:
			if knock and state == "stand":
				root.origin = Vector3(n.x, o.y, n.z)
				trip((d * Vector3(1, 0, 1)).normalized(), 0.0, 0.5)   # poussé dans le vide : il bascule
				return
			continue
		root.origin = Vector3(n.x, g, n.z)
		if i > 0:
			detour = signf(tries[0].cross(tries[i]).y) if detour == 0.0 else detour
			detour_t = 1.2
		return


## Chute d'un rebord : on suit le sol le plus haut survolé depuis le dernier contact ; en touchant un sol plus bas, il prend
## des dégâts selon le dénivelé (jamais pour un jongle ou un rebond sur place : le sol n'a pas changé de hauteur).
func _terrain_fall() -> void:
	var pel: RigidBody3D = parts.pelvis
	var gy := ground_y(pel.global_position, 0.25)
	if gy == INF:
		return
	if fall_g0 == INF:
		fall_g0 = gy
	if pel.global_position.y - gy < 0.45 and pel.linear_velocity.y <= 0.5:
		if fall_g0 - gy > FALL_HURT:
			_fall_damage(fall_g0 - gy)
		fall_g0 = gy
	else:
		fall_g0 = maxf(fall_g0, gy)


## Écrasé au sol après une grande chute (poussé du haut de la plateforme, d'un bloc…).
func _fall_damage(drop: float) -> void:
	var dmg := drop * FALL_DMG
	fall_hurt_last = dmg
	hp = maxf(hp - dmg, 0.0)
	_flash()
	if get_parent().has_method("impact"):
		get_parent().impact(0.08, minf(0.4 + dmg / 20.0, 1.2))
	if hp <= 0 and state != "dead":
		state = "dead"
		timer = _dead_timer()


## Tout corps qui s'écrase au sol rebondit, exagéré : on rend une bonne part de sa vitesse de chute vers le haut.
func _ground_bounce(dt: float) -> void:
	bounce_cd -= dt
	var vy: float = parts.pelvis.linear_velocity.y
	var low := INF
	for b in parts.values():
		low = minf(low, b.global_position.y)
	if bounce_cd <= 0 and fall_vy < -BOUNCE_MIN and height_above(parts.pelvis.global_position) < 0.45 and vy > fall_vy * 0.5:   # il vient de toucher : la chute s'est arrêtée net
		var up := minf(-fall_vy * ground_bounce, 9.0)
		for b in parts.values():   # même vitesse verticale pour tout le corps : aucun joint n'est tiré
			b.linear_velocity.y = maxf(b.linear_velocity.y, 0.0) * 0.3 + up
		bounce_cd = 0.2
		vy = up
	fall_vy = vy


func _bounce() -> void:
	var low := INF
	for b in parts.values():
		low = minf(low, b.global_position.y)
	if height_above(parts.pelvis.global_position) < 0.4 and parts.pelvis.linear_velocity.y <= 0.5:
		var c: Vector3 = parts.pelvis.global_position
		var w := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * chaos * 2.0
		for b in parts.values():
			b.linear_velocity = Vector3(b.linear_velocity.x * 0.5, land_bounce, b.linear_velocity.z * 0.5) + w.cross(b.global_position - c)
			b.angular_velocity = w
		land_bounce = 0.0
		if get_parent().has_method("impact"):
			get_parent().impact(0.06, 0.6)


## Fracassé au sol : ragdoll qui rebondit vers le haut (et un peu vers le joueur), prêt à être jonglé.
func slam(fwd: Vector3, dmg: float, bounce_k := 1.0) -> void:
	hp = maxf(hp - dmg, 0.0)
	projectile_t = 1.0   # fracassé : en rebondissant, son corps percute les autres sbires
	swing_victims.clear()
	_flash()
	state = "dead" if hp <= 0 else "down"
	timer = _dead_timer() if hp <= 0 else DOWN_TIME
	air_recover = false
	juggles = 0
	var low := INF
	var c: Vector3 = parts.pelvis.global_position
	var g := ground_y(c, 0.5)
	g = 0.0 if g == INF else g
	for b in parts.values():
		low = minf(low, b.global_position.y - 0.13 - g)
	var spin := Vector3.UP.cross(fwd) * -randf_range(1.5, 3.0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * chaos
	for b in parts.values():
		if low < 0.0:
			b.global_position.y -= low   # jamais sous le sol, sinon la physique le recrache
		b.collision_layer = 2
		b.freeze = false
		b.gravity_scale = RAG_GRAV
		b.linear_velocity = Vector3.UP * bounce * bounce_k * (1.0 + randf_range(-0.05, 0.05) * chaos) - fwd * 1.5 * bounce_k + spin.cross(b.global_position - c) * bounce_k
		b.angular_velocity = spin


## Passage en ragdoll : chaque membre garde la vitesse qu'il avait dans la réaction (bascule autour des pieds,
## fouet du buste, recul), et l'éjection s'ajoute dans le même sens. Mouvement rigide : aucun joint n'est tiré.
func _launch() -> void:
	state = "dead" if hp <= 0 else "down"
	timer = _dead_timer() if hp <= 0 else DOWN_TIME
	var s := eject * clampf(launch_strength / 80.0, 0.5, 1.5) * (1.0 + randf_range(-0.12, 0.12) * chaos)
	var lift := _lift()
	air_recover = lift > 0.5 and hp > 0 and not knockdown   # lanceur : il se rattrapera sur ses pieds (sauf jongle, KO, ou uppercut de fin de combo)
	knockdown = false
	juggles = 0
	# Chaque chute est différente : direction un peu déviée, force et hauteur qui varient, vrille autour d'un axe au hasard.
	var dir := launch_dir.rotated(Vector3.UP, randf_range(-0.3, 0.3) * chaos)
	var v := dir * s * (1.0 - lift * 0.7) + Vector3.UP * (0.5 + s * 0.075 + lift * uplift * (1.0 + randf_range(-0.06, 0.06) * chaos))   # horizontal : vite et à plat ; montant : il décolle
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(1.0, 3.0) * chaos
	var w := Vector3.UP.cross(dir) * s * 0.15 * (1.0 - lift) + spin   # même axe que la réaction (aucun ajout pour un coup montant) + la vrille
	var c: Vector3 = parts.pelvis.global_position
	var waist: Vector3 = parts.pelvis.global_transform * Vector3(0, 0.1, 0)
	for n in parts:
		var b: RigidBody3D = parts[n]
		var p := b.global_position
		var up: bool = n in ["chest", "head", "arm_l", "fore_l", "arm_r", "fore_r"]
		var add := v + w.cross(p - c)
		if n == "head" or n.begins_with("arm") or n.begins_with("fore"):
			add *= 0.6   # tête et bras traînent : le corps se désarticule au lieu de partir en planche
		if n.begins_with("arm") or n.begins_with("fore") or n.begins_with("thigh") or n.begins_with("shin"):
			add += Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)) * 1.2 * chaos   # bras et jambes battent différemment à chaque fois
		b.freeze = false
		# Coup montant : même trajectoire, parcourue plus vite (vitesses x k, gravité x k²), pour qu'il ne flotte pas.
		var k := lerpf(1.0, lift_speed, lift)
		b.gravity_scale = lerpf(RAG_GRAV, 1.3 * k * k, lift)
		b.linear_velocity = (slide + lean_v.cross(p - root.origin) + ((lean_v * 0.8).cross(p - waist) if up else Vector3.ZERO) + add) * k
		b.angular_velocity = (lean_v * (1.8 if up else 1.0) * (1.0 - lift * 0.5) + w) * k   # vol long = moins de rotation, sinon il fait un salto complet
	if air_recover:   # lanceur : il monte presque à la verticale, pour qu'on puisse le suivre d'un saut
		var drift := Vector3.ZERO
		for b in parts.values():
			drift += b.linear_velocity * Vector3(1, 0, 1) / parts.size()
		for b in parts.values():
			b.linear_velocity -= drift * 0.8   # même correction pour tous les membres : rien ne tire sur les articulations


## 0 = coup horizontal (jab, direct, chassé), 1 = coup franchement montant (uppercut).
func _lift() -> float:
	return clampf((launch_up - 0.4) / 0.4, 0.0, 1.0)


## Coup sur un corps au sol : impulsion partagée entre le membre touché et le torse, pour que les joints tiennent.
func _push(part: RigidBody3D, impulse: Vector3, point: Vector3) -> void:
	var k := minf(part.mass / 24.0, 0.5)   # un membre léger (avant-bras 2 kg) prend moins, sinon son joint s'arrache
	part.apply_impulse(impulse * k, (point - part.global_position).limit_length(0.15))
	parts.chest.apply_central_impulse(impulse * (1.0 - k))


## Jongle : touché en l'air, il ne se rattrape plus et repart vers le haut, de moins en moins (usure) ; au bout de MAX_JUGGLES il s'écrase.
func _juggle(impulse: Vector3) -> void:
	air_recover = false
	juggles += 1
	var pop: float = air_pop * ([1.0, 0.9, 0.8, 0.3][mini(juggles, MAX_JUGGLES + 1) - 1])   # au-delà de MAX_JUGGLES, il ne remonte presque plus
	# On remplace sa vitesse d'ensemble (sans toucher aux mouvements des membres entre eux) : il remonte toujours de la même façon,
	# au lieu d'empiler les coups et de partir hors de portée ; il dérive peu à l'horizontale, pour rester à portée.
	var mean := Vector3.ZERO
	var m := 0.0
	for b in parts.values():
		mean += b.linear_velocity * b.mass
		m += b.mass
	mean /= m
	var push := 0.5 if impulse.length() < 80.0 else 6.0   # un coup lourd en l'air l'envoie au loin
	var goal := Vector3(mean.x * 0.4, pop, mean.z * 0.4) + Vector3(impulse.x, 0, impulse.z).normalized() * push
	for b in parts.values():
		b.linear_velocity += goal - mean
		b.gravity_scale = 2.6 + 0.1 * juggles


## Coup vers le bas sur un ennemi en l'air (marteau) : il est écrasé au sol, sans remonter ; le jongle est fini.
func _spike(impulse: Vector3) -> void:
	air_recover = false
	juggles = MAX_JUGGLES
	var mean := Vector3.ZERO
	var m := 0.0
	for b in parts.values():
		mean += b.linear_velocity * b.mass
		m += b.mass
	mean /= m
	var goal := Vector3(mean.x * 0.3, -spike_speed, mean.z * 0.3) + Vector3(impulse.x, 0, impulse.z).normalized() * 1.0
	for b in parts.values():
		b.linear_velocity += goal - mean
		b.gravity_scale = 3.0


## Uppercut sur un ennemi en l'air : il repart vers le haut comme au lanceur (même vitesse, même gravité), le jongle repart de zéro.
func _relaunch() -> void:
	air_recover = false
	juggles = 0
	var mean := Vector3.ZERO
	var m := 0.0
	for b in parts.values():
		mean += b.linear_velocity * b.mass
		m += b.mass
	mean /= m
	var goal := Vector3(mean.x * 0.3, uplift * lift_speed, mean.z * 0.3)
	for b in parts.values():
		b.linear_velocity += goal - mean
		b.gravity_scale = 1.3 * lift_speed * lift_speed


## Touché en l'air : on garde sa vitesse de jongle pour plus tard, on fige le corps et il se contracte.
func _crisp(part: RigidBody3D, impulse: Vector3, point: Vector3) -> void:
	if hp <= 0:
		_jolt(part, impulse, point)   # KO : pas de crispation, il part mou
		return
	var v := Vector3.ZERO
	var m := 0.0
	for b in parts.values():
		v += b.linear_velocity * b.mass
		m += b.mass
	crisp_v = v / m
	var dir := Vector3(impulse.x, 0, impulse.z).normalized()
	crisp_axis = (Vector3.UP.cross(dir) if dir.length() > 0.1 else Vector3.RIGHT).rotated(Vector3.UP, randf_range(-0.4, 0.4) * chaos)
	crisp_part = part
	crisp_imp = impulse
	crisp_point = point
	var pel: RigidBody3D = parts.pelvis
	crisp_x = pel.global_transform.orthonormalized() * Transform3D(Basis(), -rest_center.pelvis)
	state = "crisp"
	timer = 0.0
	getup_from.clear()
	for n in parts:
		parts[n].freeze = true
		getup_from[n] = parts[n].global_transform


## Fin de la crispation : il reprend sa vitesse de jongle d'un coup, en tournoyant autour de son centre (mouvement rigide).
func _release_crisp() -> void:
	state = "down"
	timer = DOWN_TIME
	var c := Vector3.ZERO
	var m := 0.0
	for b in parts.values():
		c += b.global_position * b.mass
		m += b.mass
	c /= m
	var w := crisp_axis * spin * (1.0 + randf_range(-0.2, 0.2) * chaos)
	for b in parts.values():
		b.freeze = false
		b.linear_velocity = crisp_v + w.cross(b.global_position - c)
		b.angular_velocity = w
	_jolt(crisp_part, crisp_imp, crisp_point)


## Le corps encaisse : les membres proches de l'impact partent dans le sens du coup, les autres compensent
## (quantité de mouvement totale inchangée : même trajectoire, seul le corps plie), et le membre touché tourne sur lui-même.
func _jolt(part: RigidBody3D, impulse: Vector3, point: Vector3) -> void:
	var dir := impulse.normalized()
	var add := {}
	var mean := Vector3.ZERO
	var mass := 0.0
	for n in parts:
		var b: RigidBody3D = parts[n]
		var w := clampf(1.0 - b.global_position.distance_to(point) / 0.7, 0.0, 1.0)
		add[n] = dir * jolt * w * w
		mean += add[n] * b.mass
		mass += b.mass
	mean /= mass
	for n in parts:
		parts[n].linear_velocity += add[n] - mean
	part.angular_velocity += dir.cross(point - part.global_position).normalized() * jolt * 2.0
	parts.head.angular_velocity += Vector3.UP.cross(dir) * jolt * 1.5   # la tête fouette


## Ragdoll au sol (pas KO) : il se ramasse en boule avant sa roulade de relevé.
func _start_getup() -> void:
	poise = 1.0
	lean = Vector3.ZERO
	lean_v = Vector3.ZERO
	slide = Vector3.ZERO
	var p: Vector3 = parts.pelvis.global_position
	if height_above(p) > 0.45 or _on_prop(p):
		p = _off_props(p)   # tombé sur un objet du décor : il se relève à côté, pas dedans
	p = _free_spot(p)   # v0.218 : coincé dans un mur, un bloc, un objet : il se relève juste à côté (avant : positions infinies -> plantage)
	_face_from(p)
	roll_start = Vector3(p.x, ground_y(p, 0.3), p.z)
	_start_mocap_up(p)


## Relevé capturé (CMU 139_16 à plat ventre, 140_09 sur le dos) : on choisit selon sa position au sol, on place la capture
## pour que son corps couché tombe sur le ragdoll (bassin et axe tête-bassin), puis on s'y fond et on la joue.
func _start_mocap_up(p: Vector3) -> void:
	_cycles()
	var face_down: bool = (parts.chest.global_basis.z).y < 0.0   # le devant du buste regarde le sol
	up_clip = E_UP_FRONT if face_down else E_UP_BACK
	var first: Dictionary = up_clip[0]
	# axe du corps couché dans la capture (bassin -> tête) et position du bassin, dans le repère debout final
	var pb := Basis(Quaternion.from_euler(first.pelvis * (PI / 180)))
	var axis_c := pb * Vector3.UP
	var axis_r: Vector3 = parts.head.global_position - parts.pelvis.global_position
	var yaw := atan2(axis_r.x, axis_r.z) - atan2(axis_c.x, axis_c.z)
	var b := Basis(Vector3.UP, yaw)
	var off: Vector3 = b * (first.pelvis_off + Vector3(0, 1.0, 0))   # centre du bassin depuis le point debout final
	var g := ground_y(p, 0.3)
	root = Transform3D(b, Vector3(p.x - off.x, g if g != INF else p.y, p.z - off.z))
	if _on_prop(root.origin):
		root.origin = _off_props(root.origin)
	root.origin = _free_spot(root.origin)
	_start_blend("mup")


## Point au sol le plus proche où il peut se tenir debout (v0.218) : si p est dans un mur, un bloc ou un objet (le rayon part de
## l'intérieur : sol introuvable), on cherche autour, de plus en plus loin ; le y rendu est celui du sol trouvé.
func _free_spot(p: Vector3) -> Vector3:
	var g := ground_y(p, 0.3)
	if g != INF and _clear(Vector3(p.x, g, p.z)):
		return Vector3(p.x, g, p.z)
	for r in [0.5, 0.8, 1.1, 1.5, 2.0, 2.6, 3.4, 4.5]:
		for k in 16:
			var a := TAU * k / 16.0
			var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * r
			var gq := ground_y(q, 0.3)
			if gq != INF and gq <= p.y + 0.5 and _clear(Vector3(q.x, gq, q.z)):
				return Vector3(q.x, gq, q.z)
	return last_good if last_good.is_finite() else Vector3(p.x, 0.0, p.z)


## Place pour un corps debout (rien du décor dans son buste).
func _clear(at: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = CapsuleShape3D.new()
	q.shape.radius = 0.28
	q.shape.height = 1.2
	q.transform = Transform3D(Basis(), at + Vector3.UP * 1.0)
	q.collision_mask = 1
	for r in get_world_3d().direct_space_state.intersect_shape(q, 4):
		if r.collider is StaticBody3D:
			return false
	return true


## Point au sol libre le plus proche, hors des objets du décor sous (ou autour de) ce point.
func _off_props(p: Vector3) -> Vector3:
	var flat := Vector3(p.x, 0, p.z)
	for i in 4:
		var moved := false
		for b in get_tree().get_nodes_in_group("reactive"):
			if not b is Node3D:
				continue
			var c: Vector3 = (b as Node3D).global_position * Vector3(1, 0, 1)
			var d := flat - c
			var need := 1.0   # rayon d'un meuble + la boule de la roulade
			if d.length() < need:
				flat = c + (d.normalized() if d.length() > 0.05 else Vector3.RIGHT) * need
				moved = true
		if not moved:
			break
	return Vector3(flat.x, p.y, flat.z)


## Passage du ragdoll à une pose animée : on fige les corps et on interpole chaque membre vers la cible.
func _start_blend(kind: String) -> void:
	state = "getup"
	timer = 0.0
	blend_kind = kind
	if kind == "land":
		var pel: RigidBody3D = parts.pelvis
		var p := pel.global_position + pel.linear_velocity * Vector3(1, 0, 1) * LAND_BLEND * 0.6
		p = _free_spot(p)
		_face_from(p)
		blend_len = LAND_BLEND
		blend_x = Transform3D(root.basis, root.origin - Vector3.UP * LAND_DROP)
		blend_anim = E_POSES.land
	elif kind == "mup":
		blend_len = UP_BLEND
		anim = up_clip[0].duplicate()
		blend_anim = anim
		blend_x = _body_x(root)
	else:
		blend_len = GATHER
		blend_x = _roll_x(-90.0)
		blend_anim = E_POSES.tuck
	getup_from.clear()
	for n in parts:
		parts[n].freeze = true
		parts[n].gravity_scale = 1.0
		getup_from[n] = parts[n].global_transform


func _face_from(p: Vector3) -> void:
	var yaw := root.basis.get_euler().y
	if target:
		var to := target.global_position - p
		yaw = atan2(to.x, to.z)
	var g := ground_y(p, 0.3)
	root = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, g if g != INF else p.y, p.z))


## Repère du corps pendant la roulade arrière, pour un angle de bascule donné (-90 = sur le dos, -360 = redressé).
func _roll_x(angle: float) -> Transform3D:
	var r := Basis(Vector3.UP.cross(root.basis.z), deg_to_rad(angle)) * root.basis
	var c := _roll_origin(angle) + Vector3.UP * BALL_R
	return Transform3D(r, c - r * TUCK_CENTER)


## La boule roule sans glisser : elle recule de BALL_R par radian tourné, en s'éloignant du joueur.
func _roll_origin(angle: float) -> Vector3:
	return roll_start - root.basis.z * BALL_R * deg_to_rad(-angle - 90.0)


## Chaque membre va de sa position de ragdoll vers la pose cible, en gardant ses articulations collées.
func _getup_pose(t: float) -> void:
	t = smoothstep(0.0, 1.0, t)
	for d in BODY:
		var b: RigidBody3D = parts[d[0]]
		var from: Transform3D = getup_from[d[0]]
		if d[1] == "":
			b.global_transform = from.interpolate_with(blend_x * Transform3D(Basis(), d[3]), t)
			continue
		var p: RigidBody3D = parts[d[1]]
		var rel: Quaternion = (getup_from[d[1]].basis.orthonormalized().inverse() * from.basis.orthonormalized()).get_rotation_quaternion()
		var goal := Quaternion.from_euler(blend_anim.get(d[0], Vector3.ZERO) * (PI / 180))
		var basis := p.global_basis * Basis(rel.slerp(goal, t))
		var anchor: Vector3 = p.global_transform * (d[4] - rest_center[d[1]])
		b.global_transform = Transform3D(basis, anchor - basis * (d[4] - d[3]))


func _flash() -> void:
	mat.albedo_color = Color.WHITE
	await get_tree().create_timer(0.07, true, false, true).timeout
	mat.albedo_color = COLOR

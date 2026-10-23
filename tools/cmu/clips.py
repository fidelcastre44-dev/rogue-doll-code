"""Coups repris de captures CMU (mocap.cs.cmu.edu, usage libre). Une entrée par coup :
file = capture ; tip = membre qui frappe ; hit = instant de l'impact dans la capture (s) ;
t0 / t1 = début du geste et fin du retour ; speed = combien de fois plus vite que la capture (v0.214 : 1,5 à 2) ;
la fiche prend alors ce rythme (active = impact, end = fin ; l'annulation garde son rapport d'avant) et une clé toutes les `step` s
de capture (1/30 par défaut) ; plant = pieds d'appui (« lr », « l » ou « r ») : ils restent à leur place de garde et le bassin se
place par rapport à eux comme dans la capture ; plant_at = [(de, à, pieds)] pour changer d'appui pendant le geste ;
aim = instant qui donne la direction du coup (sinon hit) ; lift = bassin relevé (m) ; pose = préfixe des poses créées.
Ancien format accepté : samples = [(temps du jeu, temps de la capture[, pieds])] (les durées de la fiche ne changent pas)."""

CLIPS = [
    # Jab (bras avant) : 144_14 « Left_Punch_Sequence002 », 3e jab (garde haute, le bassin tourne dans le coup puis revient).
    {"move": "jab", "file": "144_14", "tip": "fist_l", "t0": 3.32, "hit": 3.58, "t1": 3.82, "speed": 2.0, "pose": "cmu_jab"},
    # Direct (bras arrière) : 144_20 « Punch_Sequence », 1er direct.
    {"move": "cross", "file": "144_20", "tip": "fist_r", "t0": 1.38, "hit": 1.68, "t1": 1.95, "speed": 2.0, "pose": "cmu_cross"},
    # Chassé / coup de pied avant : 144_05 « Front_Kicking », 1er coup.
    {"move": "kick", "file": "144_05", "tip": "foot_r", "t0": 0.67, "hit": 1.22, "t1": 1.9, "speed": 2.0, "plant": "l",
     "plant_at": [(0.0, 0.72, "lr"), (1.86, 9.0, "lr")], "pose": "cmu_kick"},
    # Crochet gauche : 15_13 « boxing », grand crochet armé large (le bras part de derrière et balaie à hauteur de tête).
    {"move": "hook", "file": "15_13", "tip": "fist_l", "t0": 68.0, "hit": 68.32, "t1": 68.7, "speed": 2.0, "pose": "cmu_hook"},
    # Uppercut gauche : 15_13 « boxing », le poing part de la hanche et remonte sous le menton.
    {"move": "upper", "file": "15_13", "tip": "fist_l", "t0": 54.62, "hit": 54.95, "t1": 55.3, "speed": 2.0, "pose": "cmu_upper"},
    # High kick latéral : 135_07 « Mawashigeri » (coup de pied circulaire à hauteur de tête), 1er coup.
    {"move": "hikick", "file": "135_07", "tip": "foot_r", "t0": 0.55, "hit": 1.0, "t1": 1.45, "speed": 2.0, "plant": "l",
     "plant_at": [(0.0, 0.57, "lr")], "pose": "cmu_hikick"},
    # Shoot de foot et shoot d'objet : 10_01 « kick soccer ball » (le ballon est frappé au ras du sol à 5,0 s).
    {"move": "soccer_kick", "file": "10_01", "tip": "foot_r", "t0": 4.59, "hit": 5.0, "aim": 5.1, "t1": 5.5, "speed": 2.0,
     "plant": "l", "plant_at": [(0.0, 4.66, "lr")], "lift": 0.05, "pose": "cmu_soccer"},
    {"move": "prop_kick", "file": "10_01", "tip": "foot_r", "t0": 4.59, "hit": 5.0, "aim": 5.1, "t1": 5.5, "speed": 2.0,
     "plant": "l", "plant_at": [(0.0, 4.66, "lr")], "lift": 0.05, "pose": "cmu_propkick"},
]

# Cycles (v0.214) : course, marche et garde au repos. t0 = début d'un cycle propre, period = sa durée (cherchée par
# autocorrélation). La garde au repos est un mouvement ajouté à la garde du jeu (petits rebonds, respiration).
CYCLES = [
    {"name": "run", "file": "09_02", "t0": 0.267, "period": 0.75},
    {"name": "walk", "file": "08_02", "t0": 1.2, "period": 0.992},
    {"name": "idle", "file": "13_17", "t0": 0.45, "period": 0.775, "plant": "lr", "n": 24},
]

# Gestes avec déplacement (rm = le bassin garde son trajet ; le jeu en tire la trajectoire du héros, recalée sur le décor).
CYCLES += [
    # Enjambée (muret, rambarde) : 127_27 « Run Jump Over », appel du pied droit -> réception.
    {"name": "vault", "file": "127_27", "rm": True, "t0": 0.42, "t1": 1.22, "n": 24},
    # Roulade (esquive, réception roulée) : 127_23 « Run Dive Over Roll Run », mains au sol -> relevé.
    {"name": "roll", "file": "127_23", "rm": True, "t0": 0.62, "t1": 1.9, "n": 32},
    # Atterrissage lourd : 82_02 « Jump off ledge », du contact avec le sol à la fin de l'amorti.
    {"name": "heavy_land", "file": "82_02", "rm": True, "t0": 10.5, "t1": 10.95, "plant": "lr", "face": "hips", "n": 16},
]

# lie = il est couché dans la pose de la capture (sinon dans celle de la fiche).
# Relevés (v0.214) : la fin des fiches où il est couché (3× plus vite que la capture : relevé de combattant, pas de promeneur). keep = temps (fiche) jusqu'où il reste couché ; puis la capture.
GETUPS = [
    # À plat ventre : 139_16 « Get Up From Ground » (mains qui poussent, genoux sous lui, debout).
    {"move": "flop_land", "file": "139_16", "t0": 1.62, "t1": 3.45, "keep": 0.3, "lie": True, "speed": 3.0, "pose": "cmu_up_flop"},
    {"move": "sm_land", "file": "139_16", "t0": 1.62, "t1": 3.45, "keep": 0.42, "lie": True, "speed": 3.0, "pose": "cmu_up_sm"},
    # Sur le dos : 140_09 « Get Up From Ground Laying on Back ».
    {"move": "pd_land", "file": "140_09", "t0": 2.1, "t1": 4.48, "keep": 0.38, "speed": 3.0, "pose": "cmu_up_pd"},
    {"move": "drop_land", "file": "140_09", "t0": 2.1, "t1": 4.48, "keep": 1.6, "speed": 3.0, "pose": "cmu_up_drop"},
]

# Relevés des sbires (v0.214) : joués après le ragdoll, depuis l'endroit où il est tombé (repère = debout à la fin).
CYCLES += [
    {"name": "getup_front", "file": "139_16", "rm": True, "end_origin": True, "t0": 1.45, "t1": 3.45, "n": 24},
    {"name": "getup_back", "file": "140_09", "rm": True, "end_origin": True, "t0": 1.95, "t1": 4.48, "n": 28},
]

# Coup de poing des sbires (v0.214) : le direct 144_20 (bras qui part, impact à 53 %, retour) ; l'armé reste celui du jeu (il prévient).
CYCLES += [
    {"name": "punch", "file": "144_20", "rm": True, "t0": 1.38, "t1": 1.95, "plant": "lr", "face": "hips", "n": 24},
]

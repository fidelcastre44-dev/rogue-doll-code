"""Coups repris de captures CMU (mocap.cs.cmu.edu, usage libre). Une entrée par coup :
file = capture ; tip = membre qui frappe ; hit = instant de l'impact dans la capture (s) ;
t0 / t1 = début de l'armé et fin du retour ; samples = [(temps du jeu, temps de la capture[, pieds d'appui de cette image])] : la capture est recalée sur
le rythme de la fiche (active, cancel, end restent ceux du jeu) ; plant = pieds d'appui (« lr », « l » ou « r ») :
ils restent à leur place de garde et le bassin se place par rapport à eux comme dans la capture.
aim = instant qui donne la direction du coup (sinon hit) ; lift = bassin relevé (m) ; pose = préfixe des poses créées dans poses.tres ; end_key = dernière clé (la garde du jeu)."""

CLIPS = [
    # Jab (bras avant) : 144_14 « Left_Punch_Sequence002 », 3e jab (garde haute, le bassin tourne dans le coup puis revient).
    {"move": "jab", "file": "144_14", "tip": "fist_l", "hit": 3.58, "t0": 3.3, "t1": 3.85, "plant": "lr", "pose": "cmu_jab",
     "samples": [(0.025, 3.42), (0.05, 3.51), (0.075, 3.58), (0.1, 3.6), (0.13, 3.67), (0.17, 3.74)]},
    # Direct (bras arrière) : 144_20 « Punch_Sequence », 1er direct.
    {"move": "cross", "file": "144_20", "tip": "fist_r", "hit": 1.68, "t0": 1.40, "t1": 1.93, "plant": "lr", "pose": "cmu_cross",
     "samples": [(0.025, 1.47), (0.05, 1.57), (0.07, 1.67), (0.1, 1.70), (0.15, 1.78), (0.2, 1.87), (0.24, 1.93)]},
    # Chassé / coup de pied avant : 144_05 « Front_Kicking », 1er coup.
    {"move": "kick", "file": "144_05", "tip": "foot_r", "hit": 1.22, "t0": 0.70, "t1": 1.85, "plant": "l", "pose": "cmu_kick",
     "samples": [(0.03, 0.80), (0.06, 0.92), (0.09, 1.03), (0.13, 1.21), (0.19, 1.26), (0.25, 1.40), (0.32, 1.58), (0.39, 1.85, "lr")]},
    # High kick latéral : pas repris (135_07 « Mawashigeri » est réaliste ; le nôtre plonge le buste sous la jambe, pied plus haut que la tête).
    # Shoot de foot et shoot d'objet : 10_01 « kick soccer ball » (le ballon est frappé au ras du sol à 5,0 s).
    {"move": "soccer_kick", "file": "10_01", "tip": "foot_r", "hit": 5.0, "aim": 5.1, "t0": 4.55, "t1": 5.55, "plant": "l", "lift": 0.05, "pose": "cmu_soccer",
     "samples": [(0.04, 4.65, "lr"), (0.08, 4.75), (0.11, 4.8), (0.15, 4.9), (0.19, 5.0), (0.24, 5.1), (0.3, 5.2), (0.38, 5.35), (0.46, 5.5)]},
    {"move": "prop_kick", "file": "10_01", "tip": "foot_r", "hit": 5.0, "aim": 5.1, "t0": 4.55, "t1": 5.55, "plant": "l", "lift": 0.05, "pose": "cmu_propkick",
     "samples": [(0.04, 4.65, "lr"), (0.08, 4.75), (0.11, 4.8), (0.15, 4.9), (0.19, 5.0), (0.24, 5.1), (0.3, 5.2), (0.38, 5.35), (0.46, 5.5)]},
]

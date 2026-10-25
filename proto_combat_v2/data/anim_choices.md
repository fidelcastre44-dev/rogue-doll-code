# Animations choisies par coup (v0.2)

Instants de contact mesurés avec `tools/bake/mx_times.gd` (pic de vitesse du membre, repère du perso : devant / haut / côté).
Planches : `docs/planches/` (profil, 7 instants). Sources : Mixamo lot v2 (`v2:`), lots v0.113-114 (`v1:`).

| Coup | Animation (mx/) | Source Mixamo | Contact | Membre, où il est à l'impact |
|---|---|---|---|---|
| Jab | jab | v2 lead_jab_3 (Short Head Jab) | 0,28 s | main G, devant 0,72 m, haut 1,38 |
| Direct | cross | v2 boxing_8 (Back Hand Cross) | 0,57 s | main D, devant 1,04, haut 1,17 |
| Coude | elbow | v1 punch__elbow_punch | 0,53 s | avant-bras D, devant 1,03, haut 1,06 |
| Coup de pied retourné | spin_kick | v2 mma_kick_6 (Spinning Back Kick) | 0,95 s | pied D, devant 0,91, haut 1,44 |
| Uppercut lanceur | uppercut | v2 uppercut (Standing Left Uppercut) | 0,47 s | main G vers le haut, devant 0,69 |
| Balayette | sweep | v2 leg_sweep_2 (Front Leg Sweep) | 0,80 s | pied D, devant 0,61, au sol |
| Coup de pied poussé | bencao | v2 bencao (Capoeira Thrust Kick) | 0,50 s | pied D, devant 0,82, haut 0,96 |
| Gros crochet / chargé | hook_rear | v2 boxing_5 (Back Hand Hook) | 0,62 s | main D, devant 0,74, haut 0,98 |
| Direct plongeant (roulade + X) | cross_2 | v2 cross_punch | 0,98 s | main D, devant 0,62, haut 1,43 |
| Glissade (roulade + Y) | low_spin | v2 meia_lua_de_compasso | 1,15 s | pied D, balayage bas → haut |
| Coup de pied glissé (sprint + X) | slide | v2 running_slide | 0,45 s | pied G, devant 0,78, au sol |
| Gros coup de pied (sprint + Y) | flying_kick | v2 flying_kick (Flying Sidekick From A Run) | 0,28 s | pied G, devant 0,94, haut 1,41 |
| Jab aérien | jab | idem jab | 0,28 s | — |
| Pied latéral aérien | side_kick | v2 mma_kick_2 (Mma Side Kick) | 0,50 s | pied G, devant 0,76, haut 1,03 |
| Talon aérien | stomp | v2 stomp (Hard Floor Stomp) | 0,68 s | pied D, devant 0,87, vers le bas |
| Gros genou aérien | flying_knee | v2 flying_knee_punch_combo (coupé avant le poing) | 0,70 s | tibia D, devant 1,09, haut 1,08 |
| Coup de pied plongeant | flying_kick | idem, corps penché vers le bas | 0,28 s | — |
| Riposte | uppercut_rear | v2 boxing_6 (Back Hand Uppercut) | 0,60 s | main D, devant 0,85, haut 0,74 |
| Sbire : direct | e_cross | v2 cross_punch | 0,98 s | — |
| Sbire : coup de pied bas | e_low_kick | v2 mma_kick_3 (Mma Low Kick) | 0,50 s | pied D, devant 0,59, haut 0,76 |
| Sbire : crochet | hook_rear | v2 boxing_5 | 0,62 s | — |
| Sbire : gros coup de pied | e_round_kick | v1 kick__melee_kick_2 | 0,60 s | pied D, devant 0,89, haut 0,51 |
| Chope (prise, tenu, slam) | slam_a / slam_b | v2 hell_slammer_a / b (paire) | prise 1,0-2,4 s, slam 4,9-6,3 s, impact 5,95 s | repère commun |

Déplacement : idle fighting_idle, course standard_run, sprint sprint, marche walking_3, roulade quick_roll_to_run,
saut jumping_up / falling_idle / landing, double saut stylish_flip, dash aérien dodging_2, garde standing_block_idle,
parade inward_block. Réactions : head_hit_* (légère / moyenne / grosse, gauche / droite / de face), hit_to_body_4,
stomach_hit, big_stomach_hit, standing_react_* (dos, côtés), receiving_an_uppercut (lancé), stumble_backwards (titube),
getting_hit_backwards (renversé), getting_up / getting_up_3 (relevés), knocked_out / knocked_out_2 (K.O. sans ragdoll).

Rejetés après mesure : hook_5 et kicking_5 (pics de vitesse aberrants = glissements de capture), male_action_pose (une pose,
pas une animation), hook_punch (le poing est encore sur le côté à son pic).

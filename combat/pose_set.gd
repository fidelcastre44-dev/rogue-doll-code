@tool
class_name PoseSet
extends Resource
## Les poses du héros. guard = la garde (angles en degrés par articulation, hips_pos, pieds plantés) ;
## diffs = chaque pose d'attaque, écrite comme « la garde + ces changements ».
## Angles : x = vers l'avant (bras, jambes) ou penché en arrière (bassin, buste, tête), y = rotation sur soi ;
## bras, z positif = vers la droite du perso. foot_l / foot_r = cheville plantée (repère du perso, -Z devant), null = jambe en angles.

@export var guard: Dictionary = {}
@export var diffs: Dictionary = {}

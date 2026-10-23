@tool
class_name MoveData
extends Resource
## Un coup du héros : ses durées, sa zone de frappe, ce qu'il fait à l'ennemi, ses poses clés.
## Un fichier par coup dans res://moves/ : on le règle dans l'inspecteur de Godot, sans toucher au code.
## Les temps sont en secondes, avant la vitesse d'attaque globale (player.attack_speed).

## Nom interne (celui que le code utilise : "jab", "kick"...). Doit être le nom du fichier.
@export var id: StringName
## Nom affiché (salle de test, écran d'amélioration).
@export var display_name := ""
## Notes libres pour le game design.
@export_multiline var notes := ""

@export_group("Durées")
## Instant de l'impact : la frappe part à ce moment-là.
@export_range(0.0, 3.0, 0.005) var active := 0.1
## À partir de quand le coup suivant (combo, saut...) peut couper celui-ci.
@export_range(0.0, 3.0, 0.005) var cancel := 0.2
## Fin du coup : retour à la garde.
@export_range(0.0, 5.0, 0.005) var end := 0.4
## Roulade possible à partir de cet instant (-1 = juste après l'impact).
@export var roll_ok := -1.0

@export_group("Frappe")
## Membre qui frappe : fist_l, fist_r, foot_l, foot_r, el_l... Vide = pas de frappe directe (chope, plongeon...).
@export var tip := ""
## Rayon de la zone de frappe autour du membre (m).
@export_range(0.0, 3.0, 0.01) var radius := 0.0
## Dégâts.
@export var damage := 0.0
## Multiplie la force de projection (light_force, ou heavy_force pour un coup lourd).
@export var force_mult := 1.0
## Coup lourd : utilise heavy_force.
@export var heavy := false
## Perte d'équilibre de l'ennemi (1 = le met toujours au sol).
@export_range(0.0, 1.0, 0.05) var drop := 0.0
## Part de la projection vers le haut (négatif = vers le sol).
@export var up := 0.0
## Direction de la projection : devant, sur le côté gauche, ou sur la droite.
@export_enum("devant", "côté", "droite") var side := 0
## Passe la garde.
@export var guard_break := false

@export_group("Ressenti")
## Gel de l'image à l'impact (hitstop), en secondes.
@export var hitstop := 0.0
## Secousse d'écran à l'impact.
@export var shake := 0.0
## Élan vers l'avant pendant le coup (m/s).
@export var lunge := 0.0
## Pas en avant au départ du coup (m/s).
@export var step := 0.0

@export_group("Type et comportement")
## Coup aérien.
@export var air := false
## Coup léger aérien (enchaînable en l'air).
@export var light_air := false
## Comportements codés à part (chope, fracas, onde de choc...) : un mot par comportement.
@export var flags: PackedStringArray = []

@export_group("Animation")
## Poses clés : [temps, nom de pose, courbe facultative ("lin", "in")]. Les poses sont dans res://moves/poses.tres.
@export var keys: Array = []

## Champs présents dans l'ancien format qui ne sont pas des valeurs par défaut (pour un aller-retour exact).
@export var present: PackedStringArray = []


## Ancien format (dictionnaire du code) -> fiche.
static func from_dict(move_id: String, d: Dictionary) -> MoveData:
	var m := MoveData.new()
	m.id = move_id
	m.display_name = move_id
	m.active = d.active
	m.cancel = d.cancel
	m.end = d.end
	m.roll_ok = d.get("roll", -1.0)
	m.tip = d.get("tip", "")
	m.radius = d.get("r", 0.0)
	m.damage = d.get("dmg", 0.0)
	m.force_mult = d.get("mult", 1.0)
	m.heavy = d.get("heavy", false)
	m.drop = d.get("drop", 0.0)
	m.up = d.get("up", 0.0)
	m.side = 1 if d.get("side", false) else (2 if d.get("side_r", false) else 0)
	m.guard_break = d.get("guard_break", false)
	m.hitstop = d.get("stop", 0.0)
	m.shake = d.get("shake", 0.0)
	m.lunge = d.get("lunge", 0.0)
	m.step = d.get("step", 0.0)
	m.air = d.get("air", false)
	m.light_air = d.get("light_air", false)
	m.keys = d.keys.duplicate(true)
	var known := ["active", "cancel", "end", "roll", "tip", "r", "dmg", "mult", "heavy", "drop", "up", "side", "side_r", "guard_break",
		"stop", "shake", "lunge", "step", "air", "light_air", "keys"]
	var fl := PackedStringArray()
	for k in d:
		if not k in known:
			fl.append(k)
	m.flags = fl
	var pr := PackedStringArray()
	for k in d:
		pr.append(k)
	m.present = pr
	return m


## Fiche -> format que le code du héros lit (ATK[id].active, ATK[id].get("heavy"), ...).
func to_dict() -> Dictionary:
	var d := {"active": active, "cancel": cancel, "end": end, "lunge": lunge, "keys": keys}
	var opt := {"roll": roll_ok, "tip": tip, "r": radius, "dmg": damage, "mult": force_mult, "heavy": heavy, "drop": drop, "up": up,
		"side": side == 1, "side_r": side == 2, "guard_break": guard_break, "stop": hitstop, "shake": shake, "step": step,
		"air": air, "light_air": light_air}
	for k in opt:
		if k in present or _changed(k, opt[k]):
			d[k] = opt[k]
	for f in flags:
		d[f] = true
	return d


## Une valeur réglée dans l'inspecteur (différente du « rien ») compte même si l'ancien format ne l'avait pas.
func _changed(k: String, v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_STRING:
			return v != ""
		_:
			if k == "mult":
				return not is_equal_approx(v, 1.0) and tip != ""
			if k == "roll":
				return v >= 0.0
			return not is_zero_approx(v)

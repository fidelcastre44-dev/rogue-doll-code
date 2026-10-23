class_name BuildTiers
extends RefCounted
## Paliers de build pour la salle des builds du labo (idée de Thibaud, bilan du 22/10 : « un test stage avec différents tiers
## de build : vanilla, build tier 1, build tier 2… », pour se recentrer sur le feeling vanilla et trier les coups).
## Chaque palier AJOUTE ses réglages à ceux du palier précédent (le palier 3 contient le 2, qui contient le 1).
## Les réglages sont ceux de upgrades.gd (identifiants des améliorations). Répartition = première proposition de Claude,
## à corriger d'après la tier list du site (onglet « Tier list ») : il suffit de déplacer un identifiant d'un palier à l'autre.

## Vanilla (v0.212, décision de Paul) : seulement les coups de base ; les formes débloquables sont des loots, plongeon et double saut aussi.
## « id » = une amélioration de upgrades.gd ; « id:BOUTON » = une amélioration de bouton sur ce bouton (ex. « impact:X »).
const VANILLA := {"form_dropkick": false, "form_capoeira": false, "form_counter": false, "form_superjump": false,
	"air_heavy": "dropkick", "web": false, "wave": false, "double_jump": false, "dive": false, "tackle_up": false, "btn_ups": {}}

## Coups « À tester » de base de la v0.212 (pas des loots) : présents dans tous les paliers pour les essayer en situation.
const TRY := {"terrain": true, "sidestep": true, "trampoline": true}   # + les coups « fun », toujours gratuits

const TIERS := [
	{"id": "vanilla", "name": "Vanilla",
		"desc": "Le personnage de départ : jab, direct, uppercut, chassé, chassé sauté, chope, roulade, saut, sprint, garde. Aucune forme.",
		"ups": []},
	{"id": "t1", "name": "Palier 1",
		"desc": "Premiers loots : un 3e coup, deux formes de sortie de roulade / sprint, le double saut, la parade.",
		"ups": ["knee", "dropkick", "counter", "double_jump", "parry", "impact:X"]},
	{"id": "t2", "name": "Palier 2",
		"desc": "Milieu de partie : attaque en sprint, capoeira, super saut, grand tour, chope plongeante, Tazer, Triple Tour.",
		"ups": ["slide", "capoeira", "superjump", "swing", "air_slam", "riposte", "tazer:X", "triple:X", "air_dodge2"]},
	{"id": "t3", "name": "Palier 3",
		"desc": "Fin de partie : plaquage, bicyclette, toile d'araignée, la vague, plongeon, renvoi, défense, électrification de zone.",
		"ups": ["tackle", "bicycle", "web", "wave", "dive", "renvoi:L1", "defense:R1", "zone", "air_dodge3", "guard_gauge", "shoryu", "axe"]},
]

const UPGRADES := preload("res://upgrades.gd")


## Réglages du héros pour ce palier (cumulés depuis Vanilla).
static func settings(i: int) -> Dictionary:
	var s: Dictionary = UPGRADES.DEFAULTS.duplicate(true)
	s.merge(VANILLA.duplicate(true), true)
	s.merge(TRY, true)
	var fake := _Holder.new(s)
	for k in mini(i, TIERS.size() - 1) + 1:
		for id in TIERS[k].ups:
			var parts: PackedStringArray = id.split(":")
			var u: Array = UPGRADES.find(parts[0])
			if u.size():
				UPGRADES.apply(fake, u, parts[1] if parts.size() > 1 else "")
	return fake.d


## Nom lisible d'un élément de palier.
static func label(id: String) -> String:
	var parts: PackedStringArray = id.split(":")
	var u: Array = UPGRADES.find(parts[0])
	if u.is_empty():
		return id
	return u[3] + (" (%s)" % parts[1] if parts.size() > 1 else "")


## Liste lisible : ce que contient le palier (nouveautés du palier en premier, puis ce qui vient des paliers d'avant).
static func describe(i: int) -> String:
	var t: Dictionary = TIERS[i]
	var out: String = t.desc
	if t.ups.size():
		out += "\nNouveau à ce palier :"
		for id in t.ups:
			var u: Array = UPGRADES.find(id.split(":")[0])
			if u.size():
				out += "\n• %s — %s" % [label(id), u[4]]
	if i > 1:
		var before := []
		for k in range(1, i):
			for id in TIERS[k].ups:
				before.append(label(id))
		out += "\nDéjà là : " + ", ".join(before) + "."
	return out


## Faux héros (un dictionnaire de réglages) pour appliquer les améliorations comme en jeu.
class _Holder:
	var d: Dictionary
	func _init(dd: Dictionary) -> void:
		d = dd
	func _get(prop: StringName) -> Variant:
		return d.get(String(prop))
	func _set(prop: StringName, v: Variant) -> bool:
		d[String(prop)] = v
		return true

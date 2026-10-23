class_name MoveLibrary
extends RefCounted
## Charge toutes les fiches de coups (res://moves/*.tres) et les poses (res://moves/poses.tres), une seule fois.

const DIR := "res://moves/"
const POSES := "res://moves/poses.tres"

static var _moves: Dictionary = {}    # id -> MoveData
static var _table: Dictionary = {}    # id -> dictionnaire au format lu par le héros
static var _poses: PoseSet = null
static var _fresh := false
static var skip_overrides := false   # vrai pour les tests et les outils : les fiches seules, sans les retouches de l'éditeur    # après reload() : relire les fichiers sur le disque (pas la version en mémoire)


## Toutes les fiches, par id.
static func moves() -> Dictionary:
	if _moves.is_empty():
		for f in ResourceLoader.list_directory(DIR):
			if not f.ends_with(".tres") or DIR + f == POSES:
				continue
			var m := _load(DIR + f) as MoveData
			if m == null:
				push_error("Fiche de coup illisible : " + f)
				continue
			_moves[String(m.id)] = m
	return _moves


## Les coups au format du héros : ATK[id].active, ATK[id].keys...
static func table() -> Dictionary:
	if _table.is_empty():
		var ms := moves()
		for id in ms:
			_table[id] = (ms[id] as MoveData).to_dict()
		if not skip_overrides:
			AnimStore.apply(_table)   # versions cochées dans l'éditeur d'animation (user://), par-dessus les fiches
	return _table


static func poses() -> PoseSet:
	if _poses == null:
		_poses = _load(POSES) as PoseSet
	return _poses


## Après une modification en jeu (salle de test) : recharge depuis les fichiers.
static func reload() -> void:
	_moves.clear()
	_table.clear()
	_poses = null
	_fresh = true


static func _load(path: String) -> Resource:
	if _fresh:
		return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	return load(path)

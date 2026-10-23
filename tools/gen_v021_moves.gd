extends SceneTree
## Outil : réglages de fiches de la version 0.21 (retours de Thibaud du 22/10). Relançable.
##   ../godot --headless --path . -s tools/gen_v021_moves.gd

func moves() -> Dictionary:
	return {
		# Les jabs ne repoussent plus : ils bloquent le sbire sur place (sonné à chaque coup), sans le faire tomber.
		"jab": {"force_mult": 0.22, "drop": 0.0, "up": 0.0, "lunge": 0.4, "step": 0.0},
		"cross": {"force_mult": 0.28, "drop": 0.0, "up": 0.0, "lunge": 0.5, "step": 0.0},
		"air": {"step": 0.0},
		"air_cross": {"step": 0.0},
	}

func _initialize() -> void:
	for id in moves():
		var path := "res://moves/%s.tres" % id
		var m := load(path) as MoveData
		for k in moves()[id]:
			m.set(k, moves()[id][k])
		var pr := m.present
		for k in ["mult", "drop", "up", "lunge", "step"]:
			if not k in pr:
				pr.append(k)
		m.present = pr
		print(id, " ", ResourceSaver.save(m, path))
	quit()

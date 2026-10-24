extends SceneTree
## Exporte les données des coups (Moves.M + chope) en JSON pour le carnet de combat (site).
func _init():
	var out := {"moves": Moves.M, "grab": Moves.GRAB}
	var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	quit()

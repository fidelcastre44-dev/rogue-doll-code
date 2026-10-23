extends Node
## Ouvre / ferme le menu (Start, Tab ; B / Rond pour fermer). Tourne même quand le jeu est en pause.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_dt: float) -> void:
	var main := get_parent()
	if main.run and main.run.busy:
		return   # écran de fin de salle ouvert : Start ne fait rien
	if Input.is_action_just_pressed("menu"):
		main.toggle_menu()
	elif main.scroll.visible and Input.is_action_just_pressed("ui_cancel") and not _popup_open(main.panel):
		main.toggle_menu()


## Une liste déroulante ouverte : B la ferme elle, pas le menu.
func _popup_open(n: Node) -> bool:
	for c in n.get_children():
		if c is OptionButton and c.get_popup().visible:
			return true
	return false

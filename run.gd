extends Node
## Monde 1 : une suite de salles. Dans chaque salle, un décor tiré au hasard et une vague de sbires ;
## quand ils sont tous morts, tu choisis 1 amélioration parmi 3, puis salle suivante (un peu plus de sbires).
## Mort = K.O., on recommence le monde. Dernière salle nettoyée = monde terminé.

const Upgrades := preload("res://upgrades.gd")
const ROOMS := [2, 2, 3, 3, 4, 4, 5, 5]   # sbires par salle (8 salles = 8 améliorations sur 22)
const HEAL := 30.0                        # vie rendue après chaque salle
const CLEAR_DELAY := 1.2                  # le temps de voir tomber le dernier

var room_i := 0
var busy := false          # écran de choix / K.O. / victoire ouvert (jeu en pause)
var clear_t := 0.0
var main: Node
var ui := CanvasLayer.new()
var hud := Label.new()
var box := PanelContainer.new()
var col := VBoxContainer.new()
var title := Label.new()
var row := HBoxContainer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	main = get_parent()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.layer = 5
	add_child(ui)
	hud.position = Vector2(420, 18)
	hud.add_theme_font_size_override("font_size", 22)
	ui.add_child(hud)
	box.visible = false
	ui.add_child(box)
	box.add_child(col)
	col.add_theme_constant_override("separation", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	start_world()


func start_world() -> void:
	Upgrades.reset(main.player)
	main.player.hp = 100.0
	main.player.special = 0.0
	room_i = 0
	_enter_room()


func _enter_room() -> void:
	busy = false
	box.visible = false
	main.get_tree().paused = false
	clear_t = 0.0
	main.set_enemy_count(ROOMS[room_i])
	for e in main.enemies:
		e.can_respawn = false   # en partie, un sbire mort reste mort
	main.new_room()


func _process(dt: float) -> void:
	var alive := 0
	for e in main.enemies:
		if e.state != "dead":
			alive += 1
	hud.text = "Monde 1 — Salle %d / %d      Sbires : %d" % [room_i + 1, ROOMS.size(), alive]
	hud.position.x = main.get_viewport().get_visible_rect().size.x * 0.5 - 200.0
	if busy:
		return
	if main.player.hp <= 0:
		_screen("K.O. !  Tu es tombé en salle %d." % (room_i + 1), [["Recommencer le monde", func(): start_world()], ["Retour au salon", func(): main.open_hub()]])
		return
	if alive == 0:
		clear_t += dt
		if clear_t >= CLEAR_DELAY:
			if room_i >= ROOMS.size() - 1:
				_screen("Monde 1 terminé !  Bravo.", [["Rejouer le monde", func(): start_world()], ["Retour au salon", func(): main.open_hub()]])
			else:
				_offer()


## Fin de salle : 3 améliorations au hasard parmi celles qu'on n'a pas encore.
func _offer() -> void:
	var pool := []
	for u in Upgrades.LIST:
		if Upgrades.available(main.player, u):
			pool.append(u)
	pool.shuffle()
	var choices := []
	for u in pool.slice(0, 3):
		var rep: String = Upgrades.replaces(main.player, u)
		var text := "%s\n[%s]\n\n%s" % [u[3], u[4], u[5]]
		if rep != "":
			text += "\n\n(remplace : %s)" % rep
		choices.append([text, func(): _pick(u)])
	if choices.is_empty():
		_next()
		return
	_screen("Salle %d nettoyée !  Choisis une amélioration :" % (room_i + 1), choices)


func _pick(u: Array) -> void:
	Upgrades.apply(main.player, u)
	_next()


func _next() -> void:
	main.player.hp = minf(main.player.hp + HEAL, 100.0)
	room_i += 1
	_enter_room()


## Écran en pause, avec des boutons pilotables à la manette (croix / stick, A pour valider).
func _screen(text: String, buttons: Array) -> void:
	busy = true
	main.get_tree().paused = true
	if main.scroll.visible:
		main.toggle_menu()
		main.get_tree().paused = true
	title.text = text
	for c in row.get_children():
		c.queue_free()
	var first: Button = null
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(300, 230) if "\n" in b[0] else Vector2(320, 70)   # cartes d'amélioration / simples boutons
		btn.pressed.connect(b[1])
		row.add_child(btn)
		if first == null:
			first = btn
	box.visible = true
	var vs := main.get_viewport().get_visible_rect().size
	box.reset_size()
	box.position = (vs - box.get_combined_minimum_size()) * 0.5
	first.call_deferred("grab_focus")

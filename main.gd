extends Node3D
## Scène de test : contrôles, caméra, barre de vie, hitstop, secousse, panneau de réglages.

const CAM_OFFSET := Vector3(-4, 5.5, 4)   # isométrique en diagonale : le perso ne masque pas l'ennemi

@onready var player := $Player
@onready var enemy := $Enemy
@export var extra_enemies := 4    # sbires en plus du premier (5 en tout), en jeu normal
@export var force_extras := -1    # tests : nombre de sbires en plus imposé (-1 = jeu normal : seulement si c'est la scène lancée)
var enemies := []
var room: Node3D = null
var run: Node = null      # la partie (monde 1, salles, améliorations) ; en jeu normal seulement
var loadout := Label.new()   # liste des coups, dans le menu pause   # décor généré au hasard (en jeu normal ; pas dans les tests)
@export var force_room := false   # tests : générer quand même le décor
@export var force_run := false    # tests : lancer quand même la partie (monde 1)
@onready var cam := $Camera3D

var trauma := 0.0
var shake_t := 0.0
var noise := FastNoiseLite.new()   # secousse fluide (au lieu d'un saut aléatoire à chaque image, qui faisait « friser » l'écran)
@export var hitstop := 0.4         # durée du gel à l'impact (1 = l'ancienne, 0 = aucun)
var hitstops := 0
var base_time_scale := 1.0   # vitesse du jeu hors hitstop (la salle de test la baisse pour le ralenti)
@export var screen_shake := 0.5    # intensité de la secousse d'écran (1 = l'ancienne)
var cam_base := Vector3.ZERO
var hp_bar := ProgressBar.new()
var player_bar := ProgressBar.new()
var special_bar := ProgressBar.new()
var panel := VBoxContainer.new()
var scroll := ScrollContainer.new()
var hint := Label.new()   # aide des touches, en bas de l'écran   # le menu de réglages défile s'il est plus haut que l'écran
var cam_offset := CAM_OFFSET
var cam_zoom := 0.8          # caméra dynamique : 1 = distance d'origine ; plus près seul, plus loin quand les sbires s'étalent
var cam_lead := Vector3.ZERO
# v0.212 (idée notée sur le site : « la caméra est trop éloignée, elle doit beaucoup moins bouger ») : plus proche, plus stable.
const CAM_ZOOM_ALONE := 0.78   # aucun sbire : la caméra se rapproche du héros
const CAM_ZOOM_MIN := 0.85     # sbires tout proches
const CAM_ZOOM_MAX := 1.15     # limite : on ne recule pas plus, même si un sbire est très loin
static var zoom_pref := 1.0    # zoom réglé par le joueur (labo, menu pause) ; gardé d'une scène à l'autre
const ZOOM_PREF_MIN := 0.6
const ZOOM_PREF_MAX := 1.5
const CAM_SPREAD_MAX := 13.0   # m : un sbire plus loin que ça n'est pas pris en compte (il est à « 2 km »)


## Caméra dynamique : elle recule doucement pour garder les sbires vivants dans le cadre (avec une limite), et se rapproche
## quand il n'y a personne ; le cadre glisse un peu vers le groupe de sbires.
func _cam_target(real: float) -> Vector3:
	var spread := 0.0
	var sum := Vector3.ZERO
	var n := 0
	for e in enemies:
		if not is_instance_valid(e) or e.parts.is_empty() or e.state == "dead":
			continue
		var d: Vector3 = (e.parts.pelvis.global_position - player.global_position) * Vector3(1, 0, 1)
		if d.length() > CAM_SPREAD_MAX:
			continue
		spread = maxf(spread, d.length())
		sum += d
		n += 1
	var want := CAM_ZOOM_ALONE if n == 0 else clampf(CAM_ZOOM_MIN + spread / 9.0, CAM_ZOOM_MIN, CAM_ZOOM_MAX)
	cam_zoom = lerpf(cam_zoom, want, 1.0 - exp(-0.8 * real))
	var lead := ((sum / n) * 0.15).limit_length(1.0) if n > 0 else Vector3.ZERO
	cam_lead = cam_lead.lerp(lead, 1.0 - exp(-1.0 * real))
	return player.global_position + cam_lead + cam_offset * cam_zoom * zoom_pref


func _ready() -> void:
	noise.frequency = 1.0   # ~12 oscillations douces par seconde
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)   # tout l'écran, en restant fenêtré
	_inputs()
	player.enemy = enemy
	enemy.target = player
	enemies = [enemy]
	var extras := force_extras if force_extras >= 0 else (extra_enemies if get_tree().current_scene == self else 0)
	for i in extras:
		_spawn(TAU * (i + 1) / (extras + 1))
	player.enemies = enemies
	if force_room or get_tree().current_scene == self:
		room = Node3D.new()
		room.set_script(load("res://room.gd"))
		add_child(room)
		new_room()
	if force_run or get_tree().current_scene == self:
		run = Node.new()
		run.set_script(load("res://run.gd"))
		add_child(run)
		hint.text = hint.text.replace("   Select : nouvelle pièce", "")
	cam_base = player.global_position + CAM_OFFSET * cam_zoom
	cam.look_at_from_position(cam_base, player.global_position + Vector3.UP)

	var ui := CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS   # le menu reste pilotable quand le jeu est en pause
	var ctl := Node.new()
	ctl.set_script(load("res://menu_ctl.gd"))
	add_child(ctl)
	add_child(ui)
	hp_bar.position = Vector2(24, 20)
	hp_bar.custom_minimum_size = Vector2(360, 22)
	hp_bar.show_percentage = false
	hp_bar.max_value = enemy.MAX_HP
	hp_bar.modulate = Color(1, 0.45, 0.4)   # rouge : ennemi
	ui.add_child(hp_bar)
	player_bar.position = Vector2(24, 80)
	player_bar.custom_minimum_size = Vector2(360, 22)
	player_bar.show_percentage = false
	player_bar.modulate = Color(0.45, 0.65, 1)   # bleu : joueur
	ui.add_child(player_bar)
	special_bar.position = Vector2(24, 106)
	special_bar.custom_minimum_size = Vector2(240, 12)
	special_bar.show_percentage = false
	special_bar.max_value = player.SPECIAL_MAX
	special_bar.modulate = Color(1, 0.85, 0.2)   # jaune : jauge de spécial (R2)
	ui.add_child(special_bar)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Stick : bouger   X / Carré : poing (x3 = combo, aussi en l'air ; maintenu = balayage)   Y / Triangle : coup lourd (maintenu = attaque chargée ; en l'air : chassé sauté, maintenu = piqué)   R1 : chope   L1 : garde   A / Croix : saut   B / Rond : esquive   Select : nouvelle pièce   Start : pause, améliorations et réglages"
	hint.modulate = Color(1, 1, 1, 0.8)
	ui.add_child(hint)
	scroll.position = Vector2(24, 128)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.visible = false
	ui.add_child(scroll)
	panel.custom_minimum_size = Vector2(320, 0)
	scroll.add_child(panel)
	var lt := Label.new()
	lt.text = "Rogue Doll v%s\n— Tes coups —" % GameVersion.NUM
	panel.add_child(lt)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout.custom_minimum_size = Vector2(320, 0)
	loadout.add_theme_font_size_override("font_size", 13)
	panel.add_child(loadout)
	# Améliorations : chaque coup a sa version de base et ses versions débloquables (voir AMELIORATIONS.md).
	var title := Label.new()
	title.text = "— Améliorations —"
	panel.add_child(title)
	for u in [
		["Esquive (B / Rond)", "dodge_move", [["roll", "Roulade (base)"], ["dash", "Strafe éclair"]]],
		["Coup lourd (Y / Triangle)", "heavy_move", [["kick", "Chassé (base)"], ["hikick", "High kick latéral"], ["spinkick", "Coup de pied retourné"], ["axe", "Axe kick (salto)"], ["quake", "Frappe au sol (zone)"]]],
		["Attaque chargée (Y maintenu)", "charge_move", [["none", "Aucune (base)"], ["power", "Coup lourd chargé"], ["shoryu", "Shoryuken"], ["hadoken", "Boule d'énergie"]]],
		["Attaque en sprint (X)", "sprint_attack", [["none", "Aucune (base)"], ["slide", "Tacle glissé"], ["flop", "Plongeon pantin"]]],
		["Combo (X)", "light_move", [["base", "Jab + direct + uppercut (base)"], ["hook", "Jab + direct + crochet"], ["knee", "Jab + direct + genou volant"]]],
		["Chope (R1)", "throw_move", [["slam", "Fracas (base)"], ["swing", "Grand tour"], ["throw", "Lancer visé"]]],
	]:
		var lbl := Label.new()
		lbl.text = u[0]
		var ob := OptionButton.new()
		for c in u[2]:
			ob.add_item(c[1])
			if player.get(u[1]) == c[0]:
				ob.select(ob.item_count - 1)
		ob.item_selected.connect(func(i): player.set(u[1], u[2][i][0]))
		panel.add_child(lbl)
		panel.add_child(ob)
	var title_m := Label.new()
	title_m.text = "— Modificateurs (cumulables) —"
	panel.add_child(title_m)
	for m in [["Double saut (A en l'air)", "double_jump"], ["Plongeon (A en l'air)", "dive"], ["Chope plongeante (R1 en l'air)", "air_slam"], ["Balayage triple (X + bas : 3 tours)", "sweep_triple"], ["Parade au dernier moment (L1)", "parry"],
			["Riposte critique après parade", "riposte"], ["La garde remplit la jauge", "guard_gauge"], ["Plaquage (R1 en sprint)", "tackle_up"], ["Contre tournant : 3 tours", "counter_triple"]]:
		var cb := CheckButton.new()
		cb.text = m[0]
		cb.button_pressed = player.get(m[1])
		cb.toggled.connect(func(on): player.set(m[1], on))
		panel.add_child(cb)
	var nr := Button.new()
	nr.text = "Nouvelle pièce (Select)"
	nr.pressed.connect(func(): if room: new_room())
	panel.add_child(nr)
	if get_tree().current_scene == self:   # en jeu normal : accès direct à la salle de test des coups (F2 aussi)
		var lab := Button.new()
		lab.text = "Labo des coups (F2)"
		lab.pressed.connect(open_lab)
		panel.add_child(lab)
		var ed := Button.new()
		ed.text = "Éditeur d'animation (F3)"
		ed.pressed.connect(open_editor)
		panel.add_child(ed)
		var hub := Button.new()
		hub.text = "Retour au salon"
		hub.pressed.connect(open_hub)
		panel.add_child(hub)
	var lbl_n := Label.new()
	lbl_n.text = "Nombre d'ennemis"
	var ob_n := OptionButton.new()
	for n in range(1, 6):
		ob_n.add_item(str(n))
	ob_n.select(enemies.size() - 1)
	ob_n.item_selected.connect(func(i): set_enemy_count(i + 1))
	panel.add_child(lbl_n)
	panel.add_child(ob_n)
	var title2 := Label.new()
	title2.text = "— Réglages —"
	panel.add_child(title2)
	var zl := Label.new()
	var zs := HSlider.new()
	zs.min_value = ZOOM_PREF_MIN
	zs.max_value = ZOOM_PREF_MAX
	zs.step = 0.05
	zs.value = zoom_pref
	zl.text = "Zoom de la caméra : %.2f (petit = plus près)" % zoom_pref
	zs.value_changed.connect(func(v): zoom_pref = v; zl.text = "Zoom de la caméra : %.2f (petit = plus près)" % v)
	panel.add_child(zl)
	panel.add_child(zs)
	for s in [
		["Force poing", player, "light_force", 5.0, 100.0],
		["Force pied", player, "heavy_force", 20.0, 300.0],
		["Vitesse des attaques", player, "attack_speed", 0.6, 2.5],
		["Éjection (m/s)", enemy, "eject", 1.0, 20.0],
		["Vacillement", enemy, "sway", 0.0, 3.0],
		["Décollage uppercut (m/s)", enemy, "uplift", 0.0, 12.0],
		["Vitesse vol uppercut", enemy, "lift_speed", 0.5, 3.0],
		["Gel à l'impact", self, "hitstop", 0.0, 1.5],
		["Secousse de l'écran", self, "screen_shake", 0.0, 1.5],
		["Chaos des chutes", enemy, "chaos", 0.0, 2.0],
		["Pause entre ses attaques (s)", enemy, "attack_pause", 0.0, 3.0],
		["Coups enchaînés max", enemy, "max_chain", 1.0, 5.0],
		["Chance de garde", enemy, "block_chance", 0.0, 1.0],
		["Rebond de la chope (m/s)", enemy, "bounce", 3.0, 14.0],
		["Secousse du corps en l'air", enemy, "jolt", 0.0, 16.0],
		["Remontée par coup en l'air (m/s)", enemy, "air_pop", 0.0, 12.0],
		["Bascule du balayage (rad/s)", enemy, "trip_spin", 0.0, 15.0],
		["Écrasement du marteau (m/s)", enemy, "spike_speed", 0.0, 25.0],
		["Crispation en l'air (s)", enemy, "crisp_time", 0.0, 0.3],
		["Vrille après le coup (rad/s)", enemy, "spin", 0.0, 25.0],
		["Perte d'équilibre", enemy, "stagger_mult", 0.2, 3.0],
		["Récupération /s", enemy, "recovery", 0.1, 3.0],
	]:
		var lbl := Label.new()
		var sl := HSlider.new()
		sl.min_value = s[3]
		sl.max_value = s[4]
		sl.step = (s[4] - s[3]) / 100.0
		sl.value = s[1].get(s[2])
		lbl.text = "%s : %.2f" % [s[0], sl.value]
		sl.value_changed.connect(func(v): _set_all(s[1], s[2], v); lbl.text = "%s : %.2f" % [s[0], v])
		panel.add_child(lbl)
		panel.add_child(sl)


func _process(dt: float) -> void:
	var real := dt / maxf(Engine.time_scale, 0.001)   # la caméra vit en temps réel, même pendant le hitstop
	hp_bar.value = player.enemy.hp if player.enemy else 0.0   # la cible courante
	player_bar.value = player.hp
	special_bar.value = player.special
	# Plus la fenêtre est grande, plus on voit le monde (sans zoom) : la caméra recule en proportion de la hauteur de la fenêtre.
	var h := get_viewport().get_visible_rect().size.y
	cam_offset = CAM_OFFSET * clampf(h / 648.0, 1.0, 1.25)   # grande fenêtre : à peine plus loin (avant : jusqu'à 3×, trop loin)
	var w := get_viewport().get_visible_rect().size.x
	hint.size = Vector2(w - 48.0, 0)
	hint.position = Vector2(24, h - 16.0 - hint.get_combined_minimum_size().y)
	scroll.size = Vector2(340, maxf(hint.position.y - 138.0, 100.0))
	cam_base = cam_base.lerp(_cam_target(real), 1.0 - exp(-5.0 * real))
	trauma = maxf(trauma - real * 1.5, 0.0)
	shake_t += real
	var shake := Vector3(noise.get_noise_2d(shake_t * 12.0, 0.0), noise.get_noise_2d(0.0, shake_t * 12.0), 0) * 0.35 * trauma * trauma * screen_shake
	cam.global_position = cam_base + cam.global_basis * shake
	if Input.is_action_just_pressed("reset") and run == null:
		if room:
			new_room()   # Select : nouvelle pièce (décor tiré au hasard), sbires remis en place
		else:
			reset_enemies()



## Un réglage de sbire s'applique à tous les sbires.
func _set_all(obj: Object, prop: String, v: float) -> void:
	for o in (enemies if obj == enemy else [obj]):
		o.set(prop, v)


func _spawn(angle: float) -> void:
	var e := Node3D.new()
	e.set_script(load("res://enemy.gd"))
	e.target = player
	var a := angle + randf_range(-0.3, 0.3)
	e.position = player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 5.5)
	for prop in ["eject", "sway", "uplift", "lift_speed", "chaos", "attack_pause", "max_chain", "block_chance", "bounce", "jolt", "air_pop", "trip_spin", "spike_speed", "crisp_time", "spin", "stagger_mult", "recovery"]:
		e.set(prop, enemy.get(prop))   # mêmes réglages que les autres
	add_child(e)
	enemies.append(e)


## Nombre d'ennemis dans l'arène (menu) : on en ajoute ou on en retire tout de suite.
func set_enemy_count(n: int) -> void:
	while enemies.size() < n:
		_spawn(randf() * TAU)
	while enemies.size() > n:
		var e = enemies.pop_back()
		if player.enemy == e:
			player.attack = ""   # on le tenait peut-être
			player.enemy = enemies[0]
		e.queue_free()


## Tous les sbires neufs (reset, ou mort du joueur).
## Nouvelle pièce : le joueur au centre, les sbires autour, et un décor tiré au hasard qui laisse leurs places libres.
func new_room() -> void:
	player.global_position = Vector3(0, 0, 1.5)
	player.velocity = Vector3.ZERO
	var free := [player.global_position]
	for i in enemies.size():
		var a := TAU * i / enemies.size() + randf_range(-0.3, 0.3)
		var e = enemies[i]
		e.global_position = player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 5.0)
		e.build()
		free.append(e.global_position)
	room.generate(-1, free)


## Ouvre l'éditeur d'animation (anim_editor.tscn) à la place du jeu.
func open_editor() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://anim_editor.tscn")


## Retour au salon (hub.tscn, la scène de démarrage).
func open_hub() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://hub.tscn")


## Ouvre le labo des coups (labo.tscn) à la place du jeu.
func open_lab() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://labo.tscn")


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F2 and get_tree().current_scene == self:
		open_lab()
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_F3 and get_tree().current_scene == self:
		open_editor()


func reset_enemies() -> void:
	for e in enemies:
		e.build()


## Gel à l'impact (hitstop) + secousse. Le gel est plus court qu'avant et ralentit au lieu de figer (ça faisait des arrêts sur image).
func impact(stop: float, shake: float) -> void:
	trauma = minf(trauma + shake, 1.0)
	var d := stop * hitstop
	if d < 0.005:
		return
	hitstops += 1
	Engine.time_scale = 0.12 * base_time_scale
	await get_tree().create_timer(d, true, false, true).timeout
	hitstops -= 1
	if hitstops <= 0:   # plusieurs coups rapprochés : on ne relance le jeu qu'après le dernier gel
		Engine.time_scale = base_time_scale


func _inputs() -> void:
	if InputMap.has_action("light"):
		return   # déjà fait (on revient du salon, du labo ou de l'éditeur : les touches restent enregistrées)
	# ZQSD/J/K/R/Tab en repli clavier (touches physiques : WASD en QWERTY = ZQSD en AZERTY).
	var map := {
		"left": [_key(KEY_A), _axis(JOY_AXIS_LEFT_X, -1)],
		"right": [_key(KEY_D), _axis(JOY_AXIS_LEFT_X, 1)],
		"up": [_key(KEY_W), _axis(JOY_AXIS_LEFT_Y, -1)],
		"down": [_key(KEY_S), _axis(JOY_AXIS_LEFT_Y, 1)],
		"light": [_key(KEY_J), _btn(JOY_BUTTON_X)],
		"heavy": [_key(KEY_K), _btn(JOY_BUTTON_Y)],
		"grab": [_key(KEY_L), _btn(JOY_BUTTON_RIGHT_SHOULDER)],   # RB Xbox = R1 PlayStation
		"guard": [_key(KEY_U), _btn(JOY_BUTTON_LEFT_SHOULDER)],   # LB Xbox = L1 PlayStation
		"jump": [_key(KEY_SPACE), _btn(JOY_BUTTON_A)],   # A Xbox = croix PlayStation
		"roll": [_key(KEY_SHIFT), _btn(JOY_BUTTON_B)],   # B Xbox = rond PlayStation
		"reset": [_key(KEY_R), _btn(JOY_BUTTON_BACK)],
		"menu": [_key(KEY_TAB), _btn(JOY_BUTTON_START)],
		"sprint": [_key(KEY_CTRL), _btn(JOY_BUTTON_LEFT_STICK)],   # clic du stick gauche (L3) ; ou double tap du stick
		"special": [_key(KEY_I), _axis(JOY_AXIS_TRIGGER_RIGHT, 1)],   # R2 : coup spécial (pluie d'objets, v0.212)
	}
	for a in map:
		InputMap.add_action(a, 0.2)
		for e in map[a]:
			InputMap.action_add_event(a, e)
	# Menu à la manette : le stick gauche navigue aussi (la croix et A / B le font déjà par défaut).
	for ui in [["ui_up", JOY_AXIS_LEFT_Y, -1], ["ui_down", JOY_AXIS_LEFT_Y, 1], ["ui_left", JOY_AXIS_LEFT_X, -1], ["ui_right", JOY_AXIS_LEFT_X, 1]]:
		InputMap.action_add_event(ui[0], _axis(ui[1], ui[2]))
		InputMap.action_set_deadzone(ui[0], 0.5)
	InputMap.action_add_event("ui_accept", _btn(JOY_BUTTON_A))
	InputMap.action_add_event("ui_cancel", _btn(JOY_BUTTON_B))


## Start : menu ouvert = jeu en pause, navigation à la manette (stick ou croix, A / Croix pour valider, B / Rond pour fermer).
func toggle_menu() -> void:
	scroll.visible = not scroll.visible
	get_tree().paused = scroll.visible
	if scroll.visible:
		loadout.text = load("res://upgrades.gd").loadout(player)
		for c in panel.get_children():
			if c is OptionButton:
				c.grab_focus()
				break
	else:
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()


func _key(k: Key) -> InputEvent:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


func _axis(ax: JoyAxis, v: float) -> InputEvent:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	return e


func _btn(b: JoyButton) -> InputEvent:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e

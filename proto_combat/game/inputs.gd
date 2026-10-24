extends Node
signal pressed(action: String)
## Entrées : actions (manette + clavier ZQSD, touches physiques donc aussi WASD sur QWERTY), tampon d'appuis
## (un appui reste « valable » BUFFER secondes : on peut appuyer un poil en avance, le coup part au bon moment),
## durée de maintien, double appui pour le sprint, et lecture du stick avec zone morte.

const BUFFER := 0.15          # s : fenêtre du tampon (God of War / Hades : 150-250 ms)
const DOUBLE_TAP := 0.25      # s : double appui sur une direction = sprint
const DEAD := 0.2

# action -> [touches physiques, boutons manette]
const MAP := {
	"left": [[KEY_A, KEY_LEFT], []],
	"right": [[KEY_D, KEY_RIGHT], []],
	"up": [[KEY_W, KEY_UP], []],
	"down": [[KEY_S, KEY_DOWN], []],
	"attack": [[KEY_J], [JOY_BUTTON_X]],          # X / Carré
	"heavy": [[KEY_K], [JOY_BUTTON_Y]],           # Y / Triangle
	"grab": [[KEY_L], [JOY_BUTTON_RIGHT_SHOULDER]],  # R1 / RB
	"guard": [[KEY_U], [JOY_BUTTON_LEFT_SHOULDER]],  # L1 / LB
	"jump": [[KEY_SPACE], [JOY_BUTTON_A]],        # A / Croix
	"dodge": [[KEY_SHIFT], [JOY_BUTTON_B]],       # B / Rond
	"sprint": [[KEY_CTRL], [JOY_BUTTON_LEFT_STICK]],
	"pause": [[KEY_TAB, KEY_ESCAPE], [JOY_BUTTON_START]],
	"reset": [[KEY_R], [JOY_BUTTON_BACK]],
	"debug": [[KEY_F1], []],
	"hitboxes": [[KEY_F2], []],
	"slowmo": [[KEY_F3], []],
	"look": [[KEY_F4], []],
}

const BUTTONS := ["attack", "heavy", "grab", "guard", "jump", "dodge", "sprint"]

var pressed_at := {}      # action -> temps du dernier appui (secondes, temps réel du jeu)
var held_since := {}      # action -> début du maintien
var _last_dir_tap := {}   # direction -> temps du dernier appui (double appui)
var sprint_tap := false   # double appui détecté, valable tant que le stick reste poussé
var now := 0.0
var fake_stick := Vector2.ZERO   # tests : stick simulé
var use_fake := false
var _was_dir := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in MAP:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.5)
		for k in MAP[a][0]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
		for b in MAP[a][1]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			j.device = -1
			InputMap.action_add_event(a, j)
	# axes du stick gauche sur les directions (et la croix)
	var axes := [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]
	for ax in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[1]
		m.axis_value = ax[2]
		m.device = -1
		InputMap.action_add_event(ax[0], m)
	var pads := [["left", JOY_BUTTON_DPAD_LEFT], ["right", JOY_BUTTON_DPAD_RIGHT], ["up", JOY_BUTTON_DPAD_UP], ["down", JOY_BUTTON_DPAD_DOWN]]
	for p in pads:
		var j := InputEventJoypadButton.new()
		j.button_index = p[1]
		j.device = -1
		InputMap.action_add_event(p[0], j)


func _process(delta: float) -> void:
	now += delta
	var s := stick()
	var dir_on := s.length() > 0.6
	if dir_on and not _was_dir:
		var d := _dir_name(s)
		if _last_dir_tap.has(d) and now - _last_dir_tap[d] < DOUBLE_TAP:
			sprint_tap = true
		_last_dir_tap[d] = now
	if s.length() < 0.3:
		sprint_tap = false
	_was_dir = dir_on


func _dir_name(s: Vector2) -> String:
	if absf(s.x) > absf(s.y):
		return "r" if s.x > 0 else "l"
	return "d" if s.y > 0 else "u"


func _input(e: InputEvent) -> void:
	for a in BUTTONS + ["pause", "reset", "debug", "hitboxes", "slowmo", "look"]:
		if e.is_action_pressed(a, false):
			press(a)
		elif e.is_action_released(a):
			held_since.erase(a)


## Appui (aussi appelé par les tests).
func press(a: String) -> void:
	pressed_at[a] = now
	held_since[a] = now
	pressed.emit(a)


func release(a: String) -> void:
	held_since.erase(a)


## Un appui récent (dans le tampon) ? consume = on l'utilise (il ne resservira pas).
func buffered(a: String, consume := true, window := BUFFER) -> bool:
	if pressed_at.has(a) and now - pressed_at[a] <= window:
		if consume:
			pressed_at.erase(a)
		return true
	return false


func clear(a: String) -> void:
	pressed_at.erase(a)


func held(a: String) -> bool:
	return held_since.has(a)


func held_time(a: String) -> float:
	return now - held_since[a] if held_since.has(a) else 0.0


## Stick gauche (x droite, y bas), zone morte radiale, longueur ≤ 1.
func stick() -> Vector2:
	if use_fake:
		return fake_stick
	var v := Input.get_vector("left", "right", "up", "down", DEAD)
	return v.limit_length(1.0)

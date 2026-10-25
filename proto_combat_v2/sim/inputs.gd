class_name InputSource
extends Node
## Source des commandes : lit manettes et clavier et fabrique, à chaque image de la simulation, UNE commande par joueur
## (Cmd : stick dans le repère du monde + boutons appuyés cette image + boutons maintenus). La simulation ne lit que ces
## commandes ; en ligne, ce sont elles qui voyageront. Joueur 0 = manette 0 + clavier ; joueur 1 = manette 1.
## Au clavier, la direction est lissée pour éviter l'effet « 8 directions » (remarque de Thibaud).

const BUTTONS := ["attack", "heavy", "grab", "guard", "jump", "dodge", "sprint", "pause", "reset"]
const BIT := {"attack": 1, "heavy": 2, "grab": 4, "guard": 8, "jump": 16, "dodge": 32, "sprint": 64, "pause": 128, "reset": 256}
const KEYS := {
	"attack": [KEY_J], "heavy": [KEY_K], "grab": [KEY_L], "guard": [KEY_U], "jump": [KEY_SPACE], "dodge": [KEY_SHIFT],
	"sprint": [KEY_CTRL], "pause": [KEY_TAB, KEY_ESCAPE], "reset": [KEY_R],
}
const PAD := {
	"attack": JOY_BUTTON_X, "heavy": JOY_BUTTON_Y, "grab": JOY_BUTTON_RIGHT_SHOULDER, "guard": JOY_BUTTON_LEFT_SHOULDER,
	"jump": JOY_BUTTON_A, "dodge": JOY_BUTTON_B, "sprint": JOY_BUTTON_LEFT_STICK, "pause": JOY_BUTTON_START, "reset": JOY_BUTTON_BACK,
}
const DEAD := 0.2
const KEY_SMOOTH := 0.22      # lissage de la direction clavier (0 = brut, 1 = très lent)

var cam_yaw := 0.0            # orientation de la caméra (rad) : le stick « haut » = devant la caméra
var _held := [0, 0]           # bitmask par joueur
var _pressed := [0, 0]        # appuis depuis la dernière commande
var _key_dir := Vector2.ZERO
var fake := [null, null]      # tests : commande forcée {stick, press, held}
var enabled := true


class Cmd:
	var frame := 0
	var stick := Vector2.ZERO    # repère du monde : x = est (+X), y = sud (+Z) ; longueur ≤ 1
	var raw := Vector2.ZERO      # stick brut (écran : x droite, y bas), pour les menus
	var press := 0
	var held := 0
	func pressed(b: String) -> bool: return press & InputSource.BIT[b]
	func down(b: String) -> bool: return held & InputSource.BIT[b]
	func dup() -> Cmd:
		var c := Cmd.new()
		c.frame = frame; c.stick = stick; c.raw = raw; c.press = press; c.held = held
		return c


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventKey and not e.echo:
		for b in KEYS:
			if e.physical_keycode in KEYS[b]:
				_setbtn(0, b, e.pressed)
	elif e is InputEventJoypadButton:
		var p := _player_of(e.device)
		if p < 0:
			return
		for b in PAD:
			if e.button_index == PAD[b]:
				_setbtn(p, b, e.pressed)


func _player_of(device: int) -> int:
	var pads := Input.get_connected_joypads()
	var i := pads.find(device)
	return i if i >= 0 and i < 2 else -1


func _setbtn(p: int, b: String, on: bool) -> void:
	if on:
		if not (_held[p] & BIT[b]):
			_pressed[p] |= BIT[b]
		_held[p] |= BIT[b]
	else:
		_held[p] &= ~BIT[b]


## Appui simulé (tests, menus).
func press(p: int, b: String) -> void:
	_pressed[p] |= BIT[b]
	_held[p] |= BIT[b]


func release(p: int, b: String) -> void:
	_held[p] &= ~BIT[b]


func stick_raw(p: int) -> Vector2:
	var pads := Input.get_connected_joypads()
	var v := Vector2.ZERO
	if p < pads.size():
		var d: int = pads[p]
		v = Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if v.length() < DEAD:
			v = Vector2.ZERO
		else:
			v = v.normalized() * minf((v.length() - DEAD) / (1.0 - DEAD), 1.0)
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT): v.x = -1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT): v.x = 1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP): v.y = -1
		if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN): v.y = 1
	if p == 0 and v == Vector2.ZERO:
		var k := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): k.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): k.x += 1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): k.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): k.y += 1
		if k != Vector2.ZERO:
			k = k.normalized()
			_key_dir = k if _key_dir == Vector2.ZERO else _key_dir.lerp(k, 1.0 - KEY_SMOOTH).normalized()
			v = _key_dir
		else:
			_key_dir = Vector2.ZERO
	return v.limit_length(1.0)


## Fabrique la commande du joueur p pour l'image `frame` (appelé une fois par image par la simulation).
func command(p: int, frame: int) -> Cmd:
	var c := Cmd.new()
	c.frame = frame
	if fake[p] != null:
		var f: Dictionary = fake[p]
		c.raw = f.get("stick", Vector2.ZERO)
		c.press = _pressed[p] | int(f.get("press", 0))
		c.held = _held[p] | int(f.get("held", 0))
		f["press"] = 0
	else:
		c.raw = stick_raw(p) if enabled else Vector2.ZERO
		c.press = _pressed[p] if enabled else 0
		c.held = _held[p] if enabled else 0
	_pressed[p] = 0
	# repère du monde : « haut » du stick = direction regardée par la caméra
	c.stick = Vector2(c.raw.x, c.raw.y).rotated(-cam_yaw)
	return c


func clear(p: int) -> void:
	_pressed[p] = 0
	_held[p] = 0
	if fake[p] != null:
		fake[p] = {"stick": Vector2.ZERO, "press": 0, "held": 0}

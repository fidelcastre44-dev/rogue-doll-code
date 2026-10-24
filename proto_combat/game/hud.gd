class_name Hud
extends CanvasLayer
## Interface : titre / version, compteur de combo, frise des images du coup en cours (comme le mode entraînement d'un jeu
## de combat : vert = armé, rouge = actif, bleu = récupération), historique des entrées, aide des commandes (F1).

var game: Node
var root: Control
var title: Label
var combo_l: Label
var combo_sub: Label
var info: Label
var help: Label
var frames: Control
var hp_bar: ProgressBar
var hist: Label
var show_help := true
var show_debug := true
var _combo_scale := 1.0
var _last_combo := 0
var _hist := []
var _last_move_f := -1
var _last_move := ""
var _seq := []            # images du dernier coup (pour la frise)

const HELP := """[F1] masquer l'aide
Stick / ZQSD : courir (double appui ou L3 / Ctrl : sprint)
X / J : jab ▸ direct ▸ crochet ▸ coup retourné
   …puis Y pendant l'enchaînement : uppercut (envoie en l'air)
   …puis A : sauter le rejoindre ▸ X X X en l'air (le 3e l'écrase, il rebondit) ; Y en l'air : piqué
Y / K : coup de pied poussé ▸ Y : gros crochet plongeant
   Y maintenu : crochet chargé (relâcher pour frapper)
B / Maj : roulade (invincible au début) ▸ X : direct plongeant ▸ Y : glissade
   en l'air : petit dash ; juste avant un coup ennemi = esquive parfaite (ralenti)
L1 / U : garde ; pile au moment du coup = PARADE ▸ X : riposte
R1 / L : chope et lancer (le stick choisit la direction)
Sprint + X : glissade ; Sprint + Y : crochet volant
Start / Tab : menu (mannequins, vitesse, aide à la visée…)
Select / R : remettre la situation   F2 : zones de frappe   F3 : ralenti   F4 : perso"""


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	title = _label(22, Color(1, 1, 1, 0.9))
	title.position = Vector2(24, 16)
	combo_l = _label(96, Color(1, 0.85, 0.35))
	combo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combo_l.position = Vector2(-380, 70)
	combo_l.size = Vector2(340, 110)
	combo_l.pivot_offset = Vector2(300, 60)
	combo_sub = _label(26, Color(1, 1, 1, 0.9))
	combo_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_sub.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combo_sub.position = Vector2(-380, 172)
	combo_sub.size = Vector2(340, 40)
	help = _label(17, Color(1, 1, 1, 0.92))
	help.text = HELP
	help.position = Vector2(24, 70)
	info = _label(18, Color(1, 1, 1, 0.95))
	info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info.position = Vector2(24, -128)
	hist = _label(18, Color(0.8, 0.95, 1.0, 0.95))
	hist.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hist.position = Vector2(-520, -60)
	hist.size = Vector2(500, 30)
	hist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	frames = Control.new()
	frames.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	frames.position = Vector2(24, -64)
	frames.size = Vector2(760, 40)
	frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frames.draw.connect(_draw_frames)
	root.add_child(frames)
	hp_bar = ProgressBar.new()
	hp_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp_bar.position = Vector2(24, 50)
	hp_bar.size = Vector2(260, 10)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.9, 0.5)
	hp_bar.add_theme_stylebox_override("fill", sb)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0, 0, 0, 0.5)
	hp_bar.add_theme_stylebox_override("background", sb2)
	root.add_child(hp_bar)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func push_input(a: String) -> void:
	var sym := {"attack": "X", "heavy": "Y", "grab": "R1", "guard": "L1", "jump": "A", "dodge": "B"}
	if not sym.has(a):
		return
	_hist.append(sym[a])
	if _hist.size() > 10:
		_hist.pop_front()


func _process(dt: float) -> void:
	var h: Hero = game.hero
	title.text = "Rogue Doll — proto combat v%s   ·   mannequins : %s   ·   aide à la visée %d %%" % [game.VERSION, game.mode_name(), int(h.assist * 100)]
	help.visible = show_help
	hp_bar.value = h.hp
	if h.combo != _last_combo and h.combo > 1:
		_combo_scale = 1.35
	_last_combo = h.combo
	_combo_scale = lerpf(_combo_scale, 1.0, 1.0 - exp(-14.0 * dt))
	combo_l.visible = h.combo > 1
	combo_sub.visible = h.combo > 1
	combo_l.text = "%d" % h.combo
	combo_l.scale = Vector2.ONE * _combo_scale
	combo_sub.text = "COUPS"
	hist.text = " ".join(_hist)
	if show_debug:
		var s := "État : %s   image %d" % [h.state, h.f]
		if h.state == "attack":
			s += "   coup : %s (%s)   armé %d · actif %d · récup %d" % [h.move_id, h.phase(), h.mv.startup, h.mv.active, h.mv.recovery]
		if h.perfect_t > 0.0:
			s += "   ★ esquive parfaite : prochain coup renforcé"
		if h.riposte_t > 0.0:
			s += "   ★ RIPOSTE (X)"
		info.text = s
	info.visible = show_debug
	frames.visible = show_debug
	frames.queue_redraw()


func _draw_frames() -> void:
	var h: Hero = game.hero
	if h.state == "attack":
		_last_move = h.move_id
		_last_move_f = h.f
	if _last_move == "" or not Moves.M.has(_last_move):
		return
	var m: Dictionary = Moves.M[_last_move]
	var tot := Moves.total(m)
	var w := 8.0
	var x := 0.0
	for i in tot:
		var c := Color(0.3, 0.85, 0.4)
		if i >= m.startup:
			c = Color(1, 0.3, 0.3)
		if i >= m.startup + m.active:
			c = Color(0.35, 0.55, 1.0)
		if i == _last_move_f:
			c = Color.WHITE
		frames.draw_rect(Rect2(x, 8, w - 1, 18), c)
		x += w
	frames.draw_string(ThemeDB.fallback_font, Vector2(x + 10, 24), "%s : %d images" % [_last_move, tot], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

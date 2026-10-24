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
var show_help := false
var show_debug := true
var show_actions := true
var acts: Control
var hint_l: Label
const GLYPH := {
	"A": [Color(0.3, 0.8, 0.35), "A", "Espace"], "B": [Color(0.9, 0.3, 0.3), "B", "Maj"],
	"X": [Color(0.3, 0.55, 0.95), "X", "J"], "Y": [Color(0.95, 0.8, 0.2), "Y", "K"],
	"Ymaint": [Color(0.95, 0.8, 0.2), "Y…", "K tenu"], "L1": [Color(0.55, 0.58, 0.65), "L1", "U"],
	"R1": [Color(0.55, 0.58, 0.65), "R1", "L"], "stick": [Color(0.55, 0.58, 0.65), "◎", "ZQSD"], "": [Color(0, 0, 0, 0), "", ""],
}
var _combo_scale := 1.0
var _last_combo := 0
var _hist := []
var _last_move_f := -1
var _last_move := ""
var _seq := []            # images du dernier coup (pour la frise)

const HELP := """[F1] aide complète (masquer)
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
	acts = Control.new()
	acts.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	acts.position = Vector2(-680, -420)
	acts.size = Vector2(660, 340)
	acts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	acts.draw.connect(_draw_actions)
	root.add_child(acts)
	hint_l = _label(20, Color(1, 0.9, 0.55))
	hint_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.offset_left = 300
	hint_l.offset_right = -300
	hint_l.offset_top = 64
	hint_l.offset_bottom = 94
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
	acts.visible = show_actions
	hint_l.visible = show_actions
	if show_actions:
		hint_l.text = game.hero.situation_hint()
		acts.queue_redraw()
	var h: Hero = game.hero
	title.text = "Rogue Doll — proto combat v%s   ·   mannequins : %s   ·   aide à la visée %d %%   ·   F1 : tous les coups" % [game.VERSION, game.mode_name(), int(h.assist * 100)]
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



## Overlay « possible maintenant » : chaque bouton utile à cet instant, allumé s'il part tout de suite,
## grisé avec le nombre d'images restantes si l'appui est déjà accepté (tampon) mais pas encore ouvert.
func _draw_actions() -> void:
	var h: Hero = game.hero
	var list: Array = h.actions()
	var font := ThemeDB.fallback_font
	var y := 0.0
	var rowh := 34.0
	var bg_h := 30.0 + rowh * list.size()
	var top := acts.size.y - bg_h
	acts.draw_rect(Rect2(0, top - 6, acts.size.x, bg_h + 6), Color(0.05, 0.06, 0.09, 0.62))
	var title: String = "Possible maintenant · " + {"move": "au sol", "air": "en l'air", "attack": h.move_id, "charge": "charge", "dodge": "roulade", "airdash": "dash aérien", "guard": "garde", "grab": "chope", "hurt": "touché", "down": "à terre"}.get(h.state, h.state)
	acts.draw_string(font, Vector2(12, top + 18), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.75))
	y = top + 30
	for a in list:
		var g: Array = GLYPH.get(a.b, GLYPH[""])
		var on: bool = a.on
		var alpha := 1.0 if on else 0.38
		if a.b != "":
			var c: Color = g[0]
			var center := Vector2(28, y + rowh * 0.5)
			if a.b in ["L1", "R1", "stick", "Ymaint"]:
				acts.draw_rect(Rect2(10, y + 5, 38, rowh - 10), Color(c.r, c.g, c.b, alpha))
			else:
				acts.draw_circle(center, 13, Color(c.r, c.g, c.b, alpha))
			acts.draw_string(font, Vector2(10, y + rowh * 0.5 + 6), g[1], HORIZONTAL_ALIGNMENT_CENTER, 38, 16, Color(0.05, 0.05, 0.08, alpha))
			acts.draw_string(font, Vector2(54, y + rowh * 0.5 + 5), g[2], HORIZONTAL_ALIGNMENT_LEFT, 70, 12, Color(1, 1, 1, 0.45 * alpha + 0.1))
		var txt: String = a.t
		if not on and a.get("wait", 0) > 0:
			txt += "   · dans %d images" % a.wait
		acts.draw_string(font, Vector2(124, y + rowh * 0.5 + 6), txt, HORIZONTAL_ALIGNMENT_LEFT, acts.size.x - 130, 17, Color(1, 1, 1, alpha))
		y += rowh

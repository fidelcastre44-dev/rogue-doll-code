extends SceneTree
## Labo des coups : chaque coup du catalogue se met en situation sans erreur, et chaque coup de l'atelier
## (« À tester ») part vraiment à la manette dans sa situation (appuis simulés).
var lab
var f := 0
var fails := 0
var i := -1
var k := 0
var seen := {}
var seq := {}
var p
var waiting := 0

# id du site : [[image, action, "press"/"release"/"tap"/code], ...], coups attendus (au moins un vu)
const TESTS := {
	"mseed00": [[[5, "light", "tap"]], ["jab"]],
	"mseed58": [[[5, "light", "press"], [5, "heavy", "press"], [7, "light", "release"], [7, "heavy", "release"]], ["superman"]],
	"mseed24": [[[1, "up", "press"], [2, "", "sprint"], [12, "heavy", "tap"], [40, "up", "release"]], ["run_kick"]],
	"mseed32": [[[1, "up", "press"], [2, "", "sprint"], [75, "grab", "tap"], [175, "up", "release"]], ["tackle", "tackle_slam"]],
	"mseed53": [[[40, "jump", "tap"]], ["piledriver", "pd_land"]],
	"mseed33": [[[40, "roll", "tap"]], ["suplex"]],
	"mseed39": [[[5, "grab", "tap"]], ["hip_throw"]],
	"mseed36": [[[40, "heavy", "tap"]], ["cheese_grater_r"]],   # mur de la carte sur la droite (v0.212) ; chope + Y depuis la v0.216
	"mseed06": [[[60, "jump", "tap"], [80, "heavy", "tap"]], ["air_bigknee"]],
	"mseed19": [[[40, "heavy", "tap"], [110, "heavy", "tap"], [180, "heavy", "tap"]], ["prop_bash"]],
	"mseed16": [[[5, "roll", "tap"], [70, "light", "tap"]], ["spin_counter"]],
	"mseed25": [[[5, "roll", "tap"], [70, "heavy", "tap"]], ["capoeira"]],
	"mseed29": [[[110, "heavy", "tap"]], ["soccer_kick"]],
	"mseed28": [[[30, "heavy", "tap"]], ["prop_kick"]],
	"mseed26": [[[60, "jump", "tap"], [80, "heavy", "tap"]], ["bicycle"]],
	"mseed46": [[[5, "jump", "tap"], [25, "roll", "tap"]], ["#airdash"]],
	"mseed50": [[[80, "", "over"], [82, "jump", "tap"]], ["tramp"]],
	"mseed52": [[[5, "jump", "press"], [70, "jump", "release"]], ["super_jump", "dive_land"]],
}

func _initialize():
	lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)

func ok(c: bool, msg: String) -> void:
	print("  [ok] " if c else "  [FAIL] ", msg)
	if not c:
		fails += 1

func _next() -> void:
	i += 1
	if i >= LaboCatalog.MOVES.size():
		print("RESULTAT: ", "OK" if fails == 0 else "ECHEC (%d)" % fails)
		quit()
		return
	k = 0
	seen = {}
	lab.select(i)
	lab.set_menu(false)

func _process(_d):
	f += 1
	p = lab.player
	if f == 10:
		print("Labo des coups")
		ok(lab.menu_open and get_root().get_tree().paused, "au départ le menu est ouvert et le jeu en pause")
		lab.set_lock(1.0)
		ok(lab.player.lock_on and lab.player._lk(0, 1, 2) == 2.0, "aimantation à 1 : au maximum")
		lab.set_lock(0.0)
		ok(not lab.player.lock_on, "aimantation à 0 : désactivée")
		lab.set_extra(4, "guard")
		ok(lab.main.enemies.size() == 5, "sbires en plus : %d sbires (5 attendus)" % lab.main.enemies.size())
		lab.set_extra(0, "stand")
		ok(lab.main.enemies.size() == 1, "sans sbire en plus : %d" % lab.main.enemies.size())
		lab.set_menu(false)
		ok(not get_root().get_tree().paused and not lab.panel.visible and lab.mini.visible, "Start : menu fermé, le jeu repart, petite fiche affichée")
		ok(LaboCatalog.MOVES.size() >= 34, "catalogue : %d coups" % LaboCatalog.MOVES.size())
		_next()
		return false
	if i < 0:
		return false
	k += 1
	var m: Dictionary = LaboCatalog.MOVES[i]
	if p.attack != "":
		seen[p.attack] = true
	if p.roll >= 0 and p.roll_kind == "dash" and not p.is_on_floor():
		seen["#airdash"] = true
	if k == 3 and m.scene in ["grabbed", "grab_wall"]:
		pass
	if TESTS.has(m.id):
		for st in TESTS[m.id][0]:
			if st[0] == k:
				match st[2]:
					"press": Input.action_press(st[1])
					"release": Input.action_release(st[1])
					"tap":
						Input.action_press(st[1])
						set_meta("rel_" + st[1], k + 1)
					"sprint": p.sprinting = true
					"over":
						var e = lab.main.enemies[0]
						p.global_position = Vector3(e.parts.pelvis.global_position.x, 0, e.parts.pelvis.global_position.z) + Vector3(0.3, 0, 0)
		for a in ["light", "heavy", "grab", "jump", "roll"]:
			if has_meta("rel_" + a) and get_meta("rel_" + a) == k:
				Input.action_release(a)
				remove_meta("rel_" + a)
		if k == 240:
			var want: Array = TESTS[m.id][1]
			var got := []
			for w in want:
				if seen.has(w):
					got.append(w)
			ok(got.size() == want.size(), "%s (%s) : %s" % [m.name, m.id, "OK" if got.size() == want.size() else "vu %s, attendu %s" % [str(seen.keys()), str(want)]])
			for a in ["light", "heavy", "grab", "jump", "roll", "up"]:
				Input.action_release(a)
			_next()
	elif k == 60:
		ok(lab.main.enemies.size() >= 1, "%s (%s) : mise en situation « %s »" % [m.name, m.id, m.scene])
		_next()
	return false

extends SceneTree
## Aimantation réglable (labo) : plus elle est forte, plus loin le jab va chercher un sbire de côté.
const WANT := {"0.0/2.2": false, "0.0/3.5": false, "0.5/2.2": true, "0.5/3.5": false, "1.0/2.2": true, "1.0/3.5": true}
var fails := 0
var lab
var f := 0
var pw := [0.0, 0.5, 1.0]
var dists := [2.2, 3.5]
var i := 0
var j := 0
var k := 0
var hit := false
func _initialize():
	lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
func _process(_d):
	f += 1
	if f < 10: return false
	k += 1
	var p = lab.player
	if k == 1:
		lab.set_lock(pw[i])
		lab.select(0)
		lab.set_menu(false)
	if k == 30:
		var fw := Vector3(1, 0, -1).normalized()
		lab._dummies([[fw.rotated(Vector3.UP, deg_to_rad(40)) * dists[j], "stand"]])
		p.enemy = null
		hit = false
	if k == 60:
		Input.action_press("light")
	if k == 62: Input.action_release("light")
	if k > 60 and p.connected: hit = true
	if k == 160:
		var key := "%.1f/%.1f" % [pw[i], dists[j]]
		var good: bool = hit == WANT[key]
		if not good: fails += 1
		print("  [ok] " if good else "  [FAIL] ", "aimantation ", pw[i], ", sbire à ", dists[j], " m de côté : ", "touché" if hit else "raté")
		k = 0
		j += 1
		if j >= dists.size():
			j = 0
			i += 1
		if i >= pw.size():
			print("RESULTAT: ", "OK" if fails == 0 else "ECHEC (%d)" % fails)
			quit()
	return false

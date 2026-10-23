extends SceneTree
## Outil (v0.218) : combo Y de base en 3 coups (retour de Thibaud). Relançable.
##   ../godot --headless --path . -s tools/gen_v0218_moves.gd
## kick2 = le chassé (kick) joué de l'autre jambe : ses poses `cmu_kick_<n>` en miroir -> `mk2_<n>` ;
## kick3 = le retourné (spinkick), plus fort : il projette.

const SWAP := {"sh_l": "sh_r", "sh_r": "sh_l", "el_l": "el_r", "el_r": "el_l", "hip_l": "hip_r", "hip_r": "hip_l",
	"kn_l": "kn_r", "kn_r": "kn_l", "foot_l": "foot_r", "foot_r": "foot_l"}


func _mirror(full: Dictionary) -> Dictionary:
	var out := {}
	for k in full:
		var src: String = SWAP.get(k, k)
		var v = full[src] if full.has(src) else null
		if v == null:
			out[k] = null
		elif k == "hips_pos" or k.begins_with("foot"):
			out[k] = Vector3(-v.x, v.y, v.z)   # positions : reflétées en x
		else:
			out[k] = Vector3(v.x, -v.y, -v.z)  # rotations (Euler YXZ) : reflétées
	return out


func _initialize() -> void:
	var ps := load("res://moves/poses.tres") as PoseSet
	var kick := load("res://moves/kick.tres") as MoveData
	var keys := []
	var n := 0
	for k in kick.keys:
		var nk: Array = k.duplicate()
		if k.size() > 1 and String(k[1]).begins_with("cmu_kick_"):
			var full: Dictionary = ps.guard.merged(ps.diffs[k[1]], true)
			var name := "mk2_" + String(k[1]).trim_prefix("cmu_kick_")
			ps.diffs[name] = _mirror(full)
			nk[1] = name
			n += 1
		keys.append(nk)
	print("poses miroir : ", n, " (", ResourceSaver.save(ps, "res://moves/poses.tres"), ")")
	var k2 := kick.duplicate() as MoveData
	k2.id = &"kick2"
	k2.display_name = "Chassé de l'autre jambe (2e coup du combo Y)"
	k2.notes = "v0.218 (Thibaud) : 2e coup du combo Y, le chassé joué de la jambe gauche (poses mk2_ = cmu_kick_ en miroir, tools/gen_v0218_moves.gd)."
	k2.tip = "foot_l"
	k2.damage = 18.0
	k2.drop = 0.15
	k2.lunge = 3.0
	k2.keys = keys
	print("kick2 ", ResourceSaver.save(k2, "res://moves/kick2.tres"))
	var k3 := (load("res://moves/spinkick.tres") as MoveData).duplicate() as MoveData
	k3.id = &"kick3"
	k3.display_name = "Retourné puissant (3e coup du combo Y)"
	k3.notes = "v0.218 (Thibaud) : fin du combo Y, le retourné qui projette l'ennemi (comme spinkick, plus fort)."
	k3.damage = 26.0
	k3.force_mult = 1.8
	k3.drop = 1.0
	k3.up = 0.45
	k3.guard_break = true
	k3.hitstop = 0.14
	k3.shake = 1.2
	k3.lunge = 2.0
	for f in ["guard_break"]:
		if not f in k3.present:
			k3.present.append(f)
	print("kick3 ", ResourceSaver.save(k3, "res://moves/kick3.tres"))
	quit()

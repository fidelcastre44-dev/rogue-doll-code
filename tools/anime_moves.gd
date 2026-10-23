extends SceneTree
## Outil (v0.215) : style « combat anime » pour les animations faites main (celles qui ne viennent pas d'une capture CMU).
##   ../godot --headless --path . -s tools/anime_moves.gd            (ONLY=spinkick,axe facultatif)
## Relançable : la première fois, les clés et durées d'origine sont gardées dans tools/anime/source.json, et l'outil repart
## toujours de là.
## - Toutes les fiches reçoivent le mot « anime » : la cascade (player._cascade) fait partir le mouvement du bassin, puis le
##   buste, les épaules, la tête, les coudes.
## - Les coups (un instant d'impact entre 0 et 50 s : frappes, prises, lancers, coups aériens) : chaque pose s'écarte AMP fois plus de la garde
##   (poses copiées en `ax_<coup>_<n>`, les poses d'origine ne changent pas), et la pose d'impact reste figée HOLD s.

const AMP := 1.8
const HOLD := 0.05 * 1.35       # 0,05 s réelle (temps de fiche = réel × vitesse d'attaque)
const SRC := "res://tools/anime/source.json"
const JN := ["hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r", "hip_l", "kn_l", "hip_r", "kn_r"]


var h   # héros figé, pour mesurer où frappe une pose


func _initialize() -> void:
	_run()


func _run() -> void:
	MoveLibrary.skip_overrides = true
	h = load("res://player.gd").new()
	h.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(h)
	await process_frame
	var only := OS.get_environment("ONLY").split(",", false)
	var ms: Dictionary = MoveLibrary.moves()
	var ps: PoseSet = load("res://moves/poses.tres")
	var src := {}
	if FileAccess.file_exists(SRC):
		src = JSON.parse_string(FileAccess.get_file_as_string(SRC))
	else:
		for id in ms:
			var m: MoveData = ms[id]
			src[id] = {"keys": m.keys, "active": m.active, "cancel": m.cancel, "end": m.end, "flags": Array(m.flags)}
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/anime"))
		var f := FileAccess.open(SRC, FileAccess.WRITE)
		f.store_string(JSON.stringify(src, "\t"))
		f.close()
		print("clés d'origine gardées dans ", SRC)
	var n_strikes := 0
	var n_flag := 0
	for id in ms:
		if only.size() and not id in only:
			continue
		var m: MoveData = ms[id]
		if not src.has(id):
			continue
		var s: Dictionary = src[id]
		var keys: Array = s.keys
		if _is_capture(keys) or keys.size() < 2:
			continue
		for k in ps.diffs.keys():
			if String(k).begins_with("ax_%s_" % id):
				ps.diffs.erase(k)
		var flags := PackedStringArray(s.flags)
		if not "anime" in flags:
			flags.append("anime")
		m.flags = flags
		m.keys = keys.duplicate(true)
		m.active = s.active
		m.cancel = s.cancel
		m.end = s.end
		n_flag += 1
		var strike: bool = s.active > 0.0 and s.active < 50.0   # un coup (impact) : frappe, prise, lancer, coup aérien
		if strike:
			n_strikes += 1
			var nk := []
			var i := 0
			for k in keys:
				var kk: Array = k.duplicate()
				var pn: String = kk[1]
				if pn != "from" and pn != "guard" and not pn.begins_with("@") and ps.diffs.has(pn):
					var name := "ax_%s_%d" % [id, i]
					var orig: Dictionary = ps.guard.merged(ps.diffs[pn], true)
					var amp := _amplify(ps.guard, orig)
					if absf(float(kk[0]) - s.active) < 0.012 and m.tip != "":
						amp = _aim(orig, amp, m.tip)   # la pose d'impact frappe là où frappait l'originale
					ps.diffs[name] = _ground(amp)
					kk[1] = name
				nk.append(kk)
				i += 1
			# figé à l'impact : la clé de l'impact est tenue HOLD s, tout ce qui suit est décalé d'autant
			var hit := -1
			for j in nk.size():
				if absf(float(nk[j][0]) - s.active) < 0.012:
					hit = j
			if hit >= 0 and nk[hit][1] != "from":
				var held: Array = [s.active + HOLD, nk[hit][1], "step"]
				for j in range(hit + 1, nk.size()):
					if nk[j][0] < 50.0:
						nk[j][0] = snappedf(nk[j][0] + HOLD, 0.0001)
				nk.insert(hit + 1, held)
				m.end = snappedf(s.end + HOLD, 0.0001) if s.end < 50.0 else s.end
				m.cancel = snappedf(s.cancel + HOLD, 0.0001) if s.cancel < 50.0 else s.cancel
			m.keys = nk
		var err := ResourceSaver.save(m, "res://moves/%s.tres" % id)
		if err != OK:
			print("ERREUR ", id, " ", err)
	print("fiches en cascade : %d, coups amplifiés et figés : %d -> poses %s" % [n_flag, n_strikes, ResourceSaver.save(ps, "res://moves/poses.tres")])
	h.queue_free()
	quit()


func _is_capture(keys: Array) -> bool:
	for k in keys:
		if String(k[1]).begins_with("cmu_"):
			return true
	return false


## Pose amplifiée : chaque articulation s'écarte AMP fois plus de la garde (même axe), sans gagner plus de 70° ni dépasser 175° ;
## coudes et genoux restent entre tendus et repliés ; le bassin bouge AMP fois plus ; les pieds plantés s'écartent aussi
## (fente plus profonde), au plus de 0,45 m de plus.
func _amplify(guard: Dictionary, p: Dictionary) -> Dictionary:
	var out := p.duplicate()
	for jn in JN:
		if not p.has(jn):
			continue
		var side: String = jn.substr(jn.length() - 1)
		if (jn.begins_with("hip_") or jn.begins_with("kn_")) and p.get("foot_" + side) != null:
			continue   # jambe guidée par son pied (IK)
		var ge: Vector3 = guard.get(jn, Vector3.ZERO) if guard.get(jn) != null else Vector3.ZERO
		var pe: Vector3 = p[jn]
		if jn.begins_with("el_") or jn.begins_with("kn_"):
			var na := ge.x + (pe.x - ge.x) * AMP
			na = clampf(na, 0.0, 160.0) if jn.begins_with("el_") else clampf(na, -160.0, 0.0)
			out[jn] = Vector3(na, pe.y, pe.z)
			continue
		var g := Quaternion.from_euler(ge * (PI / 180.0))
		var q := Quaternion.from_euler(pe * (PI / 180.0))
		var d := g.inverse() * q
		var ang := d.get_angle()
		if ang < 0.001:
			continue
		var k := AMP if jn != "hips" else 1.0 + (AMP - 1.0) * 0.4
		var na := minf(minf(ang * k, ang + deg_to_rad(70)), deg_to_rad(175))
		var e := (g * Quaternion(d.get_axis().normalized(), na)).get_euler() * (180.0 / PI)
		out[jn] = _near(e, pe).snapped(Vector3.ONE * 0.1)
	var ghp: Vector3 = guard.get("hips_pos", Vector3.ZERO)
	var hp: Vector3 = p.get("hips_pos", ghp)
	hp = ghp + (hp - ghp) * AMP
	hp.y = maxf(hp.y, -0.6)
	out.hips_pos = hp.snapped(Vector3.ONE * 0.001)
	for s in ["foot_l", "foot_r"]:
		var fp = p.get(s)
		var gf = guard.get(s)
		if fp != null and gf != null:
			var dv: Vector3 = (fp - gf) * (AMP - 1.0)
			dv.y = 0.0
			out[s] = (fp + dv.limit_length(0.45)).snapped(Vector3.ONE * 0.001)
	return out


## Pose d'impact amplifiée : le membre qui frappe est tourné depuis l'épaule / la hanche pour que le poing, le pied ou le genou
## parte vers le point d'impact de la pose d'origine (sa propre allonge, donc souvent un peu plus loin).
func _aim(orig: Dictionary, amp: Dictionary, tip: String) -> Dictionary:
	var root_j := ""
	if tip.begins_with("fist"):
		root_j = "sh_" + tip.substr(tip.length() - 1)
	elif tip.begins_with("foot") or tip.begins_with("kn"):
		root_j = "hip_" + tip.substr(tip.length() - 1)
	if root_j == "" or (root_j.begins_with("hip") and amp.get("foot_" + root_j.substr(4)) != null):
		return amp
	var parent := "spine" if root_j.begins_with("sh") else "hips"
	h.apply_pose(h._resolve(orig))
	var target: Vector3 = h.j[tip].global_position - h.global_position
	var out := amp.duplicate()
	for it in 2:
		h.apply_pose(h._resolve(out))
		var piv: Vector3 = h.j[root_j].global_position - h.global_position
		var cur: Vector3 = (h.j[tip].global_position - h.global_position - piv).normalized()
		var want: Vector3 = (target - piv).normalized()
		if cur.dot(want) > 0.9999:
			break
		var pq: Quaternion = h.j[parent].global_basis.orthonormalized().get_rotation_quaternion()
		var local_rot: Quaternion = pq.inverse() * Quaternion(cur, want) * pq
		var q: Quaternion = local_rot * Quaternion.from_euler(out[root_j] * (PI / 180.0))
		out[root_j] = _near(q.get_euler() * (180.0 / PI), out[root_j]).snapped(Vector3.ONE * 0.1)
	return out


## Une pose amplifiée peut enfoncer un poing, la tête ou un pied dans le sol : on remonte le bassin d'autant.
func _ground(pz: Dictionary) -> Dictionary:
	h.apply_pose(h._resolve(pz))
	var need := 0.0
	for e in [["fist_l", 0.06], ["fist_r", 0.06], ["head", 0.12], ["foot_l", 0.02], ["foot_r", 0.02]]:
		need = maxf(need, e[1] - (h.j[e[0]].global_position.y - h.global_position.y))
	if need > 0.0:
		pz.hips_pos = (pz.get("hips_pos", Vector3.ZERO) + Vector3(0, need, 0)).snapped(Vector3.ONE * 0.001)
	return pz


## Même rotation, écrite avec les angles les plus proches de la pose d'origine (pas de tour complet entre deux clés).
func _near(e: Vector3, ref: Vector3) -> Vector3:
	var best := e
	var bd := INF
	for c in [e, Vector3(180.0 - e.x, e.y + 180.0, e.z + 180.0)]:
		var v: Vector3 = c
		v.x = ref.x + wrapf(v.x - ref.x, -180.0, 180.0)
		v.y = ref.y + wrapf(v.y - ref.y, -180.0, 180.0)
		v.z = ref.z + wrapf(v.z - ref.z, -180.0, 180.0)
		var dd := absf(v.x - ref.x) + absf(v.y - ref.y) + absf(v.z - ref.z)
		if dd < bd:
			bd = dd
			best = v
	return best

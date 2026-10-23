extends SceneTree
## Outil : intègre les coups repris de captures CMU (tools/cmu/retarget.py -> tools/cmu/cmu_moves.json).
##   python3 tools/cmu/retarget.py <dossier des .bvh> tools/cmu/cmu_moves.json
##   ../godot --headless --path . -s tools/import_cmu.gd            (ONLY=jab,cross facultatif)
## Chaque image de la capture devient une pose `<prefixe>_<n>` de poses.tres (angles YXZ en degrés, sans saut de plus de 180°
## d'une clé à l'autre) et une clé de la fiche ; les durées du coup (active, cancel, end) ne changent pas.
## Recalage : la capture est tournée et allongée pour frapper au même endroit que l'ancien coup (tools/cmu/old_tips.json).
## PROBE=old : n'écrit rien, enregistre dans tools/cmu/old_tips.json où frappe chaque coup actuel (point d'impact à l'instant
## « active ») ; PROBE=new : même relevé dans new_tips.json, pour contrôler.

const JSON_PATH := "res://tools/cmu/cmu_moves.json"
const TIPS_PATH := "res://tools/cmu/%s_tips.json"   # PROBE=old : référence (anciens coups) ; PROBE=new : contrôle
const JN := ["hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r", "hip_l", "kn_l", "hip_r", "kn_r"]


func _initialize() -> void:
	_run()


func _run() -> void:
	MoveLibrary.skip_overrides = true
	var h = load("res://player.gd").new()
	h.set_physics_process(false)
	h.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(h)
	await process_frame
	h.from = h._resolve(h._pose("guard"))
	if OS.get_environment("PROBE") != "":
		_probe(h)
		quit()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	var only := OS.get_environment("ONLY").split(",", false)
	var ps: PoseSet = load("res://moves/poses.tres")
	if only.is_empty():
		for k in ps.diffs.keys():
			if String(k).begins_with("cmu_"):
				ps.diffs.erase(k)   # import complet : les poses des coups retirés de clips.py disparaissent aussi
	var old_tips: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH % "old"))
	for id in data:
		if only.size() and not id in only:
			continue
		var m: Dictionary = data[id]
		var path := "res://moves/%s.tres" % id
		var md: MoveData = load(path)
		for k in ps.diffs.keys():
			if String(k).begins_with(m.pose + "_"):
				ps.diffs.erase(k)   # relançable : on remplace les poses déjà créées
		var fr := []
		var yaw := 0.0
		for f in m.frames:
			var F := {"t": float(f.t), "hips_pos": Vector3(f.hips_pos[0], f.hips_pos[1], f.hips_pos[2])}
			for jn in JN:
				F[jn] = Quaternion(f[jn][0], f[jn][1], f[jn][2], f[jn][3]).normalized()
			for s in ["foot_l", "foot_r"]:
				F[s] = null if f[s] == null else Vector3(f[s][0], f[s][1], f[s][2])
			fr.append(F)
		if old_tips.has(id) and m.get("align", true):
			yaw = _fit(h, fr, md, old_tips[id].pos)
		_from_guard(h, fr, m.rest, md, yaw)
		var keys := [[0.0, "from"]]
		var prev := {}
		for jn in JN:
			prev[jn] = h.GUARD.get(jn, Vector3.ZERO)   # angles proches de ceux de la garde (pas de tour complet en partant ou en revenant)
		var n := 0
		for F in fr:
			var pose := {"hips_pos": F.hips_pos.snapped(Vector3.ONE * 0.001)}
			for jn in JN:
				var e := _unwrap(F[jn].get_euler() * (180.0 / PI), prev.get(jn))
				prev[jn] = e
				pose[jn] = e.snapped(Vector3.ONE * 0.1)
			for s in ["l", "r"]:
				var fp = F["foot_" + s]
				pose["foot_" + s] = null if fp == null else fp.snapped(Vector3.ONE * 0.001)
				if fp != null:   # pied planté : le jeu calcule la jambe (IK), ses angles ne servent pas ; on garde ceux de la garde
					for jn in ["hip_" + s, "kn_" + s]:
						pose[jn] = h.GUARD.get(jn, Vector3.ZERO)
						prev[jn] = pose[jn]
			var name := "%s_%d" % [m.pose, n]
			ps.diffs[name] = pose
			keys.append([F.t, name, m.curve])
			n += 1
		keys.append([md.end, m.end_key, "inout"])
		md.keys = keys
		var lines := Array(md.notes.split("\n")).filter(func(l): return not "capture CMU" in l)
		lines.append("Animation reprise de la capture CMU %s (tools/cmu)." % m.clip)
		md.notes = "\n".join(lines).strip_edges()
		print("%s : %d clés (capture %s) -> %s" % [id, keys.size(), m.clip, ResourceSaver.save(md, path)])
	print("poses -> ", ResourceSaver.save(ps, "res://moves/poses.tres"))
	quit()


## Recale la capture sur l'ancien coup : même direction de frappe (on tourne tout le corps autour des pieds), et au moins
## la même allonge (le bassin avance et le pied avant fait un pas pendant le coup, puis reviennent) : la portée du coup ne change pas.
func _fit(h, fr: Array, md: MoveData, old: Array) -> float:
	var target := Vector3(old[0], old[1], old[2])
	var hit: Dictionary = fr[0]
	for F in fr:
		if absf(F.t - md.active) < absf(hit.t - md.active):
			hit = F
	var flat := func(v: Vector3) -> Vector2: return Vector2(v.x, v.z)
	var yaw := 0.0
	for it in 4:   # direction
		var tip := _tip(h, hit, md.tip)
		var d: float = flat.call(target).angle_to(flat.call(tip))
		yaw += d
		var rot := Basis(Vector3.UP, d)   # angle_to est mesuré dans le plan (x, z) : signe inverse d'une rotation autour de +Y
		for F in fr:
			F.hips = Quaternion(Vector3.UP, d) * F.hips
			F.hips_pos = rot * F.hips_pos
	var front := ""
	for s in ["foot_l", "foot_r"]:
		if hit[s] != null and (front == "" or hit[s].z < hit[front].z):
			front = s
	var dir: Vector2 = flat.call(target).normalized()
	var hold := md.active + (md.cancel - md.active) * 0.6
	var total := 0.0
	for it in 4:   # allonge
		var short: float = flat.call(target).length() - flat.call(_tip(h, hit, md.tip)).length()
		if short <= 0.01:
			break
		total += short
		for F in fr:
			var w := smoothstep(0.0, 1.0, F.t / md.active) if F.t <= md.active else clampf(1.0 - (F.t - hold) / maxf(md.end * 0.9 - hold, 0.01), 0.0, 1.0)
			var mv := Vector3(dir.x, 0, dir.y) * short * w
			F.hips_pos += mv
			if front != "":
				F[front] += mv * 0.7 + Vector3(0, 0.07 * sin(PI * w), 0)   # le pied avant fait un pas (il se lève en avançant et en revenant)
	print("  %s : tourné de %.0f°, allonge ajoutée %.2f m, impact %s (ancien %s)" % [md.id, rad_to_deg(yaw), total, _tip(h, hit, md.tip).snapped(Vector3.ONE * 0.01), target])
	return yaw


## Le coup part de la garde du jeu et y revient : on retire à chaque articulation l'écart entre la garde de la capture et celle
## du jeu, entièrement au début et à la fin, plus du tout à l'impact (le geste de la capture reste intact au moment qui compte).
func _from_guard(h, fr: Array, rest: Array, md: MoveData, yaw: float) -> void:
	var hold := md.active + (md.cancel - md.active) * 0.6
	var gr: Dictionary = h._resolve(h.GUARD)
	var gq := {}
	for jn in JN:
		gq[jn] = gr[jn]
	for s in gr.ik:
		var leg: Array = h._ik(gr, s)   # jambes de la garde : celles que l'IK donne aux pieds plantés
		gq["hip_" + s] = leg[0]
		gq["kn_" + s] = leg[1]
	for F in fr:
		var w := smoothstep(0.0, 1.0, F.t / md.active) if F.t <= md.active else clampf(1.0 - (F.t - hold) / maxf(md.end * 0.9 - hold, 0.01), 0.0, 1.0)
		var R: Dictionary = rest[0] if F.t <= md.active else rest[1]
		for jn in JN:
			var side: String = jn.substr(jn.length() - 1)
			if (jn.begins_with("hip_") or jn.begins_with("kn_")) and F["foot_" + side] != null:
				continue
			var g: Quaternion = gq[jn]
			var q: Array = R[jn]
			var c := g * Quaternion(q[0], q[1], q[2], q[3]).normalized().inverse()
			F[jn] = Quaternion.IDENTITY.slerp(c, 1.0 - w) * F[jn]
		var rh := Basis(Vector3.UP, yaw) * Vector3(R.hips_pos[0], R.hips_pos[1], R.hips_pos[2])
		F.hips_pos += (h.GUARD.get("hips_pos", Vector3.ZERO) - rh) * (1.0 - w)


func _tip(h, F: Dictionary, tip: String) -> Vector3:
	var r := {"hips_pos": Vector3(0, 0.9, 0) + F.hips_pos, "ik": {}}
	for jn in JN:
		r[jn] = F[jn]
	for s in ["l", "r"]:
		if F["foot_" + s] != null:
			r.ik[s] = F["foot_" + s]
	h.apply_pose(r)
	return h.global_basis.inverse() * (h.j[tip].global_position - h.global_position)


## Angles d'Euler (YXZ) les plus proches de ceux de la clé précédente : même rotation, sans tour complet entre deux clés.
func _unwrap(e: Vector3, ref) -> Vector3:
	if ref == null:
		return e
	# deux écritures possibles de la même rotation ; on préfère celle aux petits angles Y et Z (lisible dans l'éditeur, pas de
	# dérive près du blocage de cardan à X = 90°) tant qu'elle reste à moins de 165° de la clé précédente sur chaque axe
	var cands := []
	for c in [e, Vector3(180.0 - e.x, e.y + 180.0, e.z + 180.0)]:
		var v: Vector3 = c
		v.y = wrapf(v.y, -180.0, 180.0)
		v.z = wrapf(v.z, -180.0, 180.0)
		v.x = ref.x + wrapf(v.x - ref.x, -180.0, 180.0)
		cands.append(v)
	cands.sort_custom(func(a, b): return absf(a.y) + absf(a.z) < absf(b.y) + absf(b.z))
	for v in cands:
		if maxf(absf(v.x - ref.x), maxf(absf(v.y - ref.y), absf(v.z - ref.z))) < 165.0:
			return v
	var best: Vector3 = cands[0]
	var bd := INF
	for c in cands:
		var v: Vector3 = c
		v.y = ref.y + wrapf(v.y - ref.y, -180.0, 180.0)
		v.z = ref.z + wrapf(v.z - ref.z, -180.0, 180.0)
		var d := absf(v.x - ref.x) + absf(v.y - ref.y) + absf(v.z - ref.z)
		if d < bd:
			bd = d
			best = v
	return best


func _probe(h) -> void:
	var tab: Dictionary = MoveLibrary.table()
	var out := {}
	for id in tab:
		var a: Dictionary = tab[id]
		if a.get("tip", "") == "" or not a.has("keys") or a.keys.is_empty():
			continue
		h.apply_pose(h.pose_at(id, a.active))
		var p: Vector3 = h.global_basis.inverse() * (h.j[a.tip].global_position - h.global_position)
		out[id] = {"tip": a.tip, "pos": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]}
	var f := FileAccess.open(TIPS_PATH % OS.get_environment("PROBE"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t", true))
	print("points d'impact : ", out.size())

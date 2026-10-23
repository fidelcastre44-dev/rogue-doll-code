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
	if data.has("_cycles") and only.is_empty():
		_cycles(h, data._cycles)
	for id in data:
		if id == "_cycles" or (only.size() and not id in only):
			continue
		var m: Dictionary = data[id]
		var path := "res://moves/%s.tres" % id
		var md: MoveData = load(path)
		for k in ps.diffs.keys():
			if String(k).begins_with(m.pose + "_"):
				ps.diffs.erase(k)   # relançable : on remplace les poses déjà créées
		if m.get("keep") != null:   # relevé : les clés où il est couché restent, la capture prend la suite
			var kept := []
			for k in md.keys:
				if k[0] <= m.keep and k[1] != "guard" and (not m.get("lie", false) or k[1] == "from"):
					kept.append(k)
			var old_end := md.end
			md.end = m.timing.end
			if md.cancel < 50.0:
				md.cancel = snappedf(md.cancel + (md.end - old_end), 0.001)
			md.keys = kept
		elif m.get("timing") != null:   # rythme de la capture : la fiche prend ses durées (annulation au même rapport qu'avant)
			var r: float = m.cancel_r if m.get("cancel_r") != null else (md.cancel - md.active) / maxf(md.end - md.active, 0.001)
			md.active = m.timing.active
			md.end = m.timing.end
			md.cancel = snappedf(md.active + m.timing.get("hold", 0.0) + r * (md.end - md.active - m.timing.get("hold", 0.0)), 0.001)
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
			yaw = _fit(h, fr, md, old_tips[id].pos, m.get("reach", false))
		if m.rest != null:
			_from_guard(h, fr, m.rest, md, yaw)
		if m.get("amp", 1.0) > 1.0:
			_exaggerate(h, fr, m.amp)
			if old_tips.has(id) and m.get("align", true):
				_fit(h, fr, md, old_tips[id].pos, false, deg_to_rad(20), true)   # l'amplitude a pu dévier un peu la frappe : on la recale (20° au plus)
				var aim: Array = old_tips[id].pos.duplicate()
				if m.has("aim_y"):
					aim[1] = m.aim_y
				_aim(h, fr, md, Vector3(aim[0], aim[1], aim[2]))
		if m.get("keep") != null:
			_above_ground(h, fr)
		var keys := [[0.0, "from"]] if m.get("keep") == null else md.keys.duplicate()
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


## Cycles (course, marche, garde au repos) -> combat/cycles_data.gd (CycleData) : angles YXZ en degrés de chaque image.
## La garde au repos est « additive » : on n'enregistre que l'écart à sa pose moyenne (petits rebonds, respiration), ajouté
## à la garde du jeu ; la dérive entre la fin et le début est retirée pour que la boucle ne saute pas.
func _cycles(h, cyc: Dictionary) -> void:
	var out := "class_name CycleData\n## Généré par tools/import_cmu.gd (captures CMU) : ne pas modifier à la main.\n\n"
	for name in cyc:
		var c: Dictionary = cyc[name]
		var frames := []
		for f in c.frames:
			var F := {"hips_pos": Vector3(f.hips_pos[0], f.hips_pos[1], f.hips_pos[2])}
			for jn in JN:
				F[jn] = Quaternion(f[jn][0], f[jn][1], f[jn][2], f[jn][3]).normalized()
			frames.append(F)
		var rows := []
		if c.get("additive", false):
			var mean := {}
			var mhp := Vector3.ZERO
			for jn in JN:
				var acc := Vector4.ZERO
				var q0: Quaternion = frames[0][jn]
				for F in frames:
					var q: Quaternion = F[jn]
					if q.dot(q0) < 0.0:
						q = -q
					acc += Vector4(q.x, q.y, q.z, q.w)
				acc = acc.normalized()
				mean[jn] = Quaternion(acc.x, acc.y, acc.z, acc.w)
			for F in frames:
				mhp += F.hips_pos / frames.size()
			var n := frames.size()
			var first := {}
			var last := {}
			for i in n:
				var row := {"hips_pos": frames[i].hips_pos - mhp}
				for jn in JN:
					row[jn] = (frames[i][jn] * mean[jn].inverse()).get_euler() * (180.0 / PI)
				rows.append(row)
			for k in rows[0]:   # boucle sans saut : la dérive fin -> début est répartie sur le cycle
				var drift = rows[n - 1][k] - rows[0][k]
				for i in n:
					rows[i][k] -= drift * (float(i) / float(n))
				var avg = rows[0][k] * 0.0
				for i in n:
					avg += rows[i][k] / float(n)
				for i in n:
					rows[i][k] -= avg   # écart moyen nul : la garde du jeu reste la pose moyenne
		else:
			var prev := {}
			for jn in JN:
				prev[jn] = h.GUARD.get(jn, Vector3.ZERO)
			for i in frames.size():
				var F: Dictionary = frames[i]
				var row := {"hips_pos": F.hips_pos}
				for jn in JN:
					var e := _unwrap(F[jn].get_euler() * (180.0 / PI), prev[jn])
					prev[jn] = e
					row[jn] = e
				if c.get("planted", false):
					for s in ["foot_l", "foot_r"]:
						var fp = c.frames[i][s]
						if fp != null:
							row[s] = Vector3(fp[0], fp[1], fp[2])
				rows.append(row)
		var root := []
		if c.get("rm", false) and not c.get("planted", false) and not c.get("end_origin", false):
			# trajectoire : le héros suit le bassin de la capture (au sol au départ) ; la pose garde la hauteur du bassin du départ
			var hp0: Vector3 = rows[0].hips_pos
			for row in rows:
				root.append(Vector3(row.hips_pos.x, row.hips_pos.y - hp0.y, row.hips_pos.z))
				row.hips_pos = Vector3(0, hp0.y, 0)
		var txt := []
		for row in rows:
			var parts := []
			for k in ["hips_pos"] + JN + ["foot_l", "foot_r"]:
				if not row.has(k):
					continue
				var v: Vector3 = row[k]
				parts.append("\"%s\": Vector3(%s, %s, %s)" % [k, snappedf(v.x, 0.001 if not k in JN else 0.01), snappedf(v.y, 0.001 if not k in JN else 0.01), snappedf(v.z, 0.001 if not k in JN else 0.01)])
			txt.append("\t{" + ", ".join(parts) + "},")
		out += "## %s : capture CMU %s, foulée %.2f m par cycle, période %.3f s\n" % [name, c.clip, c.stride, c.period]
		out += "const %s_STRIDE := %s\nconst %s_PERIOD := %s\nconst %s := [\n%s\n]\n\n" % [name.to_upper(), snappedf(c.stride, 0.001), name.to_upper(), c.period, name.to_upper(), "\n".join(txt)]
		if not root.is_empty():
			var rt := []
			for v in root:
				rt.append("Vector3(%s, %s, %s)" % [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)])
			out += "const %s_ROOT := [%s]\n\n" % [name.to_upper(), ", ".join(rt)]
	var f := FileAccess.open("res://combat/cycles_data.gd", FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("cycles -> combat/cycles_data.gd : ", cyc.keys())


## Recale la capture sur l'ancien coup : même direction de frappe (on tourne tout le corps autour des pieds), et au moins
## la même allonge (le bassin avance et le pied avant fait un pas pendant le coup, puis reviennent) : la portée du coup ne change pas.
func _fit(h, fr: Array, md: MoveData, old: Array, reach: bool, max_turn := PI, bell := false) -> float:
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
		d = clampf(yaw + d, -max_turn, max_turn) - yaw
		yaw += d
		for F in fr:
			# bell : seulement autour de l'impact (le départ et la fin restent sur la garde)
			var k := 1.0
			if bell:
				var hold := md.active + (md.cancel - md.active) * 0.5
				k = smoothstep(0.0, md.active, F.t) if F.t <= md.active else 1.0 - smoothstep(hold, md.end * 0.9, F.t)
			F.hips = Quaternion(Vector3.UP, d * k) * F.hips   # angle_to est mesuré dans le plan (x, z) : signe inverse d'une rotation autour de +Y
			F.hips_pos = Basis(Vector3.UP, d * k) * F.hips_pos
	var front := ""
	for s in ["foot_l", "foot_r"]:
		if hit[s] != null and (front == "" or hit[s].z < hit[front].z):
			front = s
	var dir: Vector2 = flat.call(target).normalized()
	var hold := md.active + (md.cancel - md.active) * 0.6
	var total := 0.0
	for it in (4 if reach else 0):   # allonge (désactivée depuis la v0.214 : geste pur, la portée suit la capture)
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


## Style combat anime (v0.215) : chaque articulation s'écarte `amp` fois plus de la garde (bassin, buste, épaules, hanches,
## position du bassin). Coudes et genoux restent entre tendus et repliés ; une rotation ne gagne pas plus de 70° et reste
## sous 175° (pas de membre qui passe à travers le corps). Les jambes plantées (IK) ne bougent pas.
func _exaggerate(h, fr: Array, amp: float) -> void:
	var gr: Dictionary = h._resolve(h.GUARD)
	var gq := {}
	for jn in JN:
		gq[jn] = gr[jn]
	for s in gr.ik:
		var leg: Array = h._ik(gr, s)
		gq["hip_" + s] = leg[0]
		gq["kn_" + s] = leg[1]
	var ghp: Vector3 = h.GUARD.get("hips_pos", Vector3.ZERO)
	for F in fr:
		for jn in JN:
			var side: String = jn.substr(jn.length() - 1)
			if (jn.begins_with("hip_") or jn.begins_with("kn_")) and F["foot_" + side] != null:
				continue
			var g: Quaternion = gq[jn]
			var q: Quaternion = F[jn]
			if jn.begins_with("el_") or jn.begins_with("kn_"):   # charnière : un seul angle, autour de X
				var a0 := wrapf(2.0 * atan2(g.x, g.w), -PI, PI)
				var a1 := wrapf(2.0 * atan2(q.x, q.w), -PI, PI)
				var na := a0 + (a1 - a0) * amp
				na = clampf(na, 0.0, deg_to_rad(160)) if jn.begins_with("el_") else clampf(na, deg_to_rad(-160), 0.0)
				F[jn] = Quaternion(Vector3.RIGHT, na)
				continue
			var d := g.inverse() * q
			var ang := d.get_angle()
			if ang < 0.001:
				continue
			var k := amp if jn != "hips" else 1.0 + (amp - 1.0) * 0.4   # bassin : moins (sinon il tourne le dos à l'ennemi)
			var na := minf(minf(ang * k, ang + deg_to_rad(70)), deg_to_rad(175))
			F[jn] = g * Quaternion(d.get_axis().normalized(), na)
		var hp: Vector3 = ghp + (F.hips_pos - ghp) * amp
		hp.y = maxf(hp.y, -0.55)
		F.hips_pos = hp


## Vise : autour de l'impact, le membre qui frappe (bras ou jambe) est tourné depuis l'épaule / la hanche pour que le poing
## ou le pied parte vers la cible (direction et hauteur de l'ancien coup), à sa propre allonge. Dosé en cloche autour de l'impact.
func _aim(h, fr: Array, md: MoveData, target: Vector3) -> void:
	var side: String = md.tip.substr(md.tip.length() - 1)
	var root_j: String = ("sh_" if md.tip.begins_with("fist") else "hip_") + side
	var parent: String = "spine" if root_j.begins_with("sh") else "hips"
	var hold := md.active + (md.cancel - md.active) * 0.5
	for F in fr:
		var w := smoothstep(md.active * 0.35, md.active, F.t) if F.t <= md.active else 1.0 - smoothstep(md.active, hold + 0.1, F.t)
		if w <= 0.0:
			continue
		for it in 2:
			_tip(h, F, md.tip)
			var piv: Vector3 = h.global_basis.inverse() * (h.j[root_j].global_position - h.global_position)
			var tipp: Vector3 = h.global_basis.inverse() * (h.j[md.tip].global_position - h.global_position)
			var cur := (tipp - piv).normalized()
			# cible : là où frappait l'ancien coup (les coups de pied : au moins à 80 % de l'allonge de la jambe)
			var limb := 0.6 if root_j.begins_with("sh") else 0.88
			var flat := Vector2(target.x, target.z)
			var reach_h := flat.length() if root_j.begins_with("sh") else maxf(flat.length(), Vector2(piv.x, piv.z).length() + limb * 0.8)   # pieds : au moins 80 % de l'allonge
			var tgt := Vector3(flat.normalized().x * reach_h, target.y, flat.normalized().y * reach_h)
			var want := (tgt - piv).normalized()
			if cur.dot(want) > 0.9999:
				break
			var rot := Quaternion(cur, want)
			var pb: Basis = (h.global_basis.inverse() * h.j[parent].global_basis).orthonormalized()
			var pq := pb.get_rotation_quaternion()
			var local_rot := pq.inverse() * rot * pq   # la même rotation, dans le repère du parent
			F[root_j] = Quaternion.IDENTITY.slerp(local_rot, w) * F[root_j]


## Relevés : nos bras sont plus longs que ceux de la capture (rapport aux jambes) ; quand une main, la tête ou un pied passe
## sous le sol, on remonte le corps d'autant (image par image).
func _above_ground(h, fr: Array) -> void:
	for F in fr:
		var need := 0.0
		for e in [["fist_l", 0.06], ["fist_r", 0.06], ["head", 0.12], ["foot_l", 0.02], ["foot_r", 0.02]]:
			need = maxf(need, e[1] - _tip(h, F, e[0]).y)
		F.hips_pos.y += need


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

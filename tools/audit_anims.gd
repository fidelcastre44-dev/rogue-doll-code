extends SceneTree
## Outil : audit chiffré des animations (aucun rendu). ../godot --headless --path . -s tools/audit_anims.gd --fixed-fps 120
## A. Chaque fiche de coup, échantillonnée à 120 images/s sur un héros figé : à-coups (un membre qui saute d'une image à l'autre),
##    membres sous le sol, pieds qui glissent alors qu'ils sont posés, clés qui tournent de plus de 170° d'un coup.
## B. Les déplacements de la carte, joués pour de vrai dans le labo : mains par rapport au rebord, pieds dans le bloc, hauteur du bassin.

const EFF := ["fist_l", "fist_r", "foot_l", "foot_r", "head"]
var out := []


func _initialize() -> void:
	_run()


func _run() -> void:
	var h = load("res://player.gd").new()
	h.set_physics_process(false)
	h.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(h)
	await process_frame
	h.from = h._resolve(h._pose("guard"))
	var tab: Dictionary = MoveLibrary.table()
	var rows := []
	for id in tab:
		var a: Dictionary = tab[id]
		var end_t: float = minf(a.end, 3.0)
		if end_t <= 0.0 or not a.has("keys") or a.keys.is_empty():
			continue
		var prev := {}
		var qprev := {}
		var peak := {}
		var pops := 0.0
		var pop_who := ""
		var under := 0.0
		var slide := {"foot_l": 0.0, "foot_r": 0.0}
		var t := 0.0
		var dt := 1.0 / 120.0
		while t <= end_t:
			h.apply_pose(h.pose_at(id, t))
			for jn in ["hips", "spine", "head", "sh_l", "el_l", "sh_r", "el_r"]:
				var q: Quaternion = h.j[jn].quaternion
				if qprev.has(jn):
					var w: float = qprev[jn].angle_to(q)
					if w > peak.get(jn, [0.0, 0.0])[0]:
						peak[jn] = [w, t]
				qprev[jn] = q
			var cur := {}
			for e in EFF:
				cur[e] = h.global_basis.inverse() * (h.j[e].global_position - h.global_position)
			for e in EFF:
				if prev.has(e):
					var d: float = cur[e].distance_to(prev[e])
					if e != a.get("tip", "") and d > pops:
						pops = d
						pop_who = "%s à %.2f s" % [e, t]
				under = minf(under, cur[e].y)
			for f in ["foot_l", "foot_r"]:
				if prev.has(f) and cur[f].y < 0.06 and prev[f].y < 0.06:
					slide[f] += Vector2(cur[f].x - prev[f].x, cur[f].z - prev[f].z).length()
			prev = cur
			t += dt
		var flips := []
		var keys: Array = a.keys
		for i in range(1, keys.size()):
			var k0 = keys[i - 1][1]
			var k1 = keys[i][1]
			if k0 == "from" or k1 == "from":
				continue
			var p0: Dictionary = h._pose(k0)
			var p1: Dictionary = h._pose(k1)
			for jn in h.JOINTS:
				var v0: Vector3 = p0.get(jn, Vector3.ZERO) if p0.get(jn) != null else Vector3.ZERO
				var v1: Vector3 = p1.get(jn, Vector3.ZERO) if p1.get(jn) != null else Vector3.ZERO
				var dmax: float = maxf(absf(v1.x - v0.x), maxf(absf(v1.y - v0.y), absf(v1.z - v0.z)))
				if dmax > 170.0:
					flips.append("%s %s→%s" % [jn, k0, k1])
		var issues := []
		# cascade : si presque tout le haut du corps atteint sa vitesse maximale à la même image, il bouge « d'un bloc »
		var times := []
		for jn in peak:
			if peak[jn][0] > deg_to_rad(1.0):
				times.append(snappedf(peak[jn][1], dt))
		var same := 0
		for x in times:
			same = maxi(same, times.count(x))
		if times.size() >= 4 and same >= times.size() - 1:
			issues.append("tout bouge d'un bloc (%d articulations sur %d au même instant)" % [same, times.size()])
		if pops > 0.09:
			issues.append("à-coup %.0f cm/image (%s)" % [pops * 100.0, pop_who])
		if under < -0.06:
			issues.append("membre %.0f cm sous le sol" % (-under * 100.0))
		for f in slide:
			if slide[f] > 0.12:
				issues.append("%s glisse de %.0f cm posé au sol" % [f, slide[f] * 100.0])
		if flips.size():
			issues.append("rotation > 170° : " + ", ".join(flips.slice(0, 3)))
		rows.append([issues.size(), id, issues])
	rows.sort_custom(func(x, y): return x[0] > y[0])
	print("=== A. Fiches de coups (%d) ===" % rows.size())
	var clean := []
	for r in rows:
		if r[0] == 0:
			clean.append(r[1])
		else:
			print("- %s : %s" % [r[1], " ; ".join(r[2])])
	print("Sans défaut mesuré (%d) : %s" % [clean.size(), ", ".join(clean)])
	h.queue_free()
	await _gait()
	await _foes()
	await _loco()
	quit()


## C. Marche et course jouées pour de vrai (stick à fond ou à moitié) : de combien glisse un pied posé au sol (patinage).
func _gait() -> void:
	var lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
	for i in 10:
		await physics_frame
	lab.set_menu(false)
	var p = lab.player
	print("=== C. Marche et course ===")
	for case in [["marche", 0.45, false], ["course", 1.0, false], ["sprint", 1.0, true]]:
		p.global_position = Vector3(-6, 0, 6)
		p.velocity = Vector3.ZERO
		for i in 20:
			await physics_frame
		Input.action_press("left", case[1])
		if case[2]:
			p.sprinting = true
		var slide := {"foot_l": 0.0, "foot_r": 0.0}
		var last := {}
		var n := 0
		var vmax := 0.0
		for i in 150:
			await physics_frame
			if case[2]:
				p.sprinting = true
			if i < 40:
				continue
			vmax = maxf(vmax, Vector2(p.velocity.x, p.velocity.z).length())
			var low: String = "foot_l" if p.j.foot_l.global_position.y < p.j.foot_r.global_position.y else "foot_r"   # pied d'appui
			for f in slide:
				var fp: Vector3 = p.j[f].global_position
				if f == low and last.has(f) and last.get("low") == f and fp.y < p.global_position.y + 0.06:
					slide[f] += Vector2(fp.x - last[f].x, fp.z - last[f].z).length()
				last[f] = fp
			last["low"] = low
			n += 1
		Input.action_release("left")
		p.sprinting = false
		print("- %s (%.1f m/s) : pied d'appui qui glisse de %.0f et %.0f cm en %.1f s" % [case[0], vmax, slide.foot_l * 100.0, slide.foot_r * 100.0, n / 120.0])
	lab.queue_free()
	await process_frame


## B. Déplacements joués pour de vrai dans le labo (physique, sans rendu).
func _loco() -> void:
	var lab = load("res://labo.tscn").instantiate()
	root.add_child(lab)
	for i in 10:
		await physics_frame
	var p = lab.player
	print("=== B. Déplacements de la carte ===")
	for case in [["mv_hang", ["up"], 26, true, 70], ["mv_mantle", ["up", "left"], 60, true, 60], ["mv_vault", ["up"], 0, false, 110], ["mv_glide", ["down", "right"], 24, false, 150], ["mv_skid", ["up"], 10, false, 100], ["mv_landroll", ["down", "right"], 20, true, 120]]:
		var id: String = case[0]
		for k in LaboCatalog.MOVES.size():
			if LaboCatalog.MOVES[k].id == id:
				lab.select(k)
		lab.set_menu(false)
		for i in 30:
			await physics_frame
		for a in case[1]:
			Input.action_press(a)
		for i in case[2]:
			await physics_frame
		if id in ["mv_vault", "mv_skid"]:
			p.sprinting = true
			for i in 15:
				await physics_frame
		if id in ["mv_glide", "mv_skid"]:
			Input.action_press("roll")
		if case[3]:
			Input.action_press("jump")
			await physics_frame
			await physics_frame
			Input.action_release("jump")
		var st := {}
		var climb_tapped := false
		for i in case[4] + 120:
			await physics_frame
			var s: String = p.lc.state
			if s == "":
				continue
			if not st.has(s):
				st[s] = {"n": 0, "hand_gap": 0.0, "foot_in": 0.0, "hips_min": 9.0, "hips_max": -9.0, "pop": 0.0, "last": {}}
			var r: Dictionary = st[s]
			r.n += 1
			var top: float = p.lc.top
			if s in ["hang", "climb", "mantle", "vault"]:
				var hy: float = (p.j.fist_l.global_position.y + p.j.fist_r.global_position.y) * 0.5
				if s == "hang" or (s == "climb" and p.lc.t < 0.25):
					r.hand_gap = maxf(r.hand_gap, absf(hy - top))
				for f in ["foot_l", "foot_r"]:
					var fp: Vector3 = p.j[f].global_position
					var into: float = -(fp - (p.lc.a0 if s != "vault" else p.global_position)).dot(p.lc.wall_n)
					if fp.y < top - 0.05 and into > 0.4:
						r.foot_in = maxf(r.foot_in, top - fp.y)
			var hip: float = p.j.hips.global_position.y - p.global_position.y
			r.hips_min = minf(r.hips_min, hip)
			r.hips_max = maxf(r.hips_max, hip)
			for e in EFF:
				var gp: Vector3 = p.j[e].global_position - p.global_position
				if r.last.has(e):
					r.pop = maxf(r.pop, gp.distance_to(r.last[e]))
				r.last[e] = gp
			if s == "hang" and not climb_tapped and r.n > 40:
				climb_tapped = true
				Input.action_press("jump")
				await physics_frame
				Input.action_release("jump")
		for a in ["up", "down", "left", "right", "roll", "jump"]:
			Input.action_release(a)
		for s in st:
			var r: Dictionary = st[s]
			var notes := ["%d images" % r.n, "bassin de %.2f à %.2f m" % [r.hips_min, r.hips_max]]
			if r.hand_gap > 0.0:
				notes.append("mains à %.0f cm du rebord au pire" % (r.hand_gap * 100.0))
			if r.foot_in > 0.0:
				notes.append("pieds %.0f cm dans le bloc" % (r.foot_in * 100.0))
			if r.pop > 0.09:
				notes.append("à-coup %.0f cm/image" % (r.pop * 100.0))
			print("- %s / %s : %s" % [id, s, " ; ".join(notes)])


## D. Sbires : relevés capturés (couché sur le ventre / sur le dos) et marche. Membres sous le sol, à-coups, pieds qui glissent.
func _foes() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	var e = main.enemy
	main.player.global_position = Vector3(0, 0, 6)
	print("=== D. Sbires ===")
	for k in 4:
		e.global_position = Vector3(0, 0, 0)
		e.build()
		e.ai_on = false
		for i in 5:
			await physics_frame
		# renversé : sur le dos (poussé vers l'arrière) ou sur le ventre (poussé vers l'avant)
		var dir := Vector3(0, 0, 1) if k % 2 == 0 else Vector3(0, 0, -1)
		e.hp = 999.0
		e.hit(e.parts.chest, (dir * 14.0 + Vector3.UP * 2.0) * (1.0 + k * 0.3), e.parts.chest.global_position, 1.0, 1.0)
		var seen := {}
		var under := 0.0
		var pop := 0.0
		var last := {}
		var kind := ""
		for i in 900:
			await physics_frame
			if e.state in ["getup", "rise"]:
				seen[e.state] = true
				if kind == "" and not e.up_clip.is_empty():
					kind = "ventre" if e.up_clip == e.E_UP_FRONT else "dos"
				for n in e.parts:
					var gp: Vector3 = e.parts[n].global_position
					under = minf(under, gp.y - (0.13 if n == "head" else 0.05))
					if last.has(n):
						pop = maxf(pop, gp.distance_to(last[n]))
					last[n] = gp
			if e.state == "stand" and seen.has("rise"):
				break
		print("- relevé %d (%s) : %s ; membre le plus bas %.0f cm sous le sol ; à-coup max %.0f cm/image" % [k, kind, str(seen.keys()), maxf(-under, 0.0) * 100.0, pop * 100.0])
	main.queue_free()
	await process_frame

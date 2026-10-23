extends SceneTree
## Auto-test de l'éditeur d'animation (F3) : godot --headless --path . -s editorcheck.gd --fixed-fps 120
## Choix du coup, pose de la fiche d'origine, membre attrapé et tourné à la souris, curseurs, clés (ajouter, déplacer, supprimer),
## courbes, copier / coller, miroir, annuler / rétablir, versions nommées (enregistrer, cocher, renommer, supprimer),
## mise à jour immédiate du jeu (table des coups et héros du labo), export en un fichier, intégration au projet (outil).

var ed
var fails := []


func _initialize() -> void:
	AnimStore.path = "user://test_anims.json"
	if FileAccess.file_exists(AnimStore.path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AnimStore.path))
	AnimStore.load_file()
	AnimStore.apply(MoveLibrary.table())
	ed = load("res://anim_editor.tscn").instantiate()
	root.add_child(ed)
	_run()


func ok(c: bool, msg: String) -> void:
	print(("  [ok] " if c else "  [ECHEC] ") + msg)
	if not c:
		fails.append(msg)


func wait(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await wait(5)
	print("Ouverture")
	ok(ed.cards.size() > 20 and ed.cards[0][0] == "mseed00", "liste des coups du labo (%d)" % ed.cards.size())
	ok(ed.move_id == "jab" and ed.keys.size() == 5, "premier coup : le jab, ses 5 clés (%s, %d)" % [ed.move_id, ed.keys.size()])
	var md: MoveData = MoveLibrary.moves()["hikick"]
	ed.load_move("hikick")
	ok(ed.keys.size() == md.keys.size() and absf(ed.timing.active - md.active) < 0.001, "high kick : clés et rythme de la fiche")
	# La pose montrée = la pose du jeu (fiche d'origine) à cet instant.
	var h = load("res://player.gd").new()
	root.add_child(h)
	h.set_physics_process(false)
	var tt: float = md.keys[2][0]
	var game_pose: Dictionary = h.pose_at("hikick", tt)
	h.apply_pose(game_pose)
	var foot_game: Vector3 = h.j.foot_r.global_position - h.global_position
	ed.t = tt
	ed.hero.apply_pose(ed.pose_at(tt))
	var foot_ed: Vector3 = ed.hero.global_basis.inverse() * (ed.hero.j.foot_r.global_position - ed.hero.global_position)
	foot_game = h.global_basis.inverse() * foot_game
	ok(foot_game.distance_to(foot_ed) < 0.03, "même pose que dans le jeu (pied à %.3f m près)" % foot_game.distance_to(foot_ed))

	print("Membres à la souris")
	ed.view_3d = false
	ed._place_camera()
	await wait(2)
	ed.t = ed.keys[2].t
	ed.hero.apply_pose(ed.pose_at(ed.t))
	var at: Vector2 = ed.cam.unproject_position(ed._joint_center("el_r"))
	ok(ed.pick_joint(at) == "el_r", "clic sur le coude droit : il est attrapé (%s)" % ed.pick_joint(at))
	var before: Vector3 = ed.keys[2].pose.sh_r
	var center: Vector2 = ed.cam.unproject_position(ed.hero.j.sh_r.global_position)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = ed.cam.unproject_position(ed._joint_center("sh_r"))
	ed._unhandled_input(press)
	ok(ed.sel_joint == "sh_r" and ed.drag.has("joint"), "glisser depuis l'épaule droite : rotation en cours")
	var mv := InputEventMouseMotion.new()
	mv.position = center + (press.position - center).rotated(-0.6)
	ed._unhandled_input(mv)
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	ed._unhandled_input(rel)
	var after: Vector3 = ed.keys[2].pose.sh_r
	ok(before.distance_to(after) > 20.0, "l'épaule a tourné (%s -> %s)" % [before, after])
	ed.hero.apply_pose(ed.pose_at(ed.t))
	var new_dir: Vector2 = ed.cam.unproject_position(ed._joint_center("sh_r")) - center
	var ang := absf(angle_difference((press.position - center).angle(), new_dir.angle()))
	ok(absf(ang - 0.6) < 0.12, "et suit la souris à l'écran (%.2f rad pour 0.6)" % ang)
	ok(ed.dirty, "changement non enregistré signalé")
	ed.undo()
	ok(ed.keys[2].pose.sh_r.distance_to(before) < 0.01, "annuler : l'épaule revient")
	ed.redo()
	ok(ed.keys[2].pose.sh_r.distance_to(after) < 0.01, "rétablir")
	ed.select_joint("head")
	ed.sliders[1].value = 33.0
	ok(absf(ed.keys[2].pose.head.y - 33.0) < 0.01, "curseur Y de la tête : 33°")

	print("Clés et rythme")
	var n0: int = ed.keys.size()
	ed.t = (ed.keys[2].t + ed.keys[3].t) * 0.5
	var mid_before: Dictionary = ed.pose_at(ed.t)
	var i: int = ed.add_key(ed.t)
	ok(ed.keys.size() == n0 + 1 and i == 3, "clé ajoutée entre deux clés")
	var mid_after: Dictionary = ed.pose_at(ed.t)
	ok(mid_before.spine.angle_to(mid_after.spine) < 0.01, "la nouvelle clé reprend la pose du moment")
	ed.move_key(3, ed.keys[3].t + 0.05)
	ok(ed.keys[3].t < ed.keys[4].t and ed.keys[3].t > ed.keys[2].t, "déplacer une clé : elle reste entre ses voisines")
	ed.move_key(3, 9.0)
	ok(ed.keys[3].t < ed.keys[4].t, "elle ne dépasse pas la suivante")
	ed.set_curve(3, "inout")
	ok(ed.keys[3].curve == "inout", "courbe douce vers cette clé")
	ed.delete_key(3)
	ok(ed.keys.size() == n0, "clé supprimée")
	ed.delete_key(0)
	ok(ed.keys.size() == n0, "la première clé ne se supprime pas")
	ed.set_timing("active", 0.15)
	ok(absf(ed.timing.active - 0.15) < 0.001, "impact déplacé à 0,15 s")

	print("Pose : copier, coller, miroir")
	ed.t = ed.keys[2].t
	ed.copy_pose()
	ed.t = ed.keys[3].t
	ed.paste_pose()
	ok(ed.keys[3].pose.sh_r.distance_to(ed.keys[2].pose.sh_r) < 0.01, "pose collée sur une autre clé")
	var p: Dictionary = ed.keys[3].pose.duplicate(true)
	ed.mirror_pose()
	var q: Dictionary = ed.keys[3].pose
	ok(q.sh_l.distance_to(Vector3(p.sh_r.x, -p.sh_r.y, -p.sh_r.z)) < 0.01 and q.hip_r.distance_to(Vector3(p.hip_l.x, -p.hip_l.y, -p.hip_l.z)) < 0.01, "miroir : gauche et droite échangées")
	ed.undo()
	ok(ed.keys[3].pose.sh_r.distance_to(p.sh_r) < 0.01, "annuler le miroir")

	print("Versions et mise à jour du jeu")
	var table: Dictionary = MoveLibrary.table()
	var orig_keys: Array = table.hikick.keys
	ok(ed.save_new("rapide"), "enregistrée sous « rapide »")
	ok(AnimStore.chosen("hikick") == "rapide", "la première version est cochée : le jeu l'utilise")
	ok(table.hikick.keys != orig_keys and String(table.hikick.keys[1][1]).begins_with("@"), "la table des coups du jeu a changé tout de suite")
	ok(absf(table.hikick.active - 0.15) < 0.001, "avec son rythme (impact à 0,15 s)")
	var hp: Dictionary = h.pose_at("hikick", ed.keys[2].t)
	h.apply_pose(hp)
	ok(absf(rad_to_deg(h.j.head.quaternion.get_euler().y) - 33.0) < 0.5, "un héros en jeu joue la nouvelle pose (tête à %.1f°)" % rad_to_deg(h.j.head.quaternion.get_euler().y))
	ok(FileAccess.file_exists(AnimStore.path), "enregistrée dans le dossier utilisateur (%s)" % AnimStore.path)
	ed.set_timing("end", 0.5)
	ed.save_new("longue")
	ok(AnimStore.versions("hikick").size() == 2 and AnimStore.chosen("hikick") == "rapide", "2e version « longue » ; « rapide » reste cochée")
	ed.choose_current()
	ok(AnimStore.chosen("hikick") == "longue" and absf(table.hikick.end - 0.5) < 0.001, "on coche « longue » : le jeu la prend")
	ed.load_version("rapide")
	ok(absf(ed.timing.end - md.end) < 0.001, "rouvrir « rapide » : ses propres réglages")
	ed.load_version("longue")
	ed.rename_current("longue finale")
	ok(AnimStore.chosen("hikick") == "longue finale" and AnimStore.find_version("hikick", "longue").is_empty(), "renommer garde la coche")
	ed.load_version("")
	ed.choose_current()
	ok(AnimStore.chosen("hikick") == "" and table.hikick.keys == orig_keys, "cocher la fiche d'origine : le jeu revient à l'animation d'origine")
	ed.load_version("rapide")
	ed.choose_current()
	# Un 2e coup modifié, pour l'export.
	ed.load_move("jab")
	ed.t = ed.keys[2].t
	ed.select_joint("spine")
	ed.sliders[0].value = -30.0
	ed.save_new("penché")

	print("Export et intégration")
	var dir := ProjectSettings.globalize_path("user://")
	var path: String = AnimStore.export_all(dir)
	ok(path != "" and FileAccess.file_exists(path), "« Tout exporter » écrit un seul fichier")
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	ok(typeof(d) == TYPE_DICTIONARY and d.format == "rogue-doll-anims" and d.moves.has("hikick") and d.moves.has("jab"), "il contient tous les coups modifiés")
	ok(d.moves.hikick.versions.size() == 2 and d.moves.hikick.chosen == "rapide", "toutes les versions, avec celle qui est cochée")
	ed.load_move("hikick")
	ed.load_version("rapide")
	ed.delete_current()
	ok(AnimStore.versions("hikick").size() == 1 and AnimStore.chosen("hikick") == "", "supprimer une version cochée : retour à la fiche d'origine")
	# L'outil d'intégration (Claude) transforme les versions cochées en animations officielles, ici sur une copie.
	var ps := load("res://moves/poses.tres") as PoseSet
	var before_n := ps.diffs.size()
	var v: Dictionary = d.moves.jab.versions[0]
	var conv := AnimStore.pose_from_json(v.keys[2].pose)
	ok(absf(conv.spine.x + 30.0) < 0.01 and conv.foot_l == null, "une pose du fichier se relit à l'identique (buste à %.1f°)" % conv.spine.x)
	ok(before_n > 100, "les poses du projet ne sont pas touchées par l'éditeur (%d)" % before_n)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AnimStore.path))
	AnimStore.path = "user://anims.json"
	AnimStore.load_file()
	AnimStore.apply(MoveLibrary.table())
	print("\nRESULTAT: ", "OK" if fails.is_empty() else "ECHEC " + str(fails))
	quit(1 if fails.size() else 0)

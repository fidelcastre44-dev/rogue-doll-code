class_name Weapons
## Armes du terrain d'essai (v0.112) : épée, katana, hache, batte. Ce sont des objets qu'on prend au mur (RB) et qu'on garde :
## elles ne se cassent pas. Chaque arme a son propre jeu de coups (game/moves.gd, préfixes sw_, ka_, ax_, bt_).
## Modèles CC0 (assets/weapons/CREDITS.txt). Repère commun : lame vers +Y, origine = milieu de la poignée.
## La zone de frappe suit la lame : segment [blade.x, blade.y] (m le long de +Y), rayon `radius`.

## Prise dans la main droite (repère de l'os hand_r du squelette type mannequin UE) : la lame sort côté pouce / index
## (axe +Z de la main, mesuré entre pinky_01_r et index_01_r), la poignée au creux du poing.
const GRIP := Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-0.03, 0.085, 0.0))

const DEFS := {
	"sword": {"name": "Épée", "mesh": "res://assets/weapons/Sword.obj", "scale": 0.18, "rot": Vector3.ZERO,
		"blade": Vector2(0.12, 0.84), "radius": 0.16, "col": Color(0.75, 0.8, 0.9),
		"moves": {"attack": "sw_a", "heavy": "sw_heavy", "dodge_attack": "sw_dash", "dodge_heavy": "sw_up", "air": "sw_air", "sprint_attack": "sw_dash", "sprint_heavy": "sw_heavy"}},
	"katana": {"name": "Katana", "mesh": "res://assets/weapons/Katana.obj", "scale": 0.0085, "rot": Vector3(0, 90, 90),
		"blade": Vector2(0.06, 0.85), "radius": 0.14, "col": Color(0.85, 0.9, 1.0),
		"mats": {"Blade": Color(0.78, 0.8, 0.84), "Katana-Handle": Color(0.12, 0.08, 0.1)},
		"moves": {"attack": "ka_a", "heavy": "ka_iai", "dodge_attack": "ka_iai", "dodge_heavy": "ka_rise", "air": "ka_air", "sprint_attack": "ka_iai", "sprint_heavy": "ka_rise"}},
	"axe": {"name": "Hache", "mesh": "res://assets/weapons/Axe.obj", "scale": 0.17, "rot": Vector3.ZERO,
		"blade": Vector2(0.3, 0.62), "radius": 0.24, "col": Color(1.0, 0.75, 0.5),
		"moves": {"attack": "ax_chop", "heavy": "ax_sweep", "dodge_attack": "ax_chop", "dodge_heavy": "ax_up", "air": "ax_air", "sprint_attack": "ax_chop", "sprint_heavy": "ax_sweep"}},
	"bat": {"name": "Batte", "mesh": "res://assets/weapons/baseball_bat.glb", "scale": 1.0, "rot": Vector3.ZERO,
		"blade": Vector2(0.2, 0.67), "radius": 0.17, "col": Color(1.0, 0.9, 0.6),
		"moves": {"attack": "bt_a", "heavy": "bt_smash", "dodge_attack": "bt_swing", "dodge_heavy": "bt_up", "air": "bt_air", "sprint_attack": "bt_swing", "sprint_heavy": "bt_smash"}},
}
const ORDER := ["sword", "katana", "axe", "bat"]


## Le modèle prêt à attacher à la main (nœud racine = prise GRIP, lame vers +Y en dessous).
static func make_model(id: String) -> Node3D:
	var d: Dictionary = DEFS[id]
	var grip := Node3D.new()
	grip.name = "Weapon_" + id
	grip.transform = GRIP
	grip.add_child(make_mesh(id))
	return grip


## Le modèle seul (lame vers +Y, poignée à l'origine) : pour le mur d'armes.
static func make_mesh(id: String) -> Node3D:
	var d: Dictionary = DEFS[id]
	var r = load(d.mesh)
	var n: Node3D
	if r is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = r
		n = mi
	else:
		n = r.instantiate()
	var holder := Node3D.new()
	holder.add_child(n)
	n.scale = Vector3.ONE * float(d.scale)
	n.rotation_degrees = d.rot
	if d.has("mats"):
		for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
			if not mi is MeshInstance3D or mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var nm: String = mi.mesh.surface_get_name(s)
				if d.mats.has(nm):
					var m := StandardMaterial3D.new()
					m.albedo_color = d.mats[nm]
					m.metallic = 0.6 if nm != "Katana-Handle" else 0.0
					m.roughness = 0.35 if nm != "Katana-Handle" else 0.8
					mi.set_surface_override_material(s, m)
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return holder

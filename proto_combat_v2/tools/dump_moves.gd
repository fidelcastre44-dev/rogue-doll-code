extends SceneTree
## Écrit data/moves.gd au format du carnet de combat (collection `moves`) dans un fichier JSON : OUT=/chemin.json
const NAMES := {"jab": "Jab", "cross": "Direct", "elbow": "Coude", "spin_kick": "Coup de pied retourné", "launcher": "Uppercut lanceur",
	"sweep": "Balayette", "push_kick": "Coup de pied poussé", "haymaker": "Gros crochet", "charged": "Coup chargé", "dash_punch": "Direct plongeant",
	"slide": "Glissade (envoie en l'air)", "slide_kick": "Coup de pied glissé", "big_kick": "Gros coup de pied", "air_jab": "Jab aérien",
	"air_kick": "Pied latéral aérien", "air_heel": "Talon aérien", "air_knee": "Gros genou aérien", "dive_kick": "Coup de pied plongeant",
	"riposte": "Riposte", "e_cross": "Sbire : direct", "e_lowkick": "Sbire : coup de pied bas", "e_hook": "Sbire : crochet", "e_bigkick": "Sbire : gros coup de pied"}
const CMDS := {"jab": "X", "cross": "X X", "elbow": "X X X", "spin_kick": "X X X X", "launcher": "X X puis Y", "sweep": "X maintenu",
	"push_kick": "Y", "haymaker": "Y Y", "charged": "Y maintenu", "dash_punch": "roulade + X", "slide": "roulade + Y", "slide_kick": "sprint + X",
	"big_kick": "sprint + Y", "air_jab": "en l'air : X", "air_kick": "en l'air : X X", "air_heel": "en l'air : X X X", "air_knee": "en l'air : Y",
	"dive_kick": "en l'air : Y maintenu", "riposte": "X après une parade", "e_cross": "—", "e_lowkick": "—", "e_hook": "—", "e_bigkick": "—"}
const GROUPS := {"jab": "X au sol", "cross": "X au sol", "elbow": "X au sol", "spin_kick": "X au sol", "launcher": "X au sol", "sweep": "X au sol",
	"push_kick": "Y au sol", "haymaker": "Y au sol", "charged": "Y au sol", "dash_punch": "Roulade / sprint", "slide": "Roulade / sprint",
	"slide_kick": "Roulade / sprint", "big_kick": "Roulade / sprint", "air_jab": "En l'air", "air_kick": "En l'air", "air_heel": "En l'air",
	"air_knee": "En l'air", "dive_kick": "En l'air", "riposte": "Parade", "e_cross": "Sbires", "e_lowkick": "Sbires", "e_hook": "Sbires", "e_bigkick": "Sbires"}
const EFFECTS := {"": "—", "stagger": "recule en titubant", "knockdown": "renverse", "launch": "envoie en l'air", "juggle": "maintient en l'air", "spike": "écrase au sol"}
const DODGE := {"always": "à tout moment", "active": "après l'actif", "hit": "seulement s'il a touché"}

func _init() -> void:
	var out := {}
	var i := 0
	for k in Moves.M:
		var m: Dictionary = Moves.M[k]
		var ch := {}
		for b in m.get("chain", {}):
			ch["X" if b == "attack" else "Y"] = NAMES.get(m.chain[b], m.chain[b])
		out["v2_" + k] = {"key": k, "name": NAMES.get(k, k), "cmd": CMDS.get(k, ""), "group": "v2 · " + GROUPS.get(k, ""), "order": 200 + i,
			"anim": "Mixamo · %s (contact %.2f s, %s)" % [str(m.anim).trim_prefix("mx/"), float(m.hit), m.get("limb", "")],
			"startup": int(m.startup), "active": int(m.active), "recovery": int(m.recovery), "total": Moves.total(m),
			"dmg": m.dmg, "hitstop": m.hitstop, "stun": m.stun, "kb_h": m.kb[0], "kb_v": m.kb[1], "effect": EFFECTS.get(m.get("effect", ""), m.get("effect", "")),
			"lunge": m.get("lunge", 0.0), "chain": ch, "chain_from": m.get("chain_from", 0), "dodge": DODGE.get(m.get("dodge", "always"), ""),
			"jump_cancel": m.get("jump_cancel", false), "guard_break": m.get("guard_break", false), "armor": m.get("armor", false), "low": m.get("low", false),
			"box": "devant %.2f · haut %.2f · rayon %.2f" % [m.box[0], m.box[1], m.box[2]], "version": "0.2"}
		i += 1
	var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	print("ok ", out.size())
	quit()

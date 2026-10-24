class_name Sfx
extends Node
## Bruitages synthétisés au lancement (pas de fichiers) : impacts, souffles, garde, parade… Paul pourra les remplacer
## par ses propres sons : déposer un .wav / .ogg du même nom dans res://assets/sfx/ (ex. heavy.wav) et il est pris à la place.

const RATE := 22050
var streams := {}
var pool: Array[AudioStreamPlayer] = []
var volume := 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	_build()


func _build() -> void:
	streams["light"] = _impact(0.11, 180.0, 70.0, 0.75, 0.55)
	streams["heavy"] = _impact(0.2, 120.0, 45.0, 0.85, 0.75)
	streams["big"] = _impact(0.38, 90.0, 32.0, 0.9, 1.0)
	streams["thud"] = _impact(0.18, 70.0, 40.0, 0.4, 0.6)
	streams["land"] = _impact(0.12, 90.0, 50.0, 0.5, 0.4)
	streams["whoosh"] = _whoosh(0.13, 2200.0, 900.0, 0.35)
	streams["whoosh_heavy"] = _whoosh(0.22, 1400.0, 450.0, 0.45)
	streams["roll"] = _whoosh(0.2, 900.0, 300.0, 0.35)
	streams["jump"] = _whoosh(0.12, 700.0, 1500.0, 0.25)
	streams["block"] = _metal(0.16, 520.0, 0.5)
	streams["parry"] = _metal(0.6, 1320.0, 0.8)
	streams["break"] = _metal(0.4, 260.0, 0.9)
	streams["grab"] = _impact(0.09, 300.0, 200.0, 0.3, 0.4)
	streams["warn"] = _tone(0.12, 880.0, 1320.0, 0.18)
	streams["charge"] = _tone(0.5, 180.0, 520.0, 0.18)
	streams["perfect"] = _tone(0.35, 600.0, 2400.0, 0.3)
	for k in streams.keys():
		for ext in [".wav", ".ogg"]:
			var p: String = "res://assets/sfx/" + k + ext
			if ResourceLoader.exists(p):
				streams[k] = load(p)


func play(name: String, _at := Vector3.ZERO, vol := 0.7, pitch_var := 0.08) -> void:
	if not streams.has(name):
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[name]
			p.volume_db = linear_to_db(maxf(vol * volume, 0.001))
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return


func _wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## Impact : coup de basse qui descend (corps) + bruit filtré court (claque).
func _impact(dur: float, f0: float, f1: float, noise: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var fr := lerpf(f0, f1, sqrt(k))
		ph += TAU * fr / RATE
		var body := sin(ph) * exp(-k * 5.0)
		var nz := randf_range(-1, 1)
		lp += (nz - lp) * lerpf(0.9, 0.08, k)
		var crack := lp * exp(-t * 60.0) * noise
		d[i] = (body * 0.9 + crack) * gain * (1.0 - pow(k, 4.0))
	return _wav(d)


func _whoosh(dur: float, f0: float, f1: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var k := float(i) / n
		var cut := lerpf(f0, f1, k) / RATE * TAU
		var nz := randf_range(-1, 1)
		lp += (nz - lp) * clampf(cut, 0.0, 1.0)
		bp += (lp - bp) * 0.25
		var env := sin(PI * pow(k, 0.6))
		d[i] = (lp - bp) * env * gain * 2.5
	return _wav(d)


func _metal(dur: float, f0: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var parts := [1.0, 2.76, 5.4, 8.93]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for j in parts.size():
			s += sin(TAU * f0 * parts[j] * t) * exp(-t * (6.0 + j * 5.0)) / (j + 1)
		s += randf_range(-1, 1) * exp(-t * 90.0) * 0.6
		d[i] = s * gain * 0.6
	return _wav(d)


func _tone(dur: float, f0: float, f1: float, gain: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedFloat32Array()
	d.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(f0, f1, k) / RATE
		d[i] = (sin(ph) + 0.3 * sin(ph * 2.0)) * sin(PI * k) * gain
	return _wav(d)

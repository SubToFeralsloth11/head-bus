class_name Sfx
extends Node
## Tiny synthesised sound set, generated at start-up so the game ships no audio files.

const RATE := 22050

var _players := {}
var _engine: AudioStreamPlayer


func _ready() -> void:
	_add("coin", _coin(), -8.0)
	_add("near", _whoosh(), -6.0)
	_add("crash", _crash(), -2.0)
	_add("thud", _thud(), -4.0)
	_add("level", _chime(), -8.0)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _engine_loop()
	_engine.volume_db = -20.0
	add_child(_engine)


func play(id: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _players[id]
	p.pitch_scale = pitch
	p.play()


## speed01 = 0 idles the engine; a negative value silences it.
func engine(speed01: float) -> void:
	if speed01 < 0.0:
		if _engine.playing:
			_engine.stop()
		return
	if not _engine.playing:
		_engine.play()
	_engine.pitch_scale = 0.7 + clampf(speed01, 0.0, 1.5) * 0.6


func _add(id: String, stream: AudioStreamWAV, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	_players[id] = p


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


static func _coin() -> AudioStreamWAV:
	var n := int(RATE * 0.18)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 988.0 if t < 0.06 else 1318.0
		var sq := 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0
		out[i] = sq * 0.35 * (1.0 - t / 0.18)
	return _wav(out)


static func _whoosh() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1, 1) - lp) * (0.05 + 0.25 * t)
		out[i] = lp * 2.2 * sin(t * PI)
	return _wav(out)


static func _crash() -> AudioStreamWAV:
	var n := int(RATE * 0.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1, 1) - lp) * 0.35
		var thump := sin(TAU * 60.0 * t) * exp(-t * 8.0)
		out[i] = (lp * exp(-t * 5.0) + thump) * 0.8
	return _wav(out)


static func _thud() -> AudioStreamWAV:
	var n := int(RATE * 0.15)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * 140.0 * t) + randf_range(-0.3, 0.3)) * exp(-t * 25.0) * 0.8
	return _wav(out)


static func _chime() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 659.0 if t < 0.12 else (784.0 if t < 0.24 else 1046.0)
		out[i] = sin(TAU * f * t) * 0.4 * exp(-fmod(t, 0.12) * 6.0) * (1.0 - t / 0.5)
	return _wav(out)


## 0.4 s holds exactly 22 cycles of 55 Hz, so the loop is seamless.
static func _engine_loop() -> AudioStreamWAV:
	var n := int(RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var saw := fmod(t * 55.0, 1.0) * 2.0 - 1.0
		out[i] = (saw * 0.5 + sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 165.0 * t) * 0.15) * 0.6
	return _wav(out, true)

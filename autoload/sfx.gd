extends Node
## 轻量音效管理（Autoload 单例 `Sfx`）。
## 无需外部音频资源：在运行时用正弦 / 方波 / 锯齿波程序化合成简单提示音。

const SAMPLE_RATE := 22050
const VOICES := 12

var _streams: Dictionary = {}
var _players: Array = []


func _ready() -> void:
	_streams["hatch"] = _tone(880.0, 0.12, 0.35, "sine")
	_streams["steal"] = _tone(180.0, 0.20, 0.40, "square")
	_streams["reward"] = _tone(660.0, 0.15, 0.35, "sine")
	_streams["shield"] = _tone(1200.0, 0.15, 0.30, "sine")
	_streams["fail"] = _tone(140.0, 0.35, 0.45, "saw")
	_streams["win"] = _tone(1046.0, 0.30, 0.40, "sine")
	_streams["click"] = _tone(520.0, 0.06, 0.25, "square")
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## 播放一个音效。名称不存在时静默忽略。
func play(sound: String) -> void:
	if not _streams.has(sound):
		return
	for player in _players:
		if not player.playing:
			player.stream = _streams[sound]
			player.play()
			return


func _tone(freq: float, duration: float, volume: float, wave: String) -> AudioStreamWAV:
	var count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var fade := 0.015
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var phase := fmod(freq * t, 1.0)
		var sample := 0.0
		match wave:
			"sine":
				sample = sin(TAU * freq * t)
			"square":
				sample = 1.0 if phase < 0.5 else -1.0
			"saw":
				sample = 2.0 * phase - 1.0
		# 简单的淡入淡出包络，避免爆音
		var env := 1.0
		if t < fade:
			env = t / fade
		elif t > duration - fade:
			env = (duration - t) / fade
		var value := int(clampf(sample * env * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

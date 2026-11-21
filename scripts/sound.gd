extends Node
## Fully original synthesized sound. Generates its own PCM samples; no sound packs.

const SAMPLE_RATE := 22050

var ambient: AudioStreamPlayer
var gate: AudioStreamPlayer
var damage: AudioStreamPlayer
var finale: AudioStreamPlayer
var launch: AudioStreamPlayer
var plasma: AudioStreamPlayer
var impact: AudioStreamPlayer


func _ready() -> void:
    ambient = _player(_make_wave("ambient", 3.0), -21.0)
    gate = _player(_make_wave("gate", 0.65), -5.0)
    damage = _player(_make_wave("damage", 0.48), -7.0)
    finale = _player(_make_wave("finale", 1.7), -5.0)
    launch = _player(_make_wave("launch", 0.85), -10.0)
    plasma = _player(_make_wave("plasma", 0.24), -14.0)
    impact = _player(_make_wave("impact", 0.40), -9.0)
    ambient.play()


func _player(stream_data: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
    var result := AudioStreamPlayer.new()
    result.stream = stream_data
    result.volume_db = volume
    add_child(result)
    return result


func _make_wave(style: String, seconds: float) -> AudioStreamWAV:
    var frames := int(float(SAMPLE_RATE) * seconds)
    var pcm := PackedByteArray()
    pcm.resize(frames * 2)
    for i in range(frames):
        var t := float(i) / float(SAMPLE_RATE)
        var u := t / seconds
        var wave := 0.0
        var envelope := 1.0
        match style:
            "ambient":
                # Long, seamless harmonic drone at integer-cycle frequencies.
                wave = sin(TAU * 55.0 * t) * 0.40
                wave += sin(TAU * 82.5 * t) * 0.21
                wave += sin(TAU * 110.0 * t) * 0.17
                wave += sin(TAU * 165.0 * t) * 0.09
                envelope = 0.63
            "gate":
                var phase := TAU * (380.0 * t + 370.0 * t * t)
                wave = sin(phase) * 0.72 + sin(phase * 2.0) * 0.21
                envelope = minf(1.0, u * 13.0) * pow(1.0 - u, 1.7)
            "damage":
                var phase := TAU * (188.0 * t - 82.0 * t * t)
                wave = sin(phase) * 0.58 + sin(phase * 1.415) * 0.26
                envelope = pow(1.0 - u, 1.3)
            "finale":
                wave = sin(TAU * (220.0 * t + 120.0 * t * t)) * 0.44
                wave += sin(TAU * 330.0 * t) * 0.22
                wave += sin(TAU * 440.0 * t) * 0.17
                envelope = minf(1.0, 9.0 * u) * pow(1.0 - u, 0.55)
            "plasma":
                wave = sin(TAU * (530.0 * t - 1600.0 * t * t)) * 0.59
                wave += sin(TAU * (880.0 * t - 2450.0 * t * t)) * 0.24
                envelope = pow(1.0 - u, 2.0) * minf(1.0, u * 30.0)
            "impact":
                wave = sin(TAU * (205.0 * t - 350.0 * t * t)) * 0.52
                wave += sin(TAU * 52.0 * t) * 0.23
                envelope = pow(1.0 - u, 1.7)
            "launch":
                wave = sin(TAU * (84.0 * t + 90.0 * t * t)) * 0.62
                wave += sin(TAU * 210.0 * t) * 0.12
                envelope = minf(1.0, 11.0 * u) * pow(1.0 - u, 1.2)
        var value := clampi(int(wave * envelope * 13000.0), -32768, 32767)
        pcm[i * 2] = value & 255
        pcm[i * 2 + 1] = (value >> 8) & 255
    var audio := AudioStreamWAV.new()
    audio.mix_rate = SAMPLE_RATE
    audio.format = AudioStreamWAV.FORMAT_16_BITS
    audio.stereo = false
    audio.data = pcm
    if style == "ambient":
        audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
        audio.loop_begin = 0
        audio.loop_end = frames
    return audio


func set_boost(enabled: bool, delta: float) -> void:
    if ambient != null:
        ambient.pitch_scale = lerpf(ambient.pitch_scale, 1.27 if enabled else 1.0, minf(delta * 3.0, 1.0))


func play_gate() -> void:
    gate.play()


func play_damage() -> void:
    damage.play()


func play_finish() -> void:
    finale.play()


func play_launch() -> void:
    launch.play()


func play_plasma() -> void:
    plasma.play()


func play_impact() -> void:
    impact.play()

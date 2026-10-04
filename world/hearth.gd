class_name Hearth
extends Node3D
## The fire in the cottage: a flickering light and dancing flames.

var fire: Node3D
var _light := OmniLight3D.new()
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	_light.light_color = Color(1.0, 0.58, 0.28)
	_light.omni_range = 6.5
	_light.shadow_enabled = true
	_light.position = Vector3(0.45, 0.3, 0)
	add_child(_light)
	_noise.frequency = 2.5


func _process(delta: float) -> void:
	_t += delta
	var n := _noise.get_noise_1d(_t * 4.0)
	_light.light_energy = 1.7 + n * 0.6
	if fire:
		fire.scale = Vector3(1.0 + n * 0.08, 1.0 + _noise.get_noise_1d(_t * 6.0 + 30.0) * 0.25, 1.0 + n * 0.08)

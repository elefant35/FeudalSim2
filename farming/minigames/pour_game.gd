class_name PourGame
extends Minigame
## Watering: hold the button to tip the bucket over the plot under the crosshair.
## Aim for the band: too little and the soil dries by tomorrow, too much and it's waterlogged.

const POUR_RATE := 0.75       ## Moisture added per second.
const BUCKET_PER_MOISTURE := 0.33
const TARGET := Vector2(0.65, 1.05)

var _pouring := false
var _tip := 0.0
var _plot: FarmPlot = null
var _audio: AudioStreamPlayer
var _splash_t := 0.0


func _init() -> void:
	locks_look = false
	hint = "Hold to pour. Fill the soil to the band, then move on. A full bucket waters about three plots."


func _on_start() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.stream = Sfx.stream("pour")
	_audio.volume_db = -6.0
	player.add_child(_audio)


func press() -> void:
	_pouring = true


func release() -> void:
	_pouring = false


func update(delta: float) -> void:
	player.ray.force_raycast_update()
	_plot = FarmPlot.from_collider(player.ray.get_collider())
	var want := 1.0 if _pouring else 0.0
	_tip = move_toward(_tip, want, delta * 4.0)
	player.viewmodel.pose_pour(_tip)
	var flowing := _tip > 0.7 and player.bucket_water() > 0.0
	if flowing and not _audio.playing and _audio.stream:
		_audio.play()
	elif not flowing and _audio.playing:
		_audio.stop()
	if not flowing:
		return
	var amount := POUR_RATE * delta
	player.set_bucket_water(player.bucket_water() - amount * BUCKET_PER_MOISTURE)
	_splash_t -= delta
	var pos := player.ray.get_collision_point() if player.ray.is_colliding() else player.global_position + Vector3(0, 0.1, 0)
	if _splash_t <= 0.0:
		_splash_t = 0.12
		var spout := player.camera.global_transform * Vector3(0.15, -0.15, -0.6)
		Fx.throw(player, spout, pos, Color(0.55, 0.7, 0.85), 10, 0.02)
	if _plot:
		_plot.state.water(amount)
		_plot.refresh()
	if player.bucket_water() <= 0.0:
		player.say("The bucket is empty.")
		stop()


func _on_stop() -> void:
	if _audio:
		_audio.queue_free()
	player.viewmodel.pose_rest()


func draw(c: Control, center: Vector2) -> void:
	if _plot:
		Minigame.draw_fill(c, center, _plot.state.moisture / 1.3, "Soil water", Color(0.35, 0.55, 0.85), TARGET.x / 1.3, TARGET.y / 1.3)
	Minigame.draw_meter(c, center, player.bucket_water(), 0.0, 0.0, "Bucket %d%%" % roundi(player.bucket_water() * 100.0))

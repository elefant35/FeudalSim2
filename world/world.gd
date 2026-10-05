extends Node3D
## The farm: builds the valley, places the house, field, well and traders, and runs the day:
## sun and sky, sleeping, collapsing, saving.

const SAVE_PATH := "user://save.json"
const START_GOLD := 12
const SPAWN := Vector3(-9.0, 0.0, -2.5)
const SPAWN_YAW := -2.2

var player: Player
var hud: Hud
var sun := DirectionalLight3D.new()
var env := WorldEnvironment.new()
var _sky_mat := ProceduralSkyMaterial.new()
var _rain: GPUParticles3D
var _rain_audio := AudioStreamPlayer.new()
var _ambience := AudioStreamPlayer.new()
var _sleeping := false


func _ready() -> void:
	_build_environment()
	add_child(Terrain.build())
	player = Player.new()
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	hud.setup(player)
	hud.save_requested.connect(save_game)
	hud.new_game_requested.connect(new_game)
	player.needs.collapsed.connect(_on_collapsed)
	Clock.minutes_passed.connect(_on_minutes_passed)
	Clock.day_started.connect(_on_day_started)
	FarmLayout.build(self)
	hud.objective = _objective
	hud.guide_sections = FarmGuide.sections
	if DevTools.no_save() or not load_game():
		_start_fresh()
	print("FeudalSim2 world ready")
	var dev := DevTools.new()
	add_child(dev)
	dev.apply(self, player)


func _objective() -> String:
	return FarmGuide.next_step(player, $Field, $ThreshingFloor, $Piles, $HandCart)


func _start_fresh() -> void:
	Clock.reset()
	player.global_position = SPAWN
	player.rotation.y = SPAWN_YAW
	player.wallet.gold = START_GOLD
	player.wallet.changed.emit(player.wallet.gold)
	player.inventory.add(&"hoe")
	player.inventory.add(&"bucket")
	player.inventory.add(&"turnip_seed", 12)
	player.inventory.add(&"bread", 5)
	player.inventory.add(&"turnip", 4, 1)
	player.select_slot(1)
	hud.toast("Spring has come to your farm. Follow the \"Next\" hint (top left), or press G for the field guide.")


# --- Environment ----------------------------------------------------------------------------

func _build_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.55
	e.ambient_light_color = Color(0.62, 0.58, 0.5)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_density = 0.004
	e.fog_aerial_perspective = 0.5
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.4
	env.environment = e
	add_child(env)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	_rain = RainEffect.make()
	add_child(_rain)
	add_child(_rain_audio)
	add_child(_ambience)
	_rain_audio.stream = Sfx.stream("rain_loop")
	_rain_audio.volume_db = -8.0
	_ambience.stream = Sfx.stream("ambience_day")
	_ambience.volume_db = -14.0
	if _ambience.stream:
		_ambience.play()


func _process(_delta: float) -> void:
	_update_sky()
	if player:
		_rain.global_position = player.global_position + Vector3(0, 9, 0)
	if _rain.emitting != Clock.raining:
		_rain.emitting = Clock.raining
		if Clock.raining and _rain_audio.stream:
			_rain_audio.play()
		else:
			_rain_audio.stop()
	if Clock.raining and player:
		_rain_audio.volume_db = lerpf(_rain_audio.volume_db, -18.0 if _under_roof() else -8.0, 0.05)


## Is there a roof over the player's head?
func _under_roof() -> bool:
	var from := player.camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 8.0, 1, [player.get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Sun arc, light colour and sky tint by hour; dimmer and greyer in rain and winter.
func _update_sky() -> void:
	var h := Clock.hour()
	var day_t := (h - 6.0) / 12.0                  # 0 at 06:00, 1 at 18:00
	var elevation := sin(day_t * PI)               # >0 while the sun is up
	sun.rotation = Vector3(-asin(clampf(elevation, -1, 1)) - 0.05, deg_to_rad(-30.0) + day_t * PI * 0.8, 0)
	var daylight := smoothstep(-0.15, 0.25, elevation)
	var warm := 1.0 - smoothstep(0.0, 0.45, elevation)
	var overcast := 0.55 if Clock.raining else 0.0
	sun.light_energy = lerpf(0.05, 1.25, daylight) * (1.0 - overcast * 0.6)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.6, 0.35), warm * daylight)
	var top := Color(0.05, 0.07, 0.15).lerp(Color(0.3, 0.5, 0.82), daylight)
	var horizon := Color(0.1, 0.1, 0.18).lerp(Color(0.75, 0.8, 0.88), daylight).lerp(Color(0.95, 0.6, 0.4), warm * daylight * 0.7)
	var grey := Color(0.5, 0.52, 0.55) * maxf(daylight, 0.15)
	_sky_mat.sky_top_color = top.lerp(grey, overcast)
	_sky_mat.sky_horizon_color = horizon.lerp(grey, overcast)
	_sky_mat.ground_horizon_color = _sky_mat.sky_horizon_color
	_sky_mat.ground_bottom_color = Color(0.1, 0.09, 0.07)
	env.environment.ambient_light_energy = lerpf(0.2, 0.75, daylight)
	for l in get_tree().get_nodes_in_group("night_light"):
		(l as Light3D).light_energy = lerpf(1.4, 0.0, daylight)
	env.environment.fog_light_color = _sky_mat.sky_horizon_color
	env.environment.fog_density = 0.004 + overcast * 0.012


# --- Days, sleep, collapse ------------------------------------------------------------------

func _on_minutes_passed(minutes: float) -> void:
	player.needs.pass_hours(minutes / 60.0)


func _on_day_started(_day: int) -> void:
	if Clock.day_of_season() == 1:
		hud.toast("%s has begun." % Clock.SEASON_NAMES[Clock.season()])


## Called by the bed.
func try_sleep() -> void:
	if _sleeping:
		return
	var h := Clock.hour()
	if h > 5.0 and h < 18.0 and player.needs.energy > 40.0:
		player.say("It's too early to sleep. (You can sleep after 18:00, or whenever you're tired.)")
		return
	_sleep_until_morning("You sleep until morning.", 6.0, 1.0)


func _on_collapsed(reason: String) -> void:
	if _sleeping:
		return
	player.say(reason)
	_sleep_until_morning("You wake at home, aching. Eat and rest properly.", 8.0, 0.5)


func _sleep_until_morning(msg: String, wake_hour: float, rest_quality: float) -> void:
	_sleeping = true
	player.frozen = true
	if player.minigame:
		player.minigame.stop()
	await hud.fade_to(1.0, 1.2).finished
	var hours := Clock.skip_to_hour(wake_hour)
	player.needs.sleep(hours * rest_quality)
	player.global_position = FarmLayout.bed_wake_position
	player.rotation.y = FarmLayout.bed_wake_yaw
	player.velocity = Vector3.ZERO
	save_game()
	await get_tree().create_timer(0.6).timeout
	await hud.fade_to(0.0, 1.2).finished
	player.frozen = false
	_sleeping = false
	hud.toast(msg)
	hud.toast("%s. %s" % [Clock.date_string(), "It's raining; the fields are watered." if Clock.raining else "Fair weather."])


# --- Save / load ----------------------------------------------------------------------------

func save_game() -> void:
	if DevTools.no_save():
		return
	var data := {
		"version": 2, "clock": Clock.to_dict(), "player": player.to_dict(),
		"world": {},
	}
	for n in get_tree().get_nodes_in_group("saveable"):
		data.world[String(get_path_to(n))] = n.to_dict()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	hud.toast("Game saved.")


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 2:
		push_warning("Save file is from an older version or unreadable; starting fresh.")
		return false
	Clock.from_dict(data.clock)
	player.from_dict(data.player)
	for path: String in data.world:
		var n := get_node_or_null(path)
		if n and n.has_method("from_dict"):
			n.from_dict(data.world[path])
	hud.toast("Welcome back. %s, %s." % [Clock.date_string(), Clock.time_string()])
	return true


func new_game() -> void:
	if not DevTools.no_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	get_tree().paused = false
	get_tree().reload_current_scene()


# --- Developer scenarios (see core/dev_tools.gd) ----------------------------------------------

func dev_scenario(scenario: String) -> void:
	var field: Field = get_tree().get_first_node_in_group("field")
	var crops := ["turnip", "cabbage", "barley", "wheat"]
	if scenario in ["grown", "sandbox"]:
		field.fill_garden()
	match scenario:
		"grown":
			# Every plot in a different state, for looking at the art.
			for i in field.plots.size():
				var s := field.plots[i].state
				if i == 0:
					continue
				if i == 1:
					s.till_progress = 2.0
					field.plots[i].refresh()
					continue
				while not s.is_tilled():
					s.till(1.0)
				var c := Items.crop(StringName(crops[i % 4]))
				for pt in [Vector2(0.33, 0.33), Vector2(0.67, 0.33), Vector2(0.33, 0.67), Vector2(0.67, 0.67)]:
					s.sow(c, pt)
				if i == 2:
					field.plots[i].refresh()
					continue
				s.daily_update(0, false, field.rng)
				s.growth = c.grow_days * clampf((i - 2) / 7.0, 0.0, 1.0)
				s.moisture = 0.2 + 0.1 * i
				if i % 3 == 0:
					s.weeds.append(Vector2(0.15, 0.5))
					s.weeds.append(Vector2(0.85, 0.2))
				if i == 7:
					s.plants[4] = PlotState.Plant.BLIGHTED
					s.plants[0] = PlotState.Plant.DEAD
				if c.gets_caterpillars:
					s.caterpillars[2] = 2
				field.plots[i].refresh()
		"crow":
			# A crow already pecking at fresh seed on the nearest plot.
			var p0 := field.plots[0]
			while not p0.state.is_tilled():
				p0.state.till(1.0)
			p0.state.sow(Items.crop(&"turnip"), Vector2(0.5, 0.5))
			p0.refresh()
			var crow := Crow.new()
			crow.plot = p0
			field.add_child(crow)
			crow.state = Crow.State.PECKING
			crow.tame = true
			crow.global_position = p0.to_world(Vector2(0.5, 0.5), 0.08)
		"sandbox":
			# Everything unlocked, with ripe crops, for testing the later stages quickly.
			player.wallet.add(200)
			for id: StringName in [&"sickle", &"flail", &"winnowing_basket", &"scarecrow"]:
				player.inventory.add(id)
			for id: StringName in [&"cabbage_seed", &"barley_seed", &"wheat_seed"]:
				player.inventory.add(id, 12)
			var cart: HandCart = $HandCart
			cart.goods.add(&"turnip", 6, 2)
			cart.goods.add(&"cabbage", 3, 1)
			var stook: Array[int] = [2, 2, 1]
			($Piles as Piles).put(&"barley_sheaf", stook, FarmLayout.THRESHING_POS + Vector3(3.2, 0, -1.0))
			player.set_bucket_water(1.0)
			for i in field.plots.size():
				var s := field.plots[i].state
				if i >= 8:
					continue   # leave a row to till and sow yourself
				while not s.is_tilled():
					s.till(1.0)
				var c := Items.crop(StringName(crops[i % 4]))
				for pt in [Vector2(0.33, 0.33), Vector2(0.67, 0.33), Vector2(0.33, 0.67), Vector2(0.67, 0.67)]:
					s.sow(c, pt)
				s.daily_update(0, false, field.rng)
				s.growth = c.grow_days if i < 4 else c.grow_days * 0.5
				s.moisture = 0.8
				if i == 5:
					s.weeds.append(Vector2(0.2, 0.5))
					s.weeds.append(Vector2(0.8, 0.3))
					s.caterpillars[4] = 2
				if i == 6:
					s.plants[4] = PlotState.Plant.BLIGHTED
				field.plots[i].refresh()
		"tools":
			for id: StringName in [&"bucket", &"sickle", &"flail", &"winnowing_basket", &"scarecrow"]:
				player.inventory.add(id)
			player.set_bucket_water(1.0)

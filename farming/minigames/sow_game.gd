class_name SowGame
extends Minigame
## Broadcast sowing: aim and click to throw a handful. Each cell wants an even covering;
## gaps grow nothing and crowded cells grow poorly. The 3x3 map shows how you're doing.

var seed_item: StringName
var _plot: FarmPlot = null
var _cooldown := 0.0


func _init(item: StringName) -> void:
	seed_item = item
	locks_look = false
	hint = "Aim and click to throw a handful. Cover every square evenly; not too thick."


func update(delta: float) -> void:
	_cooldown -= delta
	var p := _plot_under_crosshair()
	if p:
		_plot = p


func _plot_under_crosshair() -> FarmPlot:
	player.ray.force_raycast_update()
	return FarmPlot.from_collider(player.ray.get_collider())


func press() -> void:
	if _cooldown > 0.0:
		return
	var plot := _plot_under_crosshair()
	var crop := Items.crop(Items.item(seed_item).crop)
	if plot == null:
		player.say("Aim at a tilled plot.")
		return
	var err := plot.state.sow_error(crop, Clock.season())
	if err != "":
		player.say(err)
		return
	if not player.inventory.remove(seed_item, 1):
		player.say("You're out of %s." % Items.name_of(seed_item).to_lower())
		stop()
		return
	_plot = plot
	_cooldown = 0.5
	var aim := plot.to_plot(player.ray.get_collision_point())
	aim += Vector2(randfn(0.0, 0.05), randfn(0.0, 0.05))
	plot.state.sow(crop, aim)
	player.viewmodel.play_throw()
	player.needs.exert(0.1)
	var hand := player.camera.global_transform * Vector3(0.2, -0.2, -0.5)
	Fx.throw(player, hand, plot.to_world(aim, 0.1), Color(0.85, 0.72, 0.45), 30, 0.015)
	Sfx.play("sow", -4.0)
	plot.get_tree().create_timer(0.4).timeout.connect(plot.refresh)
	if not player.inventory.has(seed_item):
		player.say("That was your last handful.")
		stop()


func draw(c: Control, center: Vector2) -> void:
	var origin := center + Vector2(70, -60)
	var cell := 36.0
	c.draw_rect(Rect2(origin - Vector2(6, 26), Vector2(cell * 3 + 12, cell * 3 + 32)), Color(0.12, 0.09, 0.06, 0.85))
	c.draw_string(ThemeDB.fallback_font, origin + Vector2(0, -8), "Seed cover", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.96, 0.85))
	for i in PlotState.CELLS:
		var r := Rect2(origin + Vector2(i % 3, i / 3) * cell, Vector2(cell - 3, cell - 3))
		var col := Color(0.3, 0.22, 0.15)
		if _plot:
			var d := _plot.state.seeds[i]
			match _plot.state.coverage(i):
				0:
					col = Color(0.3, 0.22, 0.15).lerp(Color(0.55, 0.5, 0.25), d / PlotState.SEED_MIN)
				1:
					col = Color(0.4, 0.7, 0.3)
				2:
					col = Color(0.85, 0.45, 0.2)
		c.draw_rect(r, col)
	var left := player.inventory.count(seed_item)
	c.draw_string(ThemeDB.fallback_font, origin + Vector2(0, cell * 3 + 18), "%d handfuls left" % left, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.96, 0.85))

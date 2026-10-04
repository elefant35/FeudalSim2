class_name DevTools
extends Node
## Developer hooks for scripted runs (screenshots, testing). Pass args after `--`, e.g.
##   Godot --path . -- --nosave --hour=9 --pos=0,0,5 --look=180,-20 --shot=/tmp/a.png
## --nosave        don't load or write the real save
## --hour=H        set the time of day
## --day=D         jump to day D (0 = first day of spring, year 1)
## --pos=x,y,z     move the player;  --look=yaw,pitch  in degrees
## --give=id:n,..  add items;  --gold=n
## --scenario=name run a setup function on the world (world.dev_scenario)
## --shot=path     save a screenshot after --wait seconds (default 2.5), then quit
## --hold=slot     select a hotbar slot
## --click         left-click whatever is under the crosshair (starts its minigame)
## --interact      press E on whatever is under the crosshair
## --newgame       after a second, run New Game once (checks a clean scene reload)

var args: Dictionary = {}
static var _reloaded := false


static func parse() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func apply(world: Node3D, player: Player) -> void:
	args = parse()
	if args.has("day"):
		Clock.total_minutes = int(args.day) * Clock.MINUTES_PER_DAY + Clock.hour() * 60.0
	if args.has("hour"):
		Clock.total_minutes = Clock.day() * Clock.MINUTES_PER_DAY + float(args.hour) * 60.0
	if args.has("rain"):
		Clock.raining = args.rain == "true"
	if args.has("gold"):
		player.wallet.add(int(args.gold))
	if args.has("give"):
		for pair: String in String(args.give).split(","):
			var p := pair.split(":")
			player.inventory.add(StringName(p[0]), int(p[1]) if p.size() > 1 else 1)
	if args.has("scenario") and world.has_method("dev_scenario"):
		world.dev_scenario(args.scenario)
	if args.has("pos"):
		var v := String(args.pos).split_floats(",")
		player.global_position = Vector3(v[0], v[1], v[2])
	if args.has("look"):
		var v := String(args.look).split_floats(",")
		player.rotation.y = deg_to_rad(v[0])
		player.head.rotation.x = deg_to_rad(v[1] if v.size() > 1 else 0.0)
	if args.has("hold"):
		player.select_slot(int(args.hold))
	if args.has("newgame") and not _reloaded:
		_reloaded = true
		await get_tree().create_timer(1.0).timeout
		world.new_game()
		return
	if args.has("interact"):
		await get_tree().create_timer(0.6).timeout
		player._update_target()
		if player.target and player.target.has_method("interact"):
			player.target.interact(player)
	if args.has("click"):
		await get_tree().create_timer(0.6).timeout
		player._update_target()
		if player.target and player.target.has_method("use"):
			var g: Minigame = player.target.use(player)
			if g:
				player.start_minigame(g)
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("wait", "2.5"))).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(args.shot))
		print("DEV screenshot saved: ", args.shot)
		get_tree().quit()


static func no_save() -> bool:
	return parse().has("nosave")

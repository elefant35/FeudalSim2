class_name DevTools
extends Node
## Developer hooks for scripted runs (screenshots, testing). Pass args after `--`, e.g.
##   Godot --path . -- --nosave --hour=9 --pos=0,0,5 --look=180,-20 --shot=/tmp/a.png
## --nosave        don't load or write the real save
## --hour=H        set the time of day
## --day=D         jump to day D (0 = first day of spring, year 1)
## --pos=x,y,z     move the player;  --look=yaw,pitch  in degrees
## --give=id:n,..  add items;  --gold=n
## --speed=n       time speed index: 0 = 1x, 1 = 2x, 2 = 4x
## --wind=deg,s    pin the wind: from this compass bearing (degrees), strength 0..1
## --scenario=name run a setup function on the world (world.dev_scenario)
## --shot=path     save a screenshot after --wait seconds (default 2.5), then quit
## --hold=slot     select a hotbar slot
## --click         left-click whatever is under the crosshair (starts its minigame)
## --interact      press E on whatever is under the crosshair
## --carry=id:n    start with n of id in your arms
## --cartpos=x,z,yaw  move the handcart first (yaw in degrees)
## --pull          take the handcart's handles
## --release       let go of the handcart after walking
## --posend=x,y,z  move the player just before the screenshot
## --lookend=yaw,pitch  where to look just before the screenshot
## --walk=seconds  walk straight ahead (prints where you end up)
## --open=panel    open a panel: guide, pack, pause
## --eat           eat something just before the screenshot
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
	if args.has("speed"):
		Clock.speed_index = int(args.speed)
		Clock.speed_changed.emit(Clock.speed())
	if args.has("wind"):
		var wv := String(args.wind).split_floats(",")
		Clock.set_wind(deg_to_rad(wv[0]), wv[1] if wv.size() > 1 else 0.5)
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
	if args.has("carry"):
		var cp := String(args.carry).split(":")
		for k in int(cp[1]) if cp.size() > 1 else 1:
			player.pick_up(StringName(cp[0]), 2)
	if args.has("cartpos"):
		var cv := String(args.cartpos).split_floats(",")
		var c: HandCart = world.get_node("HandCart")
		c.global_position = Vector3(cv[0], Terrain.height_at(cv[0], cv[1]), cv[1])
		c.global_rotation = Vector3(0, deg_to_rad(cv[2]), 0)
	if args.has("pull"):
		var cart: HandCart = world.get_node("HandCart")
		player.global_position = cart.handle_point()
		player.rotation.y = cart.global_rotation.y   # facing away from the cart, ready to pull
		cart.grab(player)
	if args.has("walk"):
		player.dev_walk_seconds = float(args.walk)
		await get_tree().create_timer(float(args.walk) + 0.2).timeout
	if args.has("release") and player.pulling:
		player.pulling.call("release", player)
	if args.has("posend"):
		var pe := String(args.posend).split_floats(",")
		player.global_position = Vector3(pe[0], pe[1], pe[2])
	if args.has("lookend"):
		var le := String(args.lookend).split_floats(",")
		player.rotation.y = deg_to_rad(le[0])
		player.head.rotation.x = deg_to_rad(le[1] if le.size() > 1 else 0.0)
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
		print("DEV interact target: ", player.target, " at ", player.target_point)
		if player.target and player.target.has_method("interact"):
			player.target.interact(player)
	if args.has("eat"):
		get_tree().create_timer(float(args.get("wait", "2.5")) - 0.4).timeout.connect(func() -> void:
			player.needs.hunger = 50.0
			player.eat_something())
	if args.has("open"):
		await get_tree().create_timer(0.5).timeout
		var hud: Hud = world.hud
		match String(args.open):
			"guide": hud.open_guide()
			"pack": hud.open_inventory()
			"pause": hud.open_pause_menu()
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


## Dev runs and tests never read or write the player's real save.
static func no_save() -> bool:
	return parse().has("nosave") or OS.get_environment("FEUDALSIM_NOSAVE") == "1"

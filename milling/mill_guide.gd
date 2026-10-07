class_name MillGuide
extends RefCounted
## The milling part of the HUD's "Next:" line and the field guide (G). Reads, never changes.


## A next step about grain, flour and your windmill, or "" when milling isn't the thing to do.
static func next_step(player: Player, mill: PostMill) -> String:
	if player.pulling is PostMill:
		var off := rad_to_deg(mill.off_wind())
		if off < 10.0:
			return "The sails face the wind. Let go of the tailpole (E)."
		return "Walk round slowly with the tailpole until the sails face the wind (%s)." % Clock.wind_string().to_lower()
	if player.is_carrying():
		var it := Items.item(player.carry_id)
		if it and it.mills_to != &"":
			if _inside(player, mill):
				return "Tip the grain into the hopper above the stones (E on it)."
			return "Take the grain to a mill: up the steps of your windmill to the hopper, or sell it to Osric at his mill to the north."
		if it and it.kind == ItemData.Kind.FLOUR:
			return "Sell your %s at the Produce Bought cart on the lane, or load it into your handcart." % Items.name_of(player.carry_id).to_lower()
		return ""
	if mill == null:
		return ""
	if mill.bin_count() >= PostMill.BIN_MAX:
		return "Your mill's meal bin is full: take the sacks out (E on the bin)."
	var loaded := mill.hopper_count() > 0 or not mill.current.is_empty()
	if loaded and mill.brake_on:
		if mill.off_wind() > deg_to_rad(25.0) and Clock.wind_strength() >= 0.15:
			return "Turn your windmill into the wind: take the tailpole (E at its end) and walk it round."
		if Clock.wind_strength() < 0.15:
			return "There's grain in your hopper but hardly any wind. Wait for a breeze."
		return "Let the brake off (the lever inside the mill) and the sails will start the stones."
	if mill.is_grinding():
		if mill.speed > PostMill.RUNAWAY:
			return "The sails are running away! Brake, then take in some cloth at the sails."
		if mill.feel_short() != "just right" and _inside(player, mill):
			return "Feel the meal at the spout, then set the stones with the tentering lever."
	if mill.running_dry:
		return "Your stones are running dry: fill the hopper or put the brake on."
	if mill.bin_count() > 0 and not mill.is_grinding():
		return "Take the flour out of your mill's meal bin (E on the bin) and sell it."
	return ""


static func _inside(player: Player, mill: PostMill) -> bool:
	if mill == null:
		return false
	var p := mill.body.to_local(player.global_position)
	return p.y > PostMill.FLOOR_Y - 0.6 and absf(p.x) < PostMill.HALF.x and absf(p.z) < PostMill.HALF.y


static func sections() -> Array:
	return [
		["Milling: your windmill",
			"Clean grain is worth more ground. Your post mill stands north-west of the house; the whole body turns on its great post.\n1. Face the wind: take the tailpole (E at its end, beside the steps) and walk slowly round until the sails face into the wind. Watch which way the pennants and the trees blow; the tailpole's prompt tells you how far off you are.\n2. Set the sails: with the brake on and the sails stopped, E at the sails spreads more cloth, click takes some in. Light wind wants full sail; a strong wind wants it reefed, or the sails run away.\n3. Fill the hopper: carry sacks of clean grain up the steps and tip them in (E).\n4. Let the brake off (the lever inside). The stones grind into the meal bin.\n5. Tend the stones: feel the meal at the spout (E). Hot means the stones are too close for the speed: open them with the tentering lever (click and move the mouse up). Gritty means too far apart: bring them down. Fine, cool meal keeps the grain's quality; rough or scorched meal loses some.\n6. Take the sacks from the bin (E) and sell flour or meal at the Produce Bought cart."],
		["The miller",
			"Osric keeps the village mill to the north. He buys clean grain at his store beside the mill (E there with grain in your arms or your handcart parked close), and grinds it himself. Wynn sells him his grain too. The produce buyer won't take raw grain: it's the mill or nothing."],
	]

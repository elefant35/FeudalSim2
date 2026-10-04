class_name Ground
extends StaticBody3D
## The terrain. Holding a placeable (a scarecrow), click the ground to set it down.


func _field() -> Field:
	return get_tree().get_first_node_in_group("field")


func get_prompt(player: Player) -> String:
	if player.held() != &"scarecrow":
		return ""
	var err := _field().scarecrow_error(player.target_point)
	return err if err != "" else "[Click] Set the scarecrow up here"


func use(player: Player) -> Minigame:
	if player.held() != &"scarecrow":
		return null
	var err := _field().scarecrow_error(player.target_point)
	if err != "":
		player.say(err)
		return null
	if player.inventory.remove(&"scarecrow"):
		_field().place_scarecrow(player.target_point)
		Sfx.play_at("thump", player.target_point)
		player.say("The scarecrow will keep crows off the nearby plots.")
	return null

class_name Ground
extends StaticBody3D
## The terrain. With the hoe, click open ground to break a new plot there; holding a
## scarecrow, click to set it up.


func _field() -> Field:
	return get_tree().get_first_node_in_group("player_field")


func get_prompt(player: Player) -> String:
	match player.held():
		&"hoe":
			var pos := _field().snap(player.target_point)
			var err := _field().placement_error(pos)
			_field().show_preview(pos, err == "")
			return err if err != "" else "[Click] Break new ground for a plot here"
		&"scarecrow":
			var err := _field().scarecrow_error(player.target_point)
			return err if err != "" else "[Click] Set the scarecrow up here"
	return ""


func use(player: Player) -> Minigame:
	match player.held():
		&"hoe":
			var pos := _field().snap(player.target_point)
			var err := _field().placement_error(pos)
			if err != "":
				player.say(err)
				return null
			var plot := _field().add_plot(pos)
			player.say("You mark out a new plot. Break the sod with good strikes.")
			return TillGame.new(plot)
		&"scarecrow":
			var err := _field().scarecrow_error(player.target_point)
			if err != "":
				player.say(err)
				return null
			if player.inventory.remove(&"scarecrow"):
				_field().place_scarecrow(player.target_point)
				Sfx.play_at("thump", player.target_point)
				player.say("The scarecrow will keep crows off the nearby plots.")
	return null

class_name Bed
extends StaticBody3D
## Your bed. Sleep ends the day (and saves).


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.0, 0.7, 2.0)
	shape.shape = b
	shape.position.y = 0.35
	add_child(shape)


func get_prompt(player: Player) -> String:
	var tired := "You're exhausted." if player.needs.energy < Needs.TIRED else ""
	return "Your bed  %s\n[E] Sleep until morning (saves the game)" % tired


func interact(_player: Player) -> void:
	get_tree().current_scene.try_sleep()

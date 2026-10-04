class_name Well
extends StaticBody3D
## The well. Hold your bucket and click to wind up water.

const BUCKET_DOWN := 0.75
const BUCKET_UP := 1.5

var _crank: Node3D
var _bucket: Node3D


func _ready() -> void:
	var m := Models.make(&"well")
	add_child(m)
	_crank = m.find_child("crank", true, false)
	_bucket = m.find_child("well_bucket", true, false)
	if _bucket:
		_bucket.position.y = BUCKET_UP
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.95
	cyl.height = 2.4
	shape.shape = cyl
	shape.position.y = 1.2
	add_child(shape)


func set_crank(angle: float, progress: float) -> void:
	if _crank:
		_crank.rotation.x = angle
	if _bucket:
		_bucket.position.y = lerpf(BUCKET_DOWN, BUCKET_UP, progress)


func lower_bucket() -> void:
	if _bucket:
		create_tween().tween_property(_bucket, "position:y", BUCKET_UP, 0.6)


func get_prompt(player: Player) -> String:
	if player.held() != &"bucket":
		return "Well\nHold your bucket to draw water." if player.inventory.has(&"bucket") else "Well\nYou need a bucket (sold at the tool stall)."
	if player.bucket_water() >= 1.0:
		return "Well\nYour bucket is full."
	return "Well\n[Hold left and circle the mouse] Draw water"


func use(player: Player) -> Minigame:
	if player.held() != &"bucket" or player.bucket_water() >= 1.0:
		return null
	if _bucket:
		var t := create_tween()
		t.tween_property(_bucket, "position:y", BUCKET_DOWN, 0.5).set_ease(Tween.EASE_IN)
		Sfx.play_at("splash", global_position + Vector3(0, 0.3, 0), -8.0)
	return WellGame.new(self)

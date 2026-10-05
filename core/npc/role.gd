class_name Role
extends RefCounted
## A profession a villager can step into (farmer now; baker, smith... later). A role reads the
## world and hands its villager the next Task; it uses the same world objects and rules as the
## player. The Npc handles the body (walking, animation) and basic needs (sleep, food), so a
## new role is only its decisions.

var npc: Npc
## The role's title, e.g. "farmer".
var title: String = "villager"


## The next thing to do, or null to idle a while.
func next_task() -> Task:
	return null


## What they'd tell you if you asked how it's going.
func chat_line() -> String:
	return "Good day."


## Food the role can fetch if the villager is hungry and their pack is empty (or null).
func fetch_food() -> Task:
	return null


func on_day_started() -> void:
	pass


func to_dict() -> Dictionary:
	return {}


func from_dict(_d: Dictionary) -> void:
	pass

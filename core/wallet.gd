class_name Wallet
extends Node
## Gold coins. Just an integer; prices live in item data.

signal changed(gold: int)

var gold: int = 0


func add(amount: int) -> void:
	gold += amount
	changed.emit(gold)


func can_afford(amount: int) -> bool:
	return gold >= amount


func spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit(gold)
	return true

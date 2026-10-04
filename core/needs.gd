class_name Needs
extends Node
## Hunger and energy. A component any character can carry (the player now, villagers later).
## Both run 0..100 where 100 is good (full, rested).

signal changed
signal collapsed(reason: String)

const HUNGER_PER_HOUR := 100.0 / 40.0     ## Full to starving in ~40 waking hours.
const ENERGY_PER_HOUR := 100.0 / 19.0     ## Rested to collapse in ~19 waking hours.
const STARVING_ENERGY_MULT := 2.0
const SLEEP_HOURS_FOR_FULL := 7.0
const TIRED := 25.0
const HUNGRY := 25.0

var hunger: float = 90.0
var energy: float = 100.0


## Waking time passing. Work makes it pass harder via `exert`.
func pass_hours(hours: float) -> void:
	hunger = maxf(0.0, hunger - HUNGER_PER_HOUR * hours)
	var drain := ENERGY_PER_HOUR * hours
	if hunger <= 0.0:
		drain *= STARVING_ENERGY_MULT
	_spend_energy(drain)
	changed.emit()


## Physical work: costs energy and makes you hungrier.
func exert(amount: float) -> void:
	hunger = maxf(0.0, hunger - amount * 0.4)
	_spend_energy(amount)
	changed.emit()


func eat(food_value: float) -> void:
	hunger = minf(100.0, hunger + food_value)
	changed.emit()


func sleep(hours: float) -> void:
	energy = minf(100.0, energy + hours * 100.0 / SLEEP_HOURS_FOR_FULL)
	hunger = maxf(0.0, hunger - HUNGER_PER_HOUR * hours * 0.25)
	changed.emit()


func _spend_energy(amount: float) -> void:
	var was_up := energy > 0.0
	energy = maxf(0.0, energy - amount)
	if was_up and energy <= 0.0:
		collapsed.emit("You collapse from starvation and exhaustion." if hunger <= 0.0 else "You collapse from exhaustion.")


## Movement and work slow down when tired or starving.
func speed_factor() -> float:
	var f := 1.0
	if energy < TIRED:
		f *= lerpf(0.55, 1.0, energy / TIRED)
	if hunger <= 0.0:
		f *= 0.8
	return f


func to_dict() -> Dictionary:
	return {"hunger": hunger, "energy": energy}


func from_dict(d: Dictionary) -> void:
	hunger = float(d.get("hunger", 85.0))
	energy = float(d.get("energy", 100.0))
	changed.emit()

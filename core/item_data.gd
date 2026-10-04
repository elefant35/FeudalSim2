class_name ItemData
extends Resource
## One kind of item: tools, seeds, produce, food. Lives as a .tres file so any chunk can use it.

enum Kind { TOOL, SEED, PRODUCE, FOOD, GRAIN, PLACEABLE }

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.TOOL
## Price at the tool stall for one purchase (0 = not sold there).
@export var buy_price: int = 0
## How many units one purchase gives (seed is sold by the bag).
@export var buy_quantity: int = 1
## Base price the produce buyer pays per unit at "fair" quality (0 = won't buy).
@export var sell_price: int = 0
## Hunger restored when eaten (0 = not edible).
@export var food_value: float = 0.0
## Whether units carry a quality grade (produce, grain).
@export var has_quality: bool = false
## For seeds: which crop they grow.
@export var crop: StringName
## Shown in the hotbar (tools, seeds, placeables).
@export var hotbar: bool = false

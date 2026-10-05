class_name CropData
extends Resource
## How one crop grows. Seasons: 0 spring, 1 summer, 2 autumn, 3 winter.

enum Harvest { HANDS, SICKLE }

@export var id: StringName
@export var display_name: String = ""
@export var seed_item: StringName
## What a harvested plant gives (produce for root crops, sheaves for grain).
@export var product_item: StringName
@export var sow_seasons: PackedInt32Array = PackedInt32Array([0])
## Days of full-rate growth until ripe.
@export var grow_days: float = 5.0
## Growth per day in each season (1.0 = full rate).
@export var season_growth: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.8, 0.0])
## Survives the frost when winter begins.
@export var hardy: bool = false
@export var harvest: Harvest = Harvest.HANDS
@export var gets_caterpillars: bool = false
## Daily chance a healthy plant catches blight (doubled in rain).
@export var blight_chance: float = 0.02
## Biennials (turnip, cabbage) left in the ground this many days after ripening bolt: they send
## up a flowering stalk and go to seed. Pulling one then gives seed instead of produce.
## 0 = doesn't bolt (grain is its own seed: keep a sack of clean grain as seed instead).
@export var bolt_days: int = 0
## Handfuls of seed gathered from each bolted plant.
@export var bolt_seed: int = 0
## Visual: which procedural model family to draw.
@export var look: StringName = &"turnip"


func can_sow_in(season: int) -> bool:
	return season in sow_seasons

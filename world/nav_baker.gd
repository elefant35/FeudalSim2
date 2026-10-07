class_name NavBaker
extends RefCounted
## Bakes the walkable area for villagers from the world's solid shapes (buildings, fences,
## trees, the well...), limited to the farms. Runs on a thread at startup; villagers walk in
## straight lines until it's ready.

const AREA := AABB(Vector3(-34, -3, -34), Vector3(78, 14, 60))
const CELL := 0.15


static func bake(world: Node3D) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"nav_source"
	# A fine grid: the 0.3 m body margin rounds up to whole cells, and on a coarse grid that
	# closes the 1.1 m cottage doorways.
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.agent_height = 1.65   # whole cells (11 × 0.15)
	nm.agent_radius = 0.3   # matches the body; any wider and cottage doorways close up
	nm.agent_max_climb = 0.3   # whole cells (2 × 0.15)
	nm.agent_max_slope = 40.0
	nm.filter_baking_aabb = AREA
	var map := world.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL)
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = nm
	world.add_child(region)
	world.add_to_group(&"nav_source")
	region.bake_finished.connect(func() -> void: print("Navigation baked: %d polygons" % nm.get_polygon_count()))
	region.bake_navigation_mesh(true)
	return region

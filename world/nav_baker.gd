class_name NavBaker
extends RefCounted
## Bakes the walkable area for villagers from the world's solid shapes (buildings, fences,
## trees, the well...), limited to the farms. Runs on a thread at startup; villagers walk in
## straight lines until it's ready.

const AREA := AABB(Vector3(-32, -3, -26), Vector3(76, 14, 52))


static func bake(world: Node3D) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"nav_source"
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_height = 1.7
	nm.agent_radius = 0.4
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 40.0
	nm.filter_baking_aabb = AREA
	var region := NavigationRegion3D.new()
	region.name = "Navigation"
	region.navigation_mesh = nm
	world.add_child(region)
	world.add_to_group(&"nav_source")
	region.bake_finished.connect(func() -> void: print("Navigation baked: %d polygons" % nm.get_polygon_count()))
	region.bake_navigation_mesh(true)
	return region

class_name RainEffect
extends RefCounted
## Falling rain streaks that follow the player.


static func make() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 3000
	p.lifetime = 1.0
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -15, -20), Vector3(40, 20, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 1, 18)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, -9.8, 0)
	# Drops vanish when they hit a GPUParticlesCollision shape (the cottage roof).
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	p.collision_base_size = 0.05
	p.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.015, 0.45)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mesh.material = m
	p.draw_pass_1 = mesh
	return p

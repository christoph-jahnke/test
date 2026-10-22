# Run with a graphical display: godot --path . --script res://tools/capture_portraits.gd
extends SceneTree
const Assets = preload("res://game/asset_catalog.gd")
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	for index in 9:
		var viewport = SubViewport.new()
		viewport.size = Vector2i(160, 160)
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var environment = WorldEnvironment.new()
		environment.environment = Environment.new()
		var sky = Sky.new()
		sky.sky_material = ProceduralSkyMaterial.new()
		environment.environment.sky = sky
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.environment.ambient_light_energy = 0.7
		viewport.add_child(environment)
		var light = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50, -25, 0)
		light.light_energy = 1.3
		viewport.add_child(light)
		viewport.add_child(Assets.create(index))
		var camera = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.8
		camera.position = Vector3(2.8, 2.3, -3.2)
		viewport.add_child(camera)
		camera.look_at(Vector3(0, 0.8, 0))
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(Assets.portrait_path(index)) == OK)
		viewport.queue_free()
	await process_frame
	quit()

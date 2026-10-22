extends SceneTree

const Assets = preload("res://game/asset_catalog.gd")

func _initialize() -> void:
	call_deferred("check_models")

func counts(node: Node, result: Dictionary) -> void:
	if node is MeshInstance3D:
		result.meshes += 1
		for surface in node.mesh.get_surface_count():
			var arrays = node.mesh.surface_get_arrays(surface)
			result.vertices += arrays[Mesh.ARRAY_VERTEX].size()
			var indices = arrays[Mesh.ARRAY_INDEX]
			result.triangles += indices.size() / 3 if indices != null else arrays[Mesh.ARRAY_VERTEX].size() / 3
	for child in node.get_children():
		counts(child, result)

func check_models() -> void:
	assert(Assets.IDS.size() == 20)
	var signatures = {}
	var total_triangles = 0
	for index in 20:
		var model = Assets.create(index)
		root.add_child(model)
		var result = {"meshes": 0, "vertices": 0, "triangles": 0}
		counts(model, result)
		assert(result.meshes > 0 and result.vertices > 100, "Imported mesh data is required")
		if index < 9:
			assert(model.find_child("Head", true, false) != null, "Turret aiming pivot must survive export")
		if index == 4:
			assert(model.find_child("Rotor", true, false) != null, "Gatling needs a separate rotor")
		if index >= 9 and index <= 12:
			assert(model.find_child("LegL", true, false) != null and model.find_child("LegR", true, false) != null)
		var bytes = FileAccess.get_file_as_bytes("res://models/%s.glb" % Assets.IDS[index])
		var digest = HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(bytes)
		signatures[digest.finish().hex_encode()] = true
		total_triangles += result.triangles
		print("MODEL %02d: %d meshes / %d triangles" % [index + 1, result.meshes, result.triangles])
		model.free()
	assert(signatures.size() == 20, "No duplicate model files")
	# All nine gameplay combinations must map to their individual assets.
	var chosen = {}
	for kind in 3:
		for branch in [-1, 0, 1]:
			chosen[Assets.tower_index(kind, branch)] = true
	assert(chosen.size() == 9)
	var gallery = load("res://game/model_gallery.tscn").instantiate()
	root.add_child(gallery)
	gallery.show_all()
	assert(gallery.display.get_child_count() == 60)
	gallery.show_model(4)
	assert(not gallery.all_models and gallery.selection == 4)
	gallery.queue_free()
	await process_frame
	print("PASS: 20 distinct GLB meshes, turret/leg pivots, nine tower variants, live gallery; %d combined triangles" % total_triangles)
	quit(0)

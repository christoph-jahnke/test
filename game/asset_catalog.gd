extends RefCounted

const IDS = [
	"01_marine_sentinel", "02_mortar_bulwark", "03_cryo_prism",
	"04_sniper_lancer", "05_assault_reaper", "06_siege_judgement",
	"07_cluster_hydra", "08_deepfreeze_zero", "09_fieldcontrol_pulse",
	"10_zombie_walker", "11_zombie_runner", "12_zombie_armored", "13_zombie_titan",
	"14_road_asphalt", "15_road_steel", "16_road_quarantine", "17_road_ruined",
	"18_bunker_command", "19_reactor", "20_barricade",
	"21_supply_crate", "22_ammo_cache", "23_generator_aux", "24_comms_mast",
	"25_floodlight", "26_pipe_junction", "27_blast_crater", "28_rubble_pile",
	"29_wreck_rover", "30_medical_shelter", "31_habitat_ruined", "32_gate_checkpoint"
]
const NAMES = [
	"Sentinel / Marine", "Bulwark / Mörser", "Prism / Kryo",
	"Lancer / Scharfschütze", "Reaper / Sturmgeschütz", "Judgement / Belagerung",
	"Hydra / Streubomben", "Zero / Tiefkälte", "Pulse / Feldkontrolle",
	"Infizierter", "Hetzer", "Panzer-Infizierter", "Titan",
	"Asphalt / Narben", "Stahl / Drainage", "Quarantäne / Sperrzone", "Ruinen / Risse",
	"Kommando-Bunker", "Reaktor R-09", "Rasierdraht-Barrikade",
	"Versorgungskiste", "Munitionslager", "Hilfsgenerator", "Funkmast",
	"Flutlicht", "Rohrverteiler", "Einschlagkrater", "Trümmerfeld",
	"Rover-Wrack", "Feldlazarett", "Habitat-Ruine", "Kontrolltor"
]
static var cache: Dictionary = {}
static var surface_cache: Dictionary = {}

static func create(index: int) -> Node3D:
	assert(index >= 0 and index < IDS.size())
	if not cache.has(index):
		cache[index] = load("res://models/%s.glb" % IDS[index])
	var model = (cache[index] as PackedScene).instantiate()
	model.set_meta("asset_id", IDS[index])
	apply_surface_style(model)
	return model

static func tower_index(kind: int, branch: int) -> int:
	return kind if branch < 0 else 3 + kind * 2 + branch

static func enemy_index(kind: String) -> int:
	return {"Zombie": 9, "Sprinter": 10, "Panzer": 11, "Titan": 12}.get(kind, 9)

# Shared surface textures add wear without duplicating them for every instance.
static func worn_material(original: StandardMaterial3D) -> StandardMaterial3D:
	if original.emission_enabled:
		return original
	var key = str(original.albedo_color) + str(original.metallic) + str(original.roughness)
	if surface_cache.has(key):
		return surface_cache[key]
	var result = original.duplicate() as StandardMaterial3D
	result.metallic = minf(original.metallic, 0.5)
	result.roughness = maxf(original.roughness, 0.68)
	var paint = Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rough = Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(key)
	for y in 128:
		for x in 128:
			var shade = rng.randf_range(0.86, 1.0)
			if rng.randf() < 0.018:
				shade *= 0.55
			paint.set_pixel(x, y, Color(shade, shade * 0.99, shade * 0.97))
			var value = rng.randf_range(0.78, 1.0)
			rough.set_pixel(x, y, Color(value, value, value))
	# Directional scuffs break up large uniform painted panels.
	for mark in 20:
		var x = rng.randi_range(2, 125)
		var y = rng.randi_range(1, 105)
		for step in rng.randi_range(3, 18):
			paint.set_pixel(mini(127, x + step / 5), y + step, Color(0.64, 0.65, 0.66))
	paint.generate_mipmaps()
	rough.generate_mipmaps()
	result.albedo_texture = ImageTexture.create_from_image(paint)
	result.roughness_texture = ImageTexture.create_from_image(rough)
	result.set_meta("surface_style", "worn_08")
	surface_cache[key] = result
	return result

static func apply_surface_style(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material is StandardMaterial3D:
				node.set_surface_override_material(surface, worn_material(material))
	for child in node.get_children():
		apply_surface_style(child)

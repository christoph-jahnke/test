extends RefCounted

const IDS = [
	"01_marine_sentinel", "02_mortar_bulwark", "03_cryo_prism",
	"04_sniper_lancer", "05_assault_reaper", "06_siege_judgement",
	"07_cluster_hydra", "08_deepfreeze_zero", "09_fieldcontrol_pulse",
	"10_zombie_walker", "11_zombie_runner", "12_zombie_armored", "13_zombie_titan",
	"14_road_asphalt", "15_road_steel", "16_road_quarantine", "17_road_ruined",
	"18_bunker_command", "19_reactor", "20_barricade"
]
const NAMES = [
	"Sentinel / Marine", "Bulwark / Mörser", "Prism / Kryo",
	"Lancer / Scharfschütze", "Reaper / Sturmgeschütz", "Judgement / Belagerung",
	"Hydra / Streubomben", "Zero / Tiefkälte", "Pulse / Feldkontrolle",
	"Infizierter", "Hetzer", "Panzer-Infizierter", "Titan",
	"Asphalt / Narben", "Stahl / Drainage", "Quarantäne / Sperrzone", "Ruinen / Risse",
	"Kommando-Bunker", "Reaktor R-09", "Rasierdraht-Barrikade"
]
static var cache: Dictionary = {}

static func create(index: int) -> Node3D:
	assert(index >= 0 and index < IDS.size())
	if not cache.has(index):
		cache[index] = load("res://models/%s.glb" % IDS[index])
	var model = (cache[index] as PackedScene).instantiate()
	model.set_meta("asset_id", IDS[index])
	return model

static func tower_index(kind: int, branch: int) -> int:
	return kind if branch < 0 else 3 + kind * 2 + branch

static func enemy_index(kind: String) -> int:
	return {"Zombie": 9, "Sprinter": 10, "Panzer": 11, "Titan": 12}.get(kind, 9)

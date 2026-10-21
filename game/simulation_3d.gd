extends "res://game/main.gd"

const LARGE_ROUTE = [Vector2(-120, 210), Vector2(220, 210), Vector2(220, 510), Vector2(500, 510), Vector2(500, 160), Vector2(800, 160), Vector2(800, 640), Vector2(1120, 640), Vector2(1120, 340), Vector2(1480, 340)]
const LARGE_PADS = [Vector2(80, 140), Vector2(125, 340), Vector2(315, 300), Vector2(330, 600), Vector2(420, 400), Vector2(595, 265), Vector2(640, 70), Vector2(725, 390), Vector2(895, 255), Vector2(905, 505), Vector2(970, 735), Vector2(1205, 535), Vector2(1035, 420), Vector2(1240, 245), Vector2(1350, 440), Vector2(610, 600)]
var overdrive = 0.0
var overdrive_cooldown = 0.0

func get_route() -> Array:
	return LARGE_ROUTE

func get_pads() -> Array:
	return LARGE_PADS

func activate_overdrive() -> void:
	if paused or lives <= 0 or overdrive_cooldown > 0:
		return
	overdrive = 8.0
	overdrive_cooldown = 45.0
	gameplay_event.emit("cryo")

func reset_run() -> void:
	super.reset_run()
	overdrive = 0
	overdrive_cooldown = 0

func _process(delta: float) -> void:
	if not paused and lives > 0:
		overdrive = maxf(0, overdrive - delta * speed)
		overdrive_cooldown = maxf(0, overdrive_cooldown - delta * speed)
		if overdrive > 0:
			for tower in towers:
				tower.cooldown -= delta * speed
	super._process(delta)

func _draw() -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	pass

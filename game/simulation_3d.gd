extends "res://game/main.gd"

# Reuse combat/economy and CanvasLayer UI without the legacy 2D renderer/input.
func _draw() -> void:
	pass

func _unhandled_input(_event: InputEvent) -> void:
	pass

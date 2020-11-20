extends Node

class player_constants:
	var gravity := 49.0
	var gravity_max_velocity := 75.0
	var ground_acceleration := 35.0
	var ground_max_velocity := 20.0
	var air_acceleration := 20.0
	var air_max_velocity := 25.0

onready var player := player_constants.new()

var _next_free_portal_cull = 0

func get_portal_cull() -> int:
	var free_cull = _next_free_portal_cull
	_next_free_portal_cull += 1
	match free_cull:
		0:
			return Utils.VisualLayers.PORTAL_CULL_0
		1:
			return Utils.VisualLayers.PORTAL_CULL_1
	return -1

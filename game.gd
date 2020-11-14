extends Spatial


export(NodePath) var player_path

onready var player: Player = get_node(player_path)

func _ready() -> void:
	player.is_main_view = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

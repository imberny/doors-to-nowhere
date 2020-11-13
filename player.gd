class_name Player
extends KinematicBody



var is_main_view: bool setget _set_is_main_view

var _input_dir := Vector3.ZERO

var velocity := Vector3.ZERO
var acceleration := 1.5
var friction := 5.0
var mouse_sensitivity := 0.008
var cam_angle_min := -88
var cam_angle_max := 88
var gravity := 20.0



func _shoot_primary() -> void:
	pass
#	if $Camera/RayCast.is_colliding():
#		var point := $Camera/RayCast.get_collision_point()
		


func _input(event) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Camera.rotate_x(-event.relative.y * mouse_sensitivity)
		$Camera.rotation.x = clamp($Camera.rotation.x, deg2rad(cam_angle_min), deg2rad(cam_angle_max))
	if event.is_action("primary_fire"):
		_shoot_primary()

	var forward := -Input.get_action_strength("forward")
	var backward := Input.get_action_strength("backward")
	var left := -Input.get_action_strength("left")
	var right := Input.get_action_strength("right")
	var dir = Vector3.ZERO
	dir += (forward + backward) * global_transform.basis.z
	dir += (left + right) * $Camera.global_transform.basis.x
	_input_dir = dir.normalized()



func _physics_process(delta: float) -> void:
	velocity = BunnyHopMovement.move(
		_input_dir,
		velocity,
		5.0,
		1.0,
		true,
		delta
	)
	velocity += gravity * Vector3.DOWN * delta
	
	velocity = move_and_slide(velocity, Vector3.UP)


func _set_is_main_view(value: bool) -> void:
	$Camera.current = value
#	$Body/LeftEye.visible = not value
#	$Body/RightEye.visible = not value

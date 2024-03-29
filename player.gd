class_name Player
extends KinematicBody

export(PackedScene) var portal_scene



var is_main_view: bool setget _set_is_main_view

var _input_dir := Vector3.ZERO

var velocity := Vector3.ZERO
var acceleration := 1.5
var friction := 5.0
var mouse_sensitivity := 0.008
var cam_angle_min := -88
var cam_angle_max := 88
var gravity := 49.0
var sprint_modifier := 1.6
var crouch_modifier := 0.3

var model: MeshInstance setget , _get_model

onready var _portal_a = portal_scene.instance()
onready var _portal_b = portal_scene.instance()


func _ready() -> void:
	$Camera.near = 0.0004
	_portal_a.exit_portal = _portal_b
	_portal_b.exit_portal = _portal_a
	_portal_a.transform.origin.y = -100
	_portal_b.transform.origin.y = -100
	get_tree().current_scene.call_deferred("add_child", _portal_a)
	get_tree().current_scene.call_deferred("add_child", _portal_b)


func _place_portal(portal) -> void:
	if $Camera/RayCast.is_colliding():
		var point: Vector3 = $Camera/RayCast.get_collision_point()
		var normal: Vector3 = $Camera/RayCast.get_collision_normal()
		portal.look_at_from_position(point + 0.05 * normal, point - normal, Vector3.UP)


func _input(event) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Camera.rotate_x(-event.relative.y * mouse_sensitivity)
		$Camera.rotation.x = clamp($Camera.rotation.x, deg2rad(cam_angle_min), deg2rad(cam_angle_max))
	if event.is_action_pressed("primary_fire"):
		_place_portal(_portal_a)
	if event.is_action_pressed("secondary_fire"):
		_place_portal(_portal_b)


func _process(_delta: float) -> void:
	var forward := -Input.get_action_strength("forward")
	var backward := Input.get_action_strength("backward")
	var left := -Input.get_action_strength("left")
	var right := Input.get_action_strength("right")
	var dir = Vector3.ZERO
	dir += (forward + backward) * global_transform.basis.z
	dir += (left + right) * $Camera.global_transform.basis.x
	_input_dir = dir.normalized()



func _physics_process(delta: float) -> void:
	var speed_modifier = 1.0
	if Input.is_action_pressed("sprint"):
		speed_modifier *= sprint_modifier
	if Input.is_action_pressed("crouch"):
		speed_modifier *= crouch_modifier
	velocity = BunnyHopMovement.move(
		_input_dir,
		velocity,
		friction,
		speed_modifier,
		true,
		delta
	)
	velocity += gravity * Vector3.DOWN * delta
	
	velocity = move_and_slide(
		velocity,
		Vector3.UP,
		false, # stops on slope, default false
		4, # max slides, default 4
		0.785398, # max floor angle, default: 0.785398
		true # infinite inertia, default true
	)


func _set_is_main_view(value: bool) -> void:
	$Camera.current = value
#	$Body/LeftEye.visible = not value
#	$Body/RightEye.visible = not value

func _get_model():
	return $Body

class_name Portal
extends Area

export(NodePath) var portal_path
export(float) var zoom = 1.0

var exit_portal: Portal setget _set_exit_portal
var my_cam: Camera
var _player: Player
onready var _bodies_in_portal := {}
onready var _body_doubles := {}

func _ready() -> void:
	if portal_path:
		exit_portal = get_node(portal_path)
	my_cam = $Camera
	remove_child(my_cam)
	$Viewport.add_child(my_cam)
	var plane_normal = global_transform.basis.z.normalized()
	var plane_dist = global_transform.origin.project(plane_normal).length()
	var portal_plane = Plane(plane_normal, plane_dist)
	$Quad.get_surface_material(0).set_shader_param("portal_plane", -plane_normal)
	$Quad.get_surface_material(0).set_shader_param("portal_plane_dist", portal_plane.d)


func _get_exit_position(entry: Portal, exit: Portal, position: Vector3) -> Vector3:
	var entry_to_exit = exit.global_transform * entry.global_transform.affine_inverse()
	var exit_pos = entry_to_exit * position
	var exit_delta_pos = exit.global_transform.origin - exit_pos
	exit_pos += exit_delta_pos + exit_delta_pos.bounce(exit.global_transform.basis.y.normalized())
	return exit_pos


func _get_exit_quaternion(entry: Portal, exit: Portal, quat: Quat) -> Quat:
	var world_to_entry := Quat(entry.global_transform.basis.orthonormalized()).inverse()
	var exit_to_world := Quat(exit.global_transform.basis.orthonormalized())
	var entry_to_exit := world_to_entry * exit_to_world
	return entry_to_exit * quat


func _process(_delta) -> void:
	var cam := get_viewport().get_camera()
	
	var cam_global_origin = cam.global_transform.origin
	var dist: float = (cam_global_origin - exit_portal.global_transform.origin).length()
	
	var dolly = Transform.IDENTITY
	var cam_half_vert_rot_basis = Basis(cam.global_transform.basis.x, cam.rotation.x * (PI/2.0) / (dist))
	var exit_basis = global_transform.basis
	exit_basis = cam_half_vert_rot_basis * exit_basis
	dolly.basis.y *= -1.0
	dolly.basis *= Basis(_get_exit_quaternion(self, exit_portal, Quat(cam.global_transform.basis.orthonormalized())))
	dolly.basis.y *= -1.0
	dolly.origin = _get_exit_position(self, exit_portal, cam_global_origin)

	# place my cam on dolly
	my_cam.global_transform = dolly
	my_cam.rotate(my_cam.global_transform.basis.y, PI)
	var dist2 = (exit_portal.global_transform.origin - dolly.origin).length()
	my_cam.near = max(dist2 - 3.0, 0.01)
	$Quad.get_surface_material(0).set_shader_param("zoom", zoom)


func _physics_process(delta) -> void:
	if _player:
		var cam = get_viewport().get_camera()
		var cam_pos = cam.global_transform.origin
		# predict next frame pos
		var cam_next_pos = cam_pos + _player.velocity * delta
		var cam_next_dir = (cam_next_pos - global_transform.origin).normalized()
		if 0 > cam_next_dir.dot(global_transform.basis.z):
			var exit_pos = _get_exit_position(self, exit_portal, _player.global_transform.origin)
			var exit_quat = _get_exit_quaternion(self, exit_portal, _player.global_transform.basis)
			_player.global_transform.origin = exit_pos
			_player.global_transform.basis = Basis(exit_quat)
			_player.rotate(_player.global_transform.basis.y, PI)
			var velocity_angle = acos(_player.velocity.normalized().dot(-global_transform.basis.z))
			var exit_forward = exit_portal.global_transform.basis.z.normalized()
			var exit_up = exit_portal.global_transform.basis.y.normalized()
			_player.velocity = exit_forward.rotated(exit_up, velocity_angle) * _player.velocity.length()
	for body_id in _bodies_in_portal:
		var rbody := _bodies_in_portal[body_id] as RigidBody
		# update double
		var double = _body_doubles[body_id] as RigidBody
		if 0 < rbody.linear_velocity.length():
			var velocity_angle = acos(rbody.linear_velocity.normalized().dot(-global_transform.basis.z))
			var exit_forward = exit_portal.global_transform.basis.z.normalized()
			var exit_up = exit_portal.global_transform.basis.y.normalized()
			double.linear_velocity = exit_forward.rotated(exit_up, velocity_angle) * rbody.linear_velocity.length()
		elif 0 < double.linear_velocity.length():
			var velocity_angle = acos(double.linear_velocity.normalized().dot(-exit_portal.global_transform.basis.z))
			var entry_forward = global_transform.basis.z.normalized()
			var entry_up = global_transform.basis.y.normalized()
			rbody.linear_velocity = entry_forward.rotated(entry_up, velocity_angle) * double.linear_velocity.length()
		
		var body_next_pos = rbody.global_transform.origin + rbody.linear_velocity * delta
		var body_next_dir = (body_next_pos - global_transform.origin).normalized()
		if 0 > body_next_dir.dot(global_transform.basis.z):
			var exit_pos = _get_exit_position(self, exit_portal, rbody.global_transform.origin)
			var exit_quat = _get_exit_quaternion(self, exit_portal, rbody.global_transform.basis)
			rbody.global_transform.origin = exit_pos
			rbody.global_transform.basis = Basis(exit_quat)
			rbody.rotate(rbody.global_transform.basis.y, PI)
			var velocity_angle = acos(rbody.linear_velocity.normalized().dot(-global_transform.basis.z))
			var exit_forward = exit_portal.global_transform.basis.z.normalized()
			var exit_up = exit_portal.global_transform.basis.y.normalized()
			rbody.linear_velocity = exit_forward.rotated(exit_up, velocity_angle) * rbody.linear_velocity.length()


func _set_exit_portal(value: Portal) -> void:
	exit_portal = value


func _on_body_entered(body):
	if body is Player:
		_player = body
		(body as PhysicsBody).collision_layer ^= 1
		(body as PhysicsBody).collision_mask ^= 1 << 1
		(body as PhysicsBody).collision_mask ^= 1 << 2
	if body is RigidBody and not body.is_in_group("doubles"):
		_bodies_in_portal[body.get_rid()] = body
		var double: RigidBody = body.duplicate()
		double.add_to_group("doubles")
		_body_doubles[body.get_rid()] = double
		add_child(double)
		double.global_transform.origin = _get_exit_position(self, exit_portal, body.global_transform.origin)
		var double_quat := _get_exit_quaternion(self, exit_portal, Quat(body.global_transform.basis))
		double.global_transform.basis = Basis(double_quat)
		(body as PhysicsBody).collision_layer ^= 2
		(body as PhysicsBody).collision_mask ^= 1
		(body as PhysicsBody).collision_mask ^= 1 << 1
		(body as PhysicsBody).collision_mask ^= 1 << 2
	
	(body as PhysicsBody).collision_layer ^= 1 << 12


func _on_body_exited(body):
	if body is Player:
		_player = null
		(body as PhysicsBody).collision_layer ^= 1
		(body as PhysicsBody).collision_mask ^= 1 << 1
		(body as PhysicsBody).collision_mask ^= 1 << 2
	if body is RigidBody and not body.is_in_group("doubles"):
		var double = _body_doubles[body.get_rid()]
		remove_child(double)
		var _err = _bodies_in_portal.erase(body.get_rid())
		_err = _body_doubles.erase(body.get_rid())
		double.queue_free()
		(body as PhysicsBody).collision_layer ^= 2
		(body as PhysicsBody).collision_mask ^= 1
		(body as PhysicsBody).collision_mask ^= 1 << 1
		(body as PhysicsBody).collision_mask ^= 1 << 2

	(body as PhysicsBody).collision_layer ^= 1 << 12

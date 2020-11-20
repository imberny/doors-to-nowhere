class_name Portal
extends Area

export(NodePath) var portal_path
export(float) var shader_scale = 0.766

var exit_portal: Portal setget _set_exit_portal
var _player: Player
onready var _viewport := $Viewport
onready var _camera := $Viewport/Camera
onready var _surface := $Surface
onready var _exit_point := $ExitPoint
onready var _bodies_in_portal := {}
onready var _body_doubles := {}


func _ready() -> void:
	if portal_path:
		self.exit_portal = get_node(portal_path)
	var plane_normal = global_transform.basis.z.normalized()
	var plane_dist = global_transform.origin.project(plane_normal).length()
	var portal_plane = Plane(plane_normal, plane_dist)
	var portal_shader: ShaderMaterial = _surface.get_surface_material(0)
	portal_shader.set_shader_param("portal_plane", -plane_normal)
	portal_shader.set_shader_param("portal_plane_dist", portal_plane.d)
	portal_shader.set_shader_param("scale", shader_scale)


func _get_exit_position(position: Vector3) -> Vector3:
	var entry_to_exit = exit_portal.transform * transform.affine_inverse()
	var exit_pos = entry_to_exit * position
	var exit_delta_pos = exit_portal.transform.origin - exit_pos
	exit_pos += exit_delta_pos + exit_delta_pos.bounce(exit_portal.transform.basis.y.normalized())
	return exit_pos


func _get_exit_quaternion(entry: Portal, exit: Portal, quat: Quat) -> Quat:
	var world_to_entry := Quat(entry.global_transform.basis.orthonormalized()).inverse()
	var exit_to_world := Quat(exit.global_transform.basis.orthonormalized())
	var entry_to_exit := world_to_entry * exit_to_world
	return entry_to_exit * quat


func teleport_rotation(local_rotation: Quat) -> Quat:
	return Quat(_exit_point.global_transform.basis) * local_rotation


func teleport_local_xform(xform: Transform) -> Transform:
	return _exit_point.global_transform * xform


func teleport_quat(quat: Quat) -> Quat:
	var to_global_quat := Quat(_exit_point.global_transform.basis.orthonormalized())
	return to_global_quat * quat


func teleport_origin(origin: Vector3) -> Vector3:
	return _exit_point.to_global(origin)


func teleport_global_quat(quat: Quat) -> Quat:
	var local_quat := (Quat(global_transform.basis).inverse() * quat).normalized()
	return self.exit_portal.teleport_quat(local_quat)


func teleport_global_origin(origin: Vector3) -> Vector3:
	var local_origin := to_local(origin)
	return self.exit_portal.teleport_origin(local_origin)


func teleport_global_xform(xform: Transform) -> Transform:
	var local_quat := (Quat(global_transform.basis).inverse() * Quat(xform.basis.orthonormalized())).normalized()
	var exit_quat := self.exit_portal.teleport_quat(local_quat)

	var local_origin := to_local(xform.origin)
	var exit_origin = self.exit_portal.teleport_origin(local_origin)

	return Transform(exit_quat, exit_origin)


func teleport_player(player: Player) -> void:
	var player_xform = _player.global_transform
	_player.global_transform = teleport_global_xform(player_xform)
	
#	var move_direction = _player.velocity.normalized()
#	move_direction = -teleport_global_origin(move_direction).normalized()
#	var exit_up = self.exit_portal.global_transform.basis.y
#	_player.velocity = move_direction * _player.velocity.length()
	var backward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var angle_sign := 1.0
	var player_dir := _player.velocity.normalized()
	if 0 < player_dir.dot(right):
		angle_sign = -1.0
	var velocity_angle = angle_sign * acos(player_dir.dot(backward))
	var exit_forward = self.exit_portal.global_transform.basis.z.normalized()
	var exit_up = self.exit_portal.global_transform.basis.y.normalized()
	_player.velocity = exit_forward.rotated(exit_up, velocity_angle) * _player.velocity.length()
	_detach_player()


func _will_player_cross_next_frame(player: Player, delta: float) -> bool:
	var main_cam := get_viewport().get_camera()
	var cam_pos := main_cam.global_transform.origin 
	var cam_forward := -main_cam.global_transform.basis.z
	# predict next cam position based on player velocity
	var cam_next_pos := cam_pos + player.velocity * delta
	
	# normal pointing to front of portal
	var forward := global_transform.basis.z.normalized()

	var portal_pos := global_transform.origin
	# compute normal pointing from portal to next cam position
	var cam_next_direction := (cam_next_pos - portal_pos).normalized()

	# check for angle greater than 90
	return 0 > cam_next_direction.dot(forward)


func _process(_delta) -> void:
	var main_cam := get_viewport().get_camera()
	var main_cam_origin = main_cam.global_transform.origin 

	var forward := global_transform.basis.z.normalized()
	var up := global_transform.basis.y.normalized()
	var portal_plane := Plane(forward, global_transform.origin.dot(forward))
	var cam_origin_on_portal := portal_plane.project(main_cam_origin)
	var cam_distance := cam_origin_on_portal.distance_to(main_cam_origin)

	_camera.global_transform = teleport_global_xform(main_cam.global_transform)
	
	_camera.near = max(cam_distance - 3.0, 0.01)


func _physics_process(delta) -> void:
	if _player:
		var cam = get_viewport().get_camera()
		var cam_pos = cam.global_transform.origin
		# predict next frame pos
		var cam_next_pos = cam_pos + _player.velocity * delta
		var cam_next_dir = (cam_next_pos - global_transform.origin).normalized()
		if _will_player_cross_next_frame(_player, delta):
			teleport_player(_player)
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
			var exit_pos = _get_exit_position(rbody.transform.origin)
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


func _attach_player(player: Player) -> void:
	_player = player
	_player.collision_layer ^= 1
	_player.collision_mask ^= 1 << 1
	_player.collision_mask ^= 1 << 2


func _on_body_entered(body):
	if body is Player:
		_attach_player(body)
	if body is RigidBody and not body.is_in_group("doubles"):
		_bodies_in_portal[body.get_rid()] = body
		var double: RigidBody = body.duplicate()
		double.add_to_group("doubles")
		_body_doubles[body.get_rid()] = double
		add_child(double)
		double.transform.origin = _get_exit_position(body.transform.origin)
#		var double_quat := _get_exit_quaternion(self, exit_portal, Quat(body.global_transform.basis))
#		double.global_transform.basis = Basis(double_quat)
		(body as PhysicsBody).collision_layer ^= 2
		(body as PhysicsBody).collision_mask ^= 1
		(body as PhysicsBody).collision_mask ^= 1 << 1
		(body as PhysicsBody).collision_mask ^= 1 << 2
	
	(body as PhysicsBody).collision_layer ^= 1 << 12


func _detach_player() -> void:
	if not _player:
		return
	_player.collision_layer ^= 1
	_player.collision_mask ^= 1 << 1
	_player.collision_mask ^= 1 << 2
	_player = null


func _on_body_exited(body):
	if body is Player:
		_detach_player()
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

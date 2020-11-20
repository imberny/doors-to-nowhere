class_name Portal
extends Area

export(NodePath) var portal_path
export(float) var shader_scale = 0.766

var exit_portal: Portal setget _set_exit_portal
onready var _viewport := $Viewport
onready var _camera := $Viewport/Camera
onready var _surface := $Surface
onready var _exit_point := $ExitPoint
onready var _body_info := {}

class BodyInfo:
	var double: PhysicsBody
	var collision_layer: int
	var collision_mask: int
	
	func _init(body_double: PhysicsBody, layer: int, mask: int) -> void:
		self.double = body_double
		self.collision_layer = layer
		self.collision_mask = mask


func _ready() -> void:
	if portal_path:
		self.exit_portal = get_node(portal_path)
	var plane_normal = global_transform.basis.z.normalized()
#	var plane_dist = global_transform.origin.project(plane_normal).length()
	var plane_dist = global_transform.origin.dot(plane_normal)
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
	var player_xform = player.global_transform
	player.global_transform = teleport_global_xform(player_xform)
	
	var player_dir := player.velocity.normalized()
	var right := global_transform.basis.x.normalized()
	# which way to rotate
	var angle_sign := 1.0
	if 0 < player_dir.dot(right):
		angle_sign = -1.0

	var backward := -global_transform.basis.z.normalized()
	var velocity_angle = angle_sign * acos(player_dir.dot(backward))

	var exit_forward = self.exit_portal.global_transform.basis.z.normalized()
	var exit_up = self.exit_portal.global_transform.basis.y.normalized()
	player.velocity = exit_forward.rotated(exit_up, velocity_angle) * player.velocity.length()


func receive_body(body: PhysicsBody, info: BodyInfo) -> void:
	if _body_info.has(body):
		return
	
	_body_info[body] = info


func _will_player_cross_next_frame(player: Player, delta: float) -> bool:
	var main_cam := get_viewport().get_camera()
	var cam_pos := main_cam.global_transform.origin 
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
	var portal_plane := Plane(forward, global_transform.origin.dot(forward))
	var cam_origin_on_portal := portal_plane.project(main_cam_origin)
	var cam_distance := cam_origin_on_portal.distance_to(main_cam_origin)

	_camera.global_transform = teleport_global_xform(main_cam.global_transform)
	
	_camera.near = max(cam_distance - 3.0, 0.01)


func _physics_process(delta) -> void:
	var bodies_to_remove := []
	for body in _body_info.keys():
		if body is Player:
			var info := _body_info[body] as BodyInfo
			var double := info.double as KinematicBody
			double.global_transform = teleport_global_xform(body.global_transform)

			if _will_player_cross_next_frame(body, delta):
				teleport_player(body)
				double.global_transform = self.exit_portal.teleport_global_xform(double.global_transform)
				bodies_to_remove.push_back(body)
		elif body is RigidBody:
			var rigid_body := body as RigidBody
			var info := _body_info[rigid_body] as BodyInfo
			var double := info.double as RigidBody
			double.global_transform = teleport_global_xform(rigid_body.global_transform)
#			if 0 < physics_body.linear_velocity.length():
#				var velocity_angle = acos(rbody.linear_velocity.normalized().dot(-global_transform.basis.z))
#				var exit_forward = exit_portal.global_transform.basis.z.normalized()
#				var exit_up = exit_portal.global_transform.basis.y.normalized()
#				double.linear_velocity = exit_forward.rotated(exit_up, velocity_angle) * rbody.linear_velocity.length()
#			elif 0 < double.linear_velocity.length():
#				var velocity_angle = acos(double.linear_velocity.normalized().dot(-exit_portal.global_transform.basis.z))
#				var entry_forward = global_transform.basis.z.normalized()
#				var entry_up = global_transform.basis.y.normalized()
#				rbody.linear_velocity = entry_forward.rotated(entry_up, velocity_angle) * double.linear_velocity.length()
			
			var body_next_pos = rigid_body.global_transform.origin + rigid_body.linear_velocity * delta
			var body_next_dir = (body_next_pos - global_transform.origin).normalized()
			if 0 > body_next_dir.dot(global_transform.basis.z):
				rigid_body.global_transform = teleport_global_xform(rigid_body.global_transform)
				var forward := -global_transform.basis.z.normalized()
				var move_dir := rigid_body.linear_velocity.normalized()
				var velocity_angle = acos(move_dir.dot(forward))
				var exit_forward = exit_portal.global_transform.basis.z.normalized()
				var exit_up = exit_portal.global_transform.basis.y.normalized()
				rigid_body.linear_velocity = exit_forward.rotated(exit_up, velocity_angle) * rigid_body.linear_velocity.length()
				bodies_to_remove.push_back(rigid_body)
	for body in bodies_to_remove:
		self.exit_portal.receive_body(body, _body_info[body])
		var _err = _body_info.erase(body)
#		_detach_body(body)


func _set_exit_portal(value: Portal) -> void:
	exit_portal = value


func _attach_body(physics_body: PhysicsBody) -> void:
	var real_collision_layer := physics_body.collision_layer
	var real_collision_mask := physics_body.collision_mask
	
	# replace collision layer with entity in portal
	physics_body.collision_layer = Utils.bit_mask_unset(
		physics_body.collision_layer,
		Utils.CollisionLayers.PLAYER |
		Utils.CollisionLayers.DYNAMIC
	)
	physics_body.collision_layer = Utils.bit_mask_set(
		physics_body.collision_layer,
		Utils.CollisionLayers.ENTITY_IN_PORTAL
	)

	# replace collision mask with an altered one while in portal
	physics_body.collision_mask = Utils.bit_mask_unset(
		physics_body.collision_mask,
		Utils.CollisionLayers.PLAYER |
		Utils.CollisionLayers.STATIC |
		Utils.CollisionLayers.DYNAMIC
	)
	physics_body.collision_mask = Utils.bit_mask_set(
		physics_body.collision_mask,
		Utils.CollisionLayers.PORTAL_STATIC |
		Utils.CollisionLayers.ENTITY_IN_PORTAL
	)

	var double: PhysicsBody
	if physics_body is Player:
		double = KinematicBody.new()
		var double_body: MeshInstance = physics_body.model.duplicate()
		var body_parts := Utils.children_to_list_recursive(double_body)
		for part in body_parts:
			part.layers = Utils.bit_mask_unset(
				part.layers,
				Utils.VisualLayers.MAIN_CAMERA |
				Utils.VisualLayers.PORTAL_CAMERA
			)
			part.layers = Utils.bit_mask_set(
				part.layers,
				Utils.VisualLayers.PORTAL_CULL
			)
		double.add_child(double_body)
	else:
		double = physics_body.duplicate()
	double.add_to_group("doubles")
	add_child(double)
	double.global_transform = teleport_global_xform(physics_body.global_transform)
	var info := BodyInfo.new(
		double,
		real_collision_layer,
		real_collision_mask
	)
	_body_info[physics_body] = info


func _detach_body(physics_body: PhysicsBody) -> void:
	if not _body_info.has(physics_body):
		return

	var info: BodyInfo = _body_info[physics_body]
	var double = info.double
	var _err = _body_info.erase(physics_body)
	double.queue_free()
	
	physics_body.collision_layer = info.collision_layer
	physics_body.collision_mask = info.collision_mask


func _on_body_entered(body):
	var physics_body := body as PhysicsBody
	if not physics_body or body.is_in_group("doubles"):
		return
	
	if _body_info.has(body):
		return
	
	_attach_body(physics_body)


func _on_body_exited(body):
	var physics_body := body as PhysicsBody
	if not physics_body or body.is_in_group("doubles"):
		return

	_detach_body(physics_body)

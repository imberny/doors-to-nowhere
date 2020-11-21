class_name Portal
extends Area

signal body_entered_back(body)
signal body_exited_back(body)


export(NodePath) var portal_path

var exit_portal: Portal setget _set_exit_portal
onready var _viewport := $Viewport
onready var _camera := $Viewport/Camera
onready var _surface := $Surface
onready var _exit_point := $ExitPoint
onready var _zone_behind := $BackArea/CollisionShape
onready var _body_info := {}

var _cull_layer: int

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
#	_cull_layer = Globals.get_portal_cull()
	_camera.cull_mask = Util.bit_mask_unset(
		_camera.cull_mask,
		Util.VisualLayers.PORTAL_CULL
	)
	_surface.layers = Util.bit_mask_unset(
		_surface.layers,
		Util.VisualLayers.MAIN_CAMERA
	)
	_surface.layers = Util.bit_mask_set(
		_surface.layers,
		Util.VisualLayers.PORTAL_CULL
	)

	_camera.fov = get_viewport().get_camera().fov


func teleport_quat(quat: Quat) -> Quat:
	var to_global_quat := Quat(_exit_point.global_transform.basis.orthonormalized())
	return to_global_quat * quat


func teleport_origin(origin: Vector3) -> Vector3:
	return _exit_point.to_global(origin)


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
	_clear_collision_exceptions(body)
	set_collision_exceptions(body)


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

#	#REMOVE THIS
#	for body in _body_info.keys():
#		if body is Player:
#			if (main_cam_origin - global_transform.origin).normalized().dot(forward) < 0:
#				print("Hmmm.")
#				print("cam origin: " + str(main_cam_origin))
#				print("portal origin: " + str(global_transform.origin))
#				return


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
	var _err
	if exit_portal:
		_err = exit_portal.disconnect("body_entered_back", self, "_on_Exit_body_entered_back")
		_err = exit_portal.disconnect("body_exited_back", self, "_on_Exit_body_exited_back")

	exit_portal = value

	_err = exit_portal.connect("body_entered_back", self, "_on_Exit_body_entered_back")
	_err = exit_portal.connect("body_exited_back", self, "_on_Exit_body_exited_back")


func _intersect_behind() -> Array:
	var space_state := get_world().direct_space_state
	var query_shape := PhysicsShapeQueryParameters.new()
	query_shape.set_shape(_zone_behind.shape)
	query_shape.transform = _zone_behind.global_transform
	return space_state.intersect_shape(query_shape)


func _clear_collision_exceptions(physics_body : PhysicsBody) -> void:
	for exception in physics_body.get_collision_exceptions():
		physics_body.remove_collision_exception_with(exception)


func set_collision_exceptions(physics_body: PhysicsBody) -> void:
	var space_state := get_world().direct_space_state
	var query_shape := PhysicsShapeQueryParameters.new()
	query_shape.set_shape(_zone_behind.shape)
	query_shape.transform = _zone_behind.global_transform
	var query_results := space_state.intersect_shape(query_shape)
	for intersection in query_results:
		var collider = intersection.collider
		if physics_body == collider:
			continue # skip self
		if _body_info.has(collider):
			continue # skip objects in this portal
		physics_body.add_collision_exception_with(collider)


func _attach_body(physics_body: PhysicsBody) -> void:
	var real_collision_layer := physics_body.collision_layer
	var real_collision_mask := physics_body.collision_mask

	_clear_collision_exceptions(physics_body)
	set_collision_exceptions(physics_body)

	var double: PhysicsBody
	if physics_body is Player:
		double = KinematicBody.new()
		
		double.add_child(physics_body.get_node("BodyShape").duplicate())

		var double_body: MeshInstance = physics_body.model.duplicate()
		var body_parts := Util.children_to_list(double_body)
		body_parts.push_front(double_body)
		for part in body_parts:
			part.layers = Util.bit_mask_unset(
				part.layers,
				Util.VisualLayers.MAIN_CAMERA |
				Util.VisualLayers.PORTAL_CAMERA
			)
			part.layers = Util.bit_mask_set(
				part.layers,
				Util.VisualLayers.PORTAL_CULL
			)
		double.add_child(double_body)
	else:
		double = physics_body.duplicate()
	double.add_to_group("doubles")
	self.exit_portal.set_collision_exceptions(double)
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

	_clear_collision_exceptions(physics_body)

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



func _on_Exit_body_entered_back(body: PhysicsBody) -> void:
	for child in Util.children_to_list(body):
		if not child is VisualInstance:
			continue
		var visual := child as VisualInstance
		visual.layers = Util.bit_mask_unset(
			visual.layers,
			Util.VisualLayers.MAIN_CAMERA
		)
		visual.layers = Util.bit_mask_set(
			visual.layers,
			Util.VisualLayers.PORTAL_CULL
		)


func _on_Exit_body_exited_back(body: PhysicsBody) -> void:
	for child in Util.children_to_list(body):
		if not child is VisualInstance:
			continue
		var visual := child as VisualInstance
		visual.layers = Util.bit_mask_unset(
			visual.layers,
			Util.VisualLayers.PORTAL_CULL
		)
		visual.layers = Util.bit_mask_set(
			visual.layers,
			Util.VisualLayers.MAIN_CAMERA
		)


func _on_BackArea_body_entered(body: PhysicsBody) -> void:
	emit_signal("body_entered_back", body)


func _on_BackArea_body_exited(body: PhysicsBody) -> void:
	emit_signal("body_exited_back", body)

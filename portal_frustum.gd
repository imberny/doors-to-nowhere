class_name PortalFrustum
extends Area

export(Array, NodePath) var exit_portal_paths
export(int) var pixels_per_unit := 800

var exit_portal: PortalFrustum setget _set_exit_portal

onready var _viewport := $Viewport
onready var _camera := $Viewport/Camera
onready var _surface := $Surface
onready var _exit_point := $ExitPoint


func _ready() -> void:
	if 0 < exit_portal_paths.size():
		self.exit_portal = get_node(exit_portal_paths[0])
#	_viewport.size = get_viewport().size
#	var aspect_ratio := get_viewport().size.y / get_viewport().size.x
	var aspect_ratio: float = _surface.mesh.size.y / _surface.mesh.size.x
	
	_viewport.size.x = get_viewport().size.x
	_viewport.size.y = get_viewport().size.x * aspect_ratio
	
#	_viewport.size = _surface.mesh.size * pixels_per_unit
#	_surface.get_surface_material(0).albedo_texture = _viewport.get_texture()


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
	var local_rotation := Quat(global_transform.basis).normalized().inverse() * Quat(xform.basis)
	var local_origin := to_local(xform.origin)
	var exit_rotation = self.exit_portal.teleport_rotation(local_rotation)
	var exit_origin = self.exit_portal.teleport_origin(local_origin)
#	return Transform(exit_rotation, exit_origin)
	
	var local_quat := (Quat(global_transform.basis).inverse() * Quat(xform.basis.orthonormalized())).normalized()
	var exit_quat := self.exit_portal.teleport_quat(local_quat)
	return Transform(exit_quat, exit_origin)
	
#	xform.origin = exit_origin
#	return xform
#	var local_xform := global_transform.affine_inverse() * xform
#	return self.exit_portal.teleport_local_xform(local_xform)
#	return teleport_local_xform(local_xform)



# Compute the tilting offset for the frustum (the X and Y coordinates of the mirrored camera position
#	when expressed in the reflection plane coordinate system) 
func frustum_offset(origin: Vector3) -> Vector2:
	var offset = _exit_point.to_local(origin)
	return Vector2(offset.x, offset.y)


func _process(_delta: float) -> void:
	var main_cam := get_viewport().get_camera()
	var main_cam_origin = main_cam.global_transform.origin 

	var forward := global_transform.basis.z.normalized()
	var up := global_transform.basis.y.normalized()
	var portal_plane := Plane(forward, global_transform.origin.dot(forward))
	var cam_origin_on_portal := portal_plane.project(main_cam_origin)
	var cam_distance := cam_origin_on_portal.distance_to(main_cam_origin)

	var view_xform := Transform(Basis(), main_cam_origin)
	view_xform = view_xform.looking_at(cam_origin_on_portal, up)
	_camera.global_transform = teleport_global_xform(view_xform)

	var frustum_offset := self.exit_portal.frustum_offset(_camera.global_transform.origin)

	# Set mirror camera frustum
	# - size 	-> mirror's width (camera is set to KEEP_WIDTH)
	# - offset 	-> previously computed tilting offset
	# - z_near 	-> distance between the mirror camera and the reflection plane (this ensures we won't
	#               be reflecting anything behind the mirror)
	# - z_far	-> large arbitrary value (render distance limit form th mirror camera position)
	var z_far := main_cam.far
	var x_size: float = _surface.mesh.size.x
	_camera.set_frustum(x_size, -frustum_offset, cam_distance, z_far)



func _set_exit_portal(value: PortalFrustum) -> void:
	exit_portal = value

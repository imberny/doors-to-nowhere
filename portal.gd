class_name Portal
extends Area


var exit_portal: Portal setget _set_exit_portal
var my_cam: Camera

func _ready() -> void:
	my_cam = $Camera
	remove_child(my_cam)
	$Viewport.add_child(my_cam)


func _process(_delta) -> void:
	var cam := get_viewport().get_camera()
	
	var cam_global_origin = cam.global_transform.origin
	
	var dolly = Transform.IDENTITY
	var rot_transform = Transform(Quat(exit_portal.rotation) * Quat(rotation).inverse() * Quat(cam.global_transform.basis.get_euler()))
	dolly.basis.y *= -1.0
	dolly *= rot_transform
	dolly.basis.y *= -1.0
	dolly.origin = exit_portal.global_transform.xform(global_transform.xform_inv(cam_global_origin))
	var dolly_to_exit = exit_portal.global_transform.origin - dolly.origin
	dolly.origin += dolly_to_exit + dolly_to_exit.bounce(exit_portal.global_transform.basis.y)
	$Dolly.global_transform = dolly
	$Dolly.rotate(dolly.basis.y, PI)
	
#	$Dolly.transform = Transform.IDENTITY
#	$Dolly.transform.basis.y *= -1.0
#	$Dolly.global_transform.origin = exit_portal.global_transform.xform(global_transform.xform_inv(cam_global_origin))
#	$Dolly.rotation = Quat(exit_portal.rotation) * Quat(rotation).inverse() * cam.global_transform.basis.get_euler()
##	$Dolly.rotate(transform.basis.y.normalized(), PI)
#	$Dolly.transform.basis.y *= -1.0
#	$Dolly.global_transform.origin += 2.0 * (exit_portal.global_transform.origin - $Dolly.global_transform.origin)
#
	# place my cam on dolly
	my_cam.global_transform = dolly
	my_cam.rotate(my_cam.global_transform.basis.y, PI)
	my_cam.near = dolly_to_exit.length()
	$Quad.get_surface_material(0).set_shader_param("distance_factor", dolly_to_exit.length())


func _set_exit_portal(value: Portal) -> void:
	exit_portal = value

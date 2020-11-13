# Code for movement with bunnyhop adapted from: https://adrianb.io/2015/02/14/bunnyhop.html
class_name BunnyHopMovement
extends Object


static func move(
	input_dir: Vector3,
	prev_velocity: Vector3,
	ground_friction: float,
	sprint_modifier: float,
	is_grounded: bool,
	delta: float
) -> Vector3:
	var new_velocity: Vector3
	
	if is_grounded:
		# Apply friction
		var speed := prev_velocity.length()
		if 0 != speed: # To avoid divide by zero errors
			var drop := speed * ground_friction * delta
			# Scale the velocity based on ground_friction.
			prev_velocity *= max(speed - drop, 0) / speed;
		new_velocity = _accelerate(
			input_dir,
			prev_velocity,
			Globals.player.ground_acceleration * sprint_modifier,
			Globals.player.ground_max_velocity * sprint_modifier,
			delta
		)
	else:
		new_velocity = _accelerate(
			input_dir,
			prev_velocity,
			Globals.player.air_acceleration,
			Globals.player.air_max_velocity,
			delta
		)
	
	return new_velocity


# accel_dir: normalized direction that the player has requested to move (taking into account the movement keys and look direction)
# prev_velocity: The current velocity of the player, before any additional calculations
# acceleration: The player acceleration value
# max_velocity: The maximum player velocity (this is not strictly adhered to due to strafejumping)
static func _accelerate(
	accel_dir: Vector3,
	prev_velocity: Vector3,
	acceleration: float,
	max_velocity: float,
	delta: float
) -> Vector3:
	var proj_vel := prev_velocity.dot(accel_dir) # Vector projection of Current velocity onto accelDir.
	var accel_vel = acceleration * delta # Accelerated velocity in direction of movement

	# If necessary, truncate the accelerated velocity so the vector projection does not exceed max_velocity
	# Actually, scratch that. Let's diminish it proportionnaly instead of capping it.
	if max_velocity < proj_vel + accel_vel:
#		accel_vel = max_velocity - proj_vel
		accel_vel *= max_velocity / (proj_vel + accel_vel)

	return prev_velocity + accel_dir * accel_vel

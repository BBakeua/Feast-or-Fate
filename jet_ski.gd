extends CharacterBody3D

@export var strafe_speed  : float = 8.0
@export var bob_amount    : float = 0.15
@export var bob_speed     : float = 2.0
@export var lean_amount   : float = 0.3
@export var lane_width    : float = 6.0   # max units left/right from origin

var _time  : float = 0.0
var _lean  : float = 0.0
var water_y: float = 0.0

func _physics_process(delta: float) -> void:
	_time += delta

	# --- Lateral input only ---
	var steer := Input.get_axis( "steer_right", "steer_left")
	velocity.x = steer * strafe_speed
	velocity.y = (water_y + sin(_time * bob_speed) * bob_amount - global_position.y) * 10.0
	velocity.z = 0.0  # boat stays still on Z; world scrolls instead

	move_and_slide()

	# --- Clamp X position ---
	global_position.x = clampf(global_position.x, -lane_width, lane_width)

	# --- Visual lean ---
	_lean = lerpf(_lean, steer * lean_amount, delta * 6.0)
	rotation.z = -_lean

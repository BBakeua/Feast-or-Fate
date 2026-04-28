extends CharacterBody3D
@export var move_speed   : float = 12.0
@export var strafe_speed : float = 8.0
@export var bob_amount   : float = 0.15
@export var bob_speed    : float = 2.0
@export var lean_amount  : float = 0.3

var _time : float = 0.0
var _lean : float = 0.0
var water_y : float = 0.0

func _physics_process(delta: float) -> void:
	_time += delta

	# --- Lateral input (left/right only) ---
	var steer := Input.get_axis("steer_right", "steer_left")

	# --- Always move forward on Z, strafe on X ---
	velocity.x = steer * strafe_speed
	velocity.z = -move_speed

	# --- Water bobbing ---
	var target_y := water_y + sin(_time * bob_speed) * bob_amount
	velocity.y = (target_y - global_position.y) * 10.0

	move_and_slide()

	# --- Visual lean into turns (rotation on Z only, no rotate_y) ---
	_lean = lerpf(_lean, steer * lean_amount, delta * 6.0)
	rotation.z = -_lean

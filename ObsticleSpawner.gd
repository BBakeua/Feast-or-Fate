extends Node3D

# --- Inspector Settings ---
@export var obstacle_scene: PackedScene          # Drag your obstacle scene here
@export var spawn_distance: float = 40.0         # How far ahead obstacles spawn
@export var spawn_interval: float = 2.0          # Seconds between spawns
@export var obstacle_speed: float = 15.0         # Speed moving toward Jetski
@export var lateral_spread: float = 4.0          # Random left/right offset
@export var max_obstacles: int = 10              # Pool cap

@onready var jetski: Node3D = get_node("/root/Game/Jetski")  # Adjust path to match your scene

var _obstacles: Array[Node3D] = []
var _obstacle_velocities: Dictionary = {}
var _timer: float = 0.0

func _ready() -> void:
	if not jetski:
		push_error("ObstacleSpawner: Could not find Jetski node. Check the path.")

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_obstacle()

	_move_obstacles(delta)
	_cleanup_passed_obstacles()

func _spawn_obstacle() -> void:
	if not obstacle_scene or not jetski:
		return
	if _obstacles.size() >= max_obstacles:
		# Remove oldest obstacle to make room
		var oldest = _obstacles.pop_front()
		if is_instance_valid(oldest):
			_obstacle_velocities.erase(oldest)
			oldest.queue_free()

	var obstacle: Node3D = obstacle_scene.instantiate()
	get_tree().current_scene.add_child(obstacle)

	# Spawn ahead of the Jetski along its forward axis
	var forward: Vector3 = -jetski.global_transform.basis.z
	var right: Vector3 = jetski.global_transform.basis.x
	var offset: float = randf_range(-lateral_spread, lateral_spread)

	obstacle.global_position = jetski.global_position + forward * spawn_distance + right * offset

	# Lock movement direction at spawn time (toward Jetski, regardless of later rotation)
	var move_dir: Vector3 = -forward * obstacle_speed
	_obstacle_velocities[obstacle] = move_dir

	_connect_collision(obstacle)
	_obstacles.append(obstacle)

func _move_obstacles(delta: float) -> void:
	for obs in _obstacles:
		if is_instance_valid(obs) and _obstacle_velocities.has(obs):
			obs.global_position += _obstacle_velocities[obs] * delta

func _cleanup_passed_obstacles() -> void:
	# Remove obstacles that have passed behind the Jetski
	var to_remove: Array = []
	for obs in _obstacles:
		if not is_instance_valid(obs):
			to_remove.append(obs)
			continue
		if jetski and obs.global_position.z > jetski.global_position.z + 10.0:
			to_remove.append(obs)
			obs.queue_free()

	for obs in to_remove:
		_obstacles.erase(obs)
		_obstacle_velocities.erase(obs)

func _connect_collision(obstacle: Node3D) -> void:
	# Recursively find any Area3D in the obstacle and connect its signal
	_connect_area_signals(obstacle)

func _connect_area_signals(node: Node) -> void:
	if node is Area3D:
		var area := node as Area3D
		if not area.body_entered.is_connected(_on_obstacle_hit):
			area.body_entered.connect(_on_obstacle_hit)
	for child in node.get_children():
		_connect_area_signals(child)

func _on_obstacle_hit(body: Node3D) -> void:
	if body.is_in_group("jetski"):
		get_tree().reload_current_scene()

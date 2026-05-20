extends Node3D

@export var obstacle_scenes: Array[PackedScene] = []
@export var spawn_distance: float = 40.0
@export var despawn_distance: float = 10.0
@export var spawn_interval: float = 1.2
@export var scroll_speed: float = 8.0
@export var max_scroll_speed: float = 24.0
@export var speed_ramp: float = 0.5
@export var lane_spread_x: float = 3.0
@export var lane_spread_y: float = 0.0
@export var player: Node3D = null
@export var jetski_group: String = "jetski"
@export var restart_delay: float = 0.4

var _active_obstacles: Array[Node3D] = []
var _spawn_timer: float = 0.0
var _hit: bool = false

func _ready() -> void:
	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner: no obstacle_scenes assigned!")

func _process(delta: float) -> void:
	scroll_speed = minf(scroll_speed + speed_ramp * delta, max_scroll_speed)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_try_spawn()
	_scroll_obstacles(delta)

# Runs every physics tick to check Area3D overlaps on each obstacle.
func _physics_process(_delta: float) -> void:
	if _hit:
		return
	for obs in _active_obstacles:
		if is_instance_valid(obs):
			_check_collision(obs)

func _check_collision(obs: Node3D) -> void:
	# Walk the obstacle's children looking for any Area3D nodes.
	for child in obs.get_children():
		if child is Area3D:
			for body in (child as Area3D).get_overlapping_bodies():
				if _is_jetski(body):
					_on_jetski_hit()
					return

func _is_jetski(node: Node) -> bool:
	if not jetski_group.is_empty():
		return node.is_in_group(jetski_group)
	# Fallback: any CharacterBody3D counts as the player.
	return node is CharacterBody3D

func _try_spawn() -> void:
	if obstacle_scenes.is_empty():
		return

	var scene: PackedScene = obstacle_scenes.pick_random()
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		push_error("ObstacleSpawner: scene did not instantiate as Node3D.")
		return

	get_tree().current_scene.add_child(instance)

	var origin: Vector3 = _player_position()
	instance.global_position = Vector3(
		origin.x + randf_range(-lane_spread_x, lane_spread_x),
		origin.y + randf_range(-lane_spread_y, lane_spread_y),
		origin.z - spawn_distance
	)

	_active_obstacles.append(instance)

	if instance.has_signal("jetski_hit") and not instance.jetski_hit.is_connected(_on_jetski_hit):
		instance.jetski_hit.connect(_on_jetski_hit)

func _scroll_obstacles(delta: float) -> void:
	var origin_z: float = _player_position().z
	var to_remove: Array[Node3D] = []

	for obs in _active_obstacles:
		if not is_instance_valid(obs):
			to_remove.append(obs)
			continue

		obs.global_position.z += scroll_speed * delta

		if obs.global_position.z > origin_z + despawn_distance:
			obs.queue_free()
			to_remove.append(obs)
			continue

		# Proximity fallback — also resolves the player node on the fly via
		# the jetski group if no direct reference was assigned.
		if not _hit:
			var target: Node3D = _resolve_player()
			if target != null and obs.global_position.distance_to(target.global_position) < 1.5:
				_on_jetski_hit()

	for obs in to_remove:
		_active_obstacles.erase(obs)

func _resolve_player() -> Node3D:
	if player != null and is_instance_valid(player):
		return player
	# Try to find the jetski by group as a fallback.
	if not jetski_group.is_empty():
		var members := get_tree().get_nodes_in_group(jetski_group)
		if not members.is_empty() and members[0] is Node3D:
			return members[0] as Node3D
	return null

func _player_position() -> Vector3:
	var target := _resolve_player()
	if target != null:
		return target.global_position
	return global_position

func clear_all() -> void:
	for obs in _active_obstacles:
		if is_instance_valid(obs):
			obs.queue_free()
	_active_obstacles.clear()

func set_spawning(enabled: bool) -> void:
	set_process(enabled)
	set_physics_process(enabled)

func _on_jetski_hit(_unused = null) -> void:
	if _hit:
		return
	_hit = true
	set_spawning(false)

	var target := _resolve_player()
	if target != null:
		_kill_jetski(target)
	else:
		get_tree().create_timer(restart_delay).timeout.connect(_restart_scene)

func _kill_jetski(jetski: Node3D) -> void:
	if jetski is CharacterBody3D:
		(jetski as CharacterBody3D).velocity = Vector3.ZERO
		jetski.set_physics_process(false)
		jetski.set_process(false)

	jetski.visible = false
	get_tree().create_timer(restart_delay).timeout.connect(_restart_scene)

func _restart_scene() -> void:
	get_tree().reload_current_scene()

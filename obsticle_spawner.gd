extends Node3D
## ObstacleSpawner.gd
## Attach to a Node3D in your scene. Randomly spawns obstacles ahead of the
## player and scrolls them toward/past the player on the Z axis.
##
## SETUP:
##   1. Create one or more MeshInstance3D obstacle scenes (or PackedScenes).
##      Add a CollisionShape3D sibling inside a StaticBody3D (or RigidBody3D).
##   2. Assign those PackedScenes to `obstacle_scenes` in the Inspector.
##   3. Set `player` to your player Node3D (or leave null to use the spawner's
##      own position as the reference point).
##   4. Tweak the exported variables to suit your game's feel.

# ── Exported tunables ────────────────────────────────────────────────────────

## PackedScenes to choose from when spawning. Add as many variants as you like.
@export var obstacle_scenes: Array[PackedScene] = []

## How many units ahead of the player (on the -Z axis) obstacles first appear.
@export var spawn_distance: float = 40.0

## Obstacles are destroyed once they pass this many units behind the player.
@export var despawn_distance: float = 10.0

## Seconds between each spawn attempt.
@export var spawn_interval: float = 1.2

## How fast obstacles travel toward the player (units per second).
## Increase over time with `scroll_speed` to ramp up difficulty.
@export var scroll_speed: float = 8.0

## Maximum speed the scroller will accelerate to.
@export var max_scroll_speed: float = 24.0

## How many units per second the scroll speed increases.
@export var speed_ramp: float = 0.5

## Half-width of the random lane spread on the X axis.
@export var lane_spread_x: float = 3.0

## Half-width of the random lane spread on the Y axis (set 0 for flat ground).
@export var lane_spread_y: float = 0.0

## Optional reference to the player node. Obstacles spawn relative to it.
## Leave empty to use the spawner's own position as the origin.
@export var player: Node3D = null

# ── Internal state ───────────────────────────────────────────────────────────

var _active_obstacles: Array[Node3D] = []
var _spawn_timer: float = 0.0

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner: no obstacle_scenes assigned!")


func _process(delta: float) -> void:
	# Ramp up speed over time.
	scroll_speed = minf(scroll_speed + speed_ramp * delta, max_scroll_speed)

	# Spawn timer.
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_try_spawn()

	# Move & cull existing obstacles.
	_scroll_obstacles(delta)


# ── Spawning ─────────────────────────────────────────────────────────────────

func _try_spawn() -> void:
	if obstacle_scenes.is_empty():
		return

	var scene: PackedScene = obstacle_scenes.pick_random()
	var instance: Node3D = scene.instantiate() as Node3D
	if instance == null:
		push_error("ObstacleSpawner: scene did not instantiate as Node3D.")
		return

	get_tree().current_scene.add_child(instance)

	# Position the new obstacle ahead of the player.
	var origin: Vector3 = _player_position()
	instance.global_position = Vector3(
		origin.x + randf_range(-lane_spread_x, lane_spread_x),
		origin.y + randf_range(-lane_spread_y, lane_spread_y),
		origin.z - spawn_distance          # negative Z = "in front" (Godot default)
	)

	_active_obstacles.append(instance)


# ── Scrolling & culling ───────────────────────────────────────────────────────

func _scroll_obstacles(delta: float) -> void:
	var origin_z: float = _player_position().z
	var to_remove: Array[Node3D] = []

	for obs in _active_obstacles:
		if not is_instance_valid(obs):
			to_remove.append(obs)
			continue

		# Move the obstacle toward the player (+Z direction).
		obs.global_position.z += scroll_speed * delta

		# Despawn once it has passed the player by despawn_distance.
		if obs.global_position.z > origin_z + despawn_distance:
			obs.queue_free()
			to_remove.append(obs)

	for obs in to_remove:
		_active_obstacles.erase(obs)


# ── Helper ────────────────────────────────────────────────────────────────────

func _player_position() -> Vector3:
	if player != null and is_instance_valid(player):
		return player.global_position
	return global_position


# ── Public API ────────────────────────────────────────────────────────────────

## Call this to instantly remove all active obstacles (e.g. on game over).
func clear_all() -> void:
	for obs in _active_obstacles:
		if is_instance_valid(obs):
			obs.queue_free()
	_active_obstacles.clear()


## Pause / resume spawning without removing the node.
func set_spawning(enabled: bool) -> void:
	set_process(enabled)

extends Node3D
## ObstacleSpawner.gd
## Attach to a Node3D in your scene.
## Randomly spawns obstacles ahead of the player and scrolls them toward/past it.
##
## SETUP:
##   1. Create one or more obstacle scenes (e.g. a CSGBox3D or MeshInstance3D +
##      CollisionShape3D inside a StaticBody3D). Save each as a .tscn file.
##   2. Add those .tscn paths to `obstacle_scenes` in the Inspector.
##   3. Set `player` to your player node in the Inspector (or leave null to use
##      the node's own position as the reference point).
##   4. Optionally add an Area3D named "DeathZone" on your player to detect hits.

# ── Inspector-exposed settings ────────────────────────────────────────────────

## Packed scenes to use as obstacles. Add at least one!
@export var obstacle_scenes: Array[PackedScene] = []

## How far ahead of the player obstacles spawn (Z units, positive = in front).
@export var spawn_distance: float = 40.0

## How far behind the player a passed obstacle is freed.
@export var despawn_distance: float = 10.0

## Horizontal range obstacles can spawn within (±x_spread around player X).
@export var x_spread: float = 3.0

## Fixed Y position obstacles spawn at (ground level).
@export var spawn_y: float = 0.0

## Seconds between spawns (randomised between min and max).
@export var spawn_interval_min: float = 1.2
@export var spawn_interval_max: float = 2.8

## How fast obstacles scroll toward the player (units/second).
## Increase over time for difficulty scaling.
@export var scroll_speed: float = 10.0

## Speed increase per second (0 = constant difficulty).
@export var speed_ramp: float = 0.5

## Maximum scroll speed cap.
@export var max_scroll_speed: float = 35.0

## Reference to the player node. If null, world origin is used as reference.
@export var player: Node3D = null

# ── Internal state ────────────────────────────────────────────────────────────

var _active_obstacles: Array[Node3D] = []
var _spawn_timer: float = 0.0
var _next_spawn_time: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)
	if obstacle_scenes.is_empty():
		push_warning("ObstacleSpawner: No obstacle scenes assigned! Add at least one PackedScene.")


func _process(delta: float) -> void:
	# --- Speed ramp ---
	scroll_speed = minf(scroll_speed + speed_ramp * delta, max_scroll_speed)

	# --- Scroll all active obstacles ---
	var player_pos := _get_player_pos()
	var to_remove: Array[Node3D] = []

	for obs in _active_obstacles:
		if not is_instance_valid(obs):
			to_remove.append(obs)
			continue

		# Move obstacle toward the player (negative Z = forward in Godot 3D).
		obs.global_position.z += scroll_speed * delta

		# Despawn once it has passed far enough behind the player.
		if obs.global_position.z > player_pos.z + despawn_distance:
			obs.queue_free()
			to_remove.append(obs)

	for obs in to_remove:
		_active_obstacles.erase(obs)

	# --- Spawn timer ---
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn_time:
		_spawn_timer = 0.0
		_next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)
		_spawn_obstacle()


# ── Spawning ──────────────────────────────────────────────────────────────────

func _spawn_obstacle() -> void:
	if obstacle_scenes.is_empty():
		return

	# Pick a random scene.
	var scene: PackedScene = obstacle_scenes[randi() % obstacle_scenes.size()]
	var obs: Node3D = scene.instantiate() as Node3D
	if obs == null:
		push_error("ObstacleSpawner: Instantiated scene is not a Node3D.")
		return

	# Position: ahead of the player, random X offset.
	var player_pos := _get_player_pos()
	var spawn_pos := Vector3(
		player_pos.x + randf_range(-x_spread, x_spread),
		spawn_y,
		player_pos.z - spawn_distance   # negative Z = in front
	)
	obs.global_position = spawn_pos

	# Add to the scene tree (as child of this spawner).
	add_child(obs)
	_active_obstacles.append(obs)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _get_player_pos() -> Vector3:
	if player != null and is_instance_valid(player):
		return player.global_position
	return global_position


## Call this to reset the spawner (e.g. on game restart).
func reset() -> void:
	for obs in _active_obstacles:
		if is_instance_valid(obs):
			obs.queue_free()
	_active_obstacles.clear()
	_spawn_timer = 0.0
	_next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)
	scroll_speed = 10.0   # reset to base speed

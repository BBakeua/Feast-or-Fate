extends Node3D

# --- Scroll ---
@export var scroll_speed       : float = 12.0

# --- Spawn timing ---
@export var spawn_interval     : float = 2.0   # seconds between spawn waves
@export var spawn_distance     : float = 60.0  # how far ahead to spawn
@export var despawn_distance   : float = 20.0  # how far behind player to despawn

# --- Lane ---
@export var side_offset_min    : float = 8.0   # closest to centre scenery spawns
@export var side_offset_max    : float = 18.0  # furthest from centre

# --- Models (assign in Inspector) ---
@export var scenery_scenes     : Array[PackedScene] = []  # mountains, rocks, trees…

# --- Internal ---
var _timer        : float = 0.0
var _active       : Array[Node3D] = []
var _player       : Node3D          # auto-found, or assign manually

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if scenery_scenes.is_empty():
		return

	# Scroll all active scenery toward the player
	for node in _active:
		node.global_position.z += scroll_speed * delta

	# Despawn anything that has passed the player
	var player_z := _player.global_position.z if _player else 0.0
	_active = _active.filter(func(n):
		if n.global_position.z > player_z + despawn_distance:
			n.queue_free()
			return false
		return true
	)

	# Spawn new wave on a timer
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_spawn_wave(player_z)

func _spawn_wave(player_z: float) -> void:
	# Spawn one on each side per wave
	for side in [-1, 1]:
		var scene : PackedScene = scenery_scenes.pick_random()
		var instance : Node3D = scene.instantiate()
		add_child(instance)

		var offset_x = randf_range(side_offset_min, side_offset_max) * side
		var spawn_z   := player_z - spawn_distance   # ahead = negative Z
		instance.global_position = Vector3(offset_x, 0.0, spawn_z)

		# Random Y rotation so they don't all face the same way
		instance.rotation.y = randf_range(-PI, PI)

		_active.append(instance)

extends Node3D
# ─────────────────────────────────────────
#  Fruit Spawner – attach to your Jetski Node3D
# ─────────────────────────────────────────
## How far ahead of the Jetski fruit will spawn (metres)
@export var spawn_distance: float = 15.0
## Half-width of the random spread (left/right of forward direction)
@export var spawn_spread: float = 6.0
## Min / max height offset from the Jetski's position
@export var spawn_height_min: float = 0.0
@export var spawn_height_max: float = 0.5
## Seconds between spawns
@export var spawn_interval: float = 2.0
## How many fruit can exist at once (older ones are removed)
@export var max_fruit: int = 10
## Speed at which fruit moves toward the Jetski (metres/sec)
@export var fruit_speed: float = 5.0
## Drag your Fruit scene (.tscn) into this slot in the Inspector
@export var fruit_scene: PackedScene

# ── internals ──────────────────────────────
var _fruit_pool: Array[Node3D] = []
var _fruit_velocities: Dictionary = {}   # fruit -> Vector3 move direction
var _score: int = 0
@onready var _spawn_timer := $SpawnTimer

func _ready() -> void:
	if not has_node("SpawnTimer"):
		var t := Timer.new()
		t.name = "SpawnTimer"
		t.wait_time = spawn_interval
		t.autostart = true
		add_child(t)
		t.timeout.connect(_spawn_fruit)
		_spawn_timer = t
	else:
		_spawn_timer.wait_time = spawn_interval
		_spawn_timer.timeout.connect(_spawn_fruit)
		_spawn_timer.start()

	if fruit_scene == null:
		push_warning("FruitSpawner: 'fruit_scene' is not set – assign a Fruit .tscn in the Inspector.")

func _process(delta: float) -> void:
	# Move each fruit along its stored direction every frame
	for fruit in _fruit_velocities.keys():
		if is_instance_valid(fruit):
			fruit.global_position += _fruit_velocities[fruit] * delta
		else:
			_fruit_velocities.erase(fruit)

func _spawn_fruit() -> void:
	if fruit_scene == null:
		return

	# ── Remove oldest fruit if pool is full ──
	while _fruit_pool.size() >= max_fruit:
		var oldest: Node3D = _fruit_pool.pop_front()
		if is_instance_valid(oldest):
			_fruit_velocities.erase(oldest)
			oldest.queue_free()

	# ── Calculate spawn position ──
	# Forward = -Z; fruit spawns ahead and travels back toward the Jetski (+Z)
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var right: Vector3   =  global_transform.basis.x.normalized()
	var offset := (
		forward * spawn_distance
		+ right  * randf_range(-spawn_spread, spawn_spread)
		+ Vector3.UP * randf_range(spawn_height_min, spawn_height_max)
	)
	var spawn_pos: Vector3 = global_position + offset

	# ── Instance the fruit ──
	var fruit: Node3D = fruit_scene.instantiate()
	get_tree().current_scene.add_child(fruit)
	fruit.global_position = spawn_pos

	# Fruit travels in the opposite direction of forward (i.e. back along Z toward the Jetski)
	_fruit_velocities[fruit] = -forward * fruit_speed

	# Connect the "collected" signal
	if fruit.has_signal("collected"):
		fruit.collected.connect(_on_fruit_collected.bind(fruit))

	_fruit_pool.append(fruit)

func _on_fruit_collected(fruit: Node3D) -> void:
	_score += 1
	print("Fruit collected! Score: %d" % _score)
	_fruit_pool.erase(fruit)
	_fruit_velocities.erase(fruit)
	# fruit frees itself via its own signal handler

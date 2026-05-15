# Spawner.gd
extends Node3D

@export var collectable_scenes: Array[PackedScene]  # drag multiple scenes in here
@export var spawn_distance: float = 30.0
@export var spawn_interval: float = 1.5
@export var lane_width: float = 4.0

func _ready():
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_spawn)
	add_child(timer)

func _spawn():
	if collectable_scenes.is_empty():
		return

	var scene = collectable_scenes.pick_random()
	var collectable = scene.instantiate()
	get_parent().add_child(collectable)

	var rand_x = randf_range(-lane_width, lane_width)
	collectable.global_position = Vector3(rand_x, 0, -spawn_distance)

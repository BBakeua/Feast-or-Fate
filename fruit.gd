# Collectable.gd
extends Area3D

@export var speed: float = 12.0
@export var despawn_z: float = 5.0

func _process(delta):
	position.z += speed * delta

	if position.z > despawn_z:
		queue_free()

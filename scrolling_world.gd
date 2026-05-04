extends Node3D

## Scrolling World Script
## Attach this to your "Scrolling World" node.
## All children scroll along the -Z axis and recycle to the back when off-screen.

@export var jetski: CharacterBody3D          ## Drag your Jetski node here
@export var scroll_speed: float = 10.0       ## Units per second
@export var offscreen_threshold: float = 10.0      ## How far behind the jetski before recycling
@export var recycle_distance_ahead: float = 50.0   ## How far ahead to place recycled pieces

var _children: Array[Node3D] = []


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			_children.append(child as Node3D)


func _physics_process(delta: float) -> void:
	if not jetski:
		push_warning("ScrollingWorld: No Jetski assigned!")
		return

	for piece in _children:
		# Move along +Z axis
		piece.global_position.z += scroll_speed * delta

		# Check if piece has gone too far behind the jetski
		if piece.global_position.z > jetski.global_position.z + offscreen_threshold:
			_recycle(piece)


func _recycle(piece: Node3D) -> void:
	# Find the farthest piece ahead on -Z (lowest Z = furthest ahead)
	var farthest_z := INF
	for other in _children:
		if other.global_position.z < farthest_z:
			farthest_z = other.global_position.z

	# Place this piece just beyond the farthest one
	piece.global_position.z = farthest_z - recycle_distance_ahead

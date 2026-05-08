extends Node3D

## ScrollingWorld.gd
## Attach this script to the "Scrolling World" node.
## All direct children will scroll toward the Jetski (CharacterBody3D)
## and teleport to the back when they go off-screen.

# ── Inspector Settings ──────────────────────────────────────────────────────

## How fast the world scrolls toward the player (units/sec)
@export var scroll_speed: float = 10.0

## Direction the world moves (relative to player). Default: -Z (forward)
@export var scroll_direction: Vector3 = Vector3(0, 0, -1)

## How far ahead (in scroll axis) objects spawn / reset to
@export var spawn_distance: float = 80.0

## How far behind the player an object must be before it's recycled
@export var recycle_distance: float = 20.0

## Path to the CharacterBody3D (Jetski) node
@export var jetski_path: NodePath = NodePath("../Jetski")

# ── Private ─────────────────────────────────────────────────────────────────

var _jetski: CharacterBody3D
var _children: Array[Node3D] = []

# Per-child: original offset on the axes perpendicular to scroll,
# so we only recycle/reset the scroll axis position.
var _lateral_offsets: Dictionary = {}   # Node3D -> Vector2 (x, y or whichever axes are not scroll)

# Pre-computed helpers
var _scroll_axis: int          # 0=X, 1=Y, 2=Z
var _scroll_sign: float        # +1 or -1


func _ready() -> void:
	_jetski = get_node(jetski_path) as CharacterBody3D
	if _jetski == null:
		push_error("ScrollingWorld: Could not find Jetski at path '%s'" % jetski_path)
		return

	# Determine which axis we scroll along
	var abs_dir := scroll_direction.abs()
	if abs_dir.x >= abs_dir.y and abs_dir.x >= abs_dir.z:
		_scroll_axis = 0
	elif abs_dir.y >= abs_dir.x and abs_dir.y >= abs_dir.z:
		_scroll_axis = 1
	else:
		_scroll_axis = 2

	_scroll_sign = sign(scroll_direction[_scroll_axis])

	# Collect children
	for child in get_children():
		var n := child as Node3D
		if n == null:
			continue
		_children.append(n)
		# Store lateral offset (the axes we won't touch during recycling)
		_lateral_offsets[n] = _get_lateral(n.global_position)


func _process(delta: float) -> void:
	if _jetski == null:
		return

	var move := scroll_direction.normalized() * scroll_speed * delta
	var player_scroll_pos: float = _jetski.global_position[_scroll_axis]

	for child in _children:
		# Move child toward player
		child.global_position += move

		# Check if it has gone far enough behind the player
		var child_scroll_pos: float = child.global_position[_scroll_axis]
		var behind: float = (player_scroll_pos - child_scroll_pos) * _scroll_sign

		if behind > recycle_distance:
			_recycle(child, player_scroll_pos)


# ── Helpers ──────────────────────────────────────────────────────────────────

## Move a child to spawn_distance ahead of the player, keeping lateral position.
func _recycle(child: Node3D, player_scroll_pos: float) -> void:
	var new_pos := child.global_position
	# Place it spawn_distance ahead (opposite of scroll direction)
	new_pos[_scroll_axis] = player_scroll_pos + spawn_distance * _scroll_sign
	child.global_position = new_pos


## Returns the two lateral components of a position as a Vector2.
func _get_lateral(pos: Vector3) -> Vector2:
	match _scroll_axis:
		0: return Vector2(pos.y, pos.z)
		1: return Vector2(pos.x, pos.z)
		_: return Vector2(pos.x, pos.y)

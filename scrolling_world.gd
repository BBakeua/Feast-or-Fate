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
var _lateral_offsets: Dictionary = {}
var _scroll_axis: int
var _scroll_sign: float

func _ready() -> void:
	_jetski = get_node(jetski_path) as CharacterBody3D
	if _jetski == null:
		push_error("ScrollingWorld: Could not find Jetski at path '%s'" % jetski_path)
		return
	var abs_dir := scroll_direction.abs()
	if abs_dir.x >= abs_dir.y and abs_dir.x >= abs_dir.z:
		_scroll_axis = 0
	elif abs_dir.y >= abs_dir.x and abs_dir.y >= abs_dir.z:
		_scroll_axis = 1
	else:
		_scroll_axis = 2
	_scroll_sign = sign(scroll_direction[_scroll_axis])
	for child in get_children():
		var n := child as Node3D
		if n == null:
			continue
		_children.append(n)
		_lateral_offsets[n] = _get_lateral(n.global_position)

func _process(delta: float) -> void:
	if _jetski == null:
		return
	var move := scroll_direction.normalized() * scroll_speed * delta
	var player_scroll_pos: float = _jetski.global_position[_scroll_axis]
	for child in _children:
		child.global_position -= move
		var child_scroll_pos: float = child.global_position[_scroll_axis]
		var behind: float = (player_scroll_pos - child_scroll_pos) * _scroll_sign
		if behind > recycle_distance:
			_recycle(child, player_scroll_pos)

func _recycle(child: Node3D, player_scroll_pos: float) -> void:
	var new_pos := child.global_position

	# Find the furthest-ahead sibling so we queue behind it, not near the player
	var furthest_scroll_pos := player_scroll_pos
	for c in _children:
		var s: float = c.global_position[_scroll_axis]
		var dist_ahead: float = (s - player_scroll_pos) * _scroll_sign
		if dist_ahead > (furthest_scroll_pos - player_scroll_pos) * _scroll_sign:
			furthest_scroll_pos = s

	new_pos[_scroll_axis] = furthest_scroll_pos + spawn_distance * _scroll_sign
	child.global_position = new_pos

func _get_lateral(pos: Vector3) -> Vector2:
	match _scroll_axis:
		0: return Vector2(pos.y, pos.z)
		1: return Vector2(pos.x, pos.z)
		_: return Vector2(pos.x, pos.y)

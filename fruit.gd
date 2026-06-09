extends Area3D

signal collected

@export var jetski_layer: int = 1
@export var bob_speed: float  = 2.0
@export var bob_height: float = 0.15
@export var fade_duration: float = 0.3

var _start_y: float
var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	_start_y = position.y
	body_entered.connect(_on_body_entered)
	collision_mask = jetski_layer


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _start_y + sin(_time * bob_speed) * bob_height


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if body is Node3D:
		_collect()


func _collect() -> void:
	_collected = true
	emit_signal("collected")

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, fade_duration)

	var mesh := find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mesh and mesh.get_surface_override_material(0):
		var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
		mat = mat.duplicate()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.set_surface_override_material(0, mat)
		tween.tween_property(mat, "albedo_color:a", 0.0, fade_duration)

	tween.chain().tween_callback(queue_free)
	$CollisionShape3D.set_deferred("disabled", true)

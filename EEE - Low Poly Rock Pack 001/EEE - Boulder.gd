extends StaticBody3D
## Obstacle.gd
## Attach to the root node of each obstacle PackedScene.
##
## SCENE STRUCTURE (example):
##   StaticBody3D  ← this script
##     MeshInstance3D
##     CollisionShape3D
##
## COLLISION SETUP:
##   • This node needs a CollisionShape3D child (already required for
##     StaticBody3D to block anything).
##   • The Jetski CharacterBody3D must also have a CollisionShape3D.
##   • In Project → Project Settings → Layer Names → 3D Physics, give the
##     Jetski its own layer (e.g. layer 2 "jetski") and set this obstacle's
##     Collision → Mask to include that layer so body_entered fires.
##   • Alternatively, leave layers at default (layer 1) — it will still work
##     as long as the Jetski isn't set to layer 0.

# ── Tunables ──────────────────────────────────────────────────────────────────

## Optional: spin the obstacle for visual flair (radians per second).
@export var spin_speed: Vector3 = Vector3(0.0, 1.2, 0.0)

## Seconds to wait before restarting the scene (gives time for effects/sound).
@export var restart_delay: float = 0.4

## Group name used to identify the Jetski node.
## Add the Jetski to this group via Inspector → Node → Groups panel.
## Leave empty to treat ANY CharacterBody3D as the Jetski.
@export var jetski_group: String = "jetski"

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted the frame the Jetski is hit, before the scene reloads.
## Connect this in your HUD/audio manager to play a crash sound, show an
## explosion, freeze the camera, etc.
signal jetski_hit

# ── Internal ──────────────────────────────────────────────────────────────────

var _hit: bool = false   # guard so multiple contacts don't double-trigger

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# body_entered requires an Area3D — StaticBody3D doesn't emit it on its own.
	# We auto-create a child Area3D that mirrors our collision shape.
	_connect_area()


func _process(delta: float) -> void:
	rotate_x(spin_speed.x * delta)
	rotate_y(spin_speed.y * delta)
	rotate_z(spin_speed.z * delta)

# ── Collision detection ───────────────────────────────────────────────────────

## Looks for a child Area3D named "HitArea" (auto-created if missing) and
## connects its body_entered signal. Using an Area3D child is the standard
## Godot pattern for detecting when something enters a StaticBody3D.
func _connect_area() -> void:
	var area := get_node_or_null("HitArea") as Area3D
	if area == null:
		area = Area3D.new()
		area.name = "HitArea"
		add_child(area)

		# Clone the first CollisionShape3D found so the hit zone matches exactly.
		for child in get_children():
			if child is CollisionShape3D:
				var shape_copy := CollisionShape3D.new()
				shape_copy.shape = (child as CollisionShape3D).shape
				area.add_child(shape_copy)
				break

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _hit:
		return   # already triggered — ignore follow-up contacts

	# Accept the hit only from a CharacterBody3D in the jetski group.
	# If jetski_group is empty, any CharacterBody3D counts.
	var is_jetski: bool = (
		body is CharacterBody3D
		and (jetski_group.is_empty() or body.is_in_group(jetski_group))
	)

	if not is_jetski:
		return

	_hit = true
	emit_signal("jetski_hit")
	_kill_jetski(body)


# ── Kill & restart ────────────────────────────────────────────────────────────

func _kill_jetski(jetski: Node3D) -> void:
	# 1. Zero velocity and disable processing so the Jetski freezes instantly.
	if jetski is CharacterBody3D:
		(jetski as CharacterBody3D).velocity = Vector3.ZERO
		jetski.set_physics_process(false)
		jetski.set_process(false)

	# 2. Hide the Jetski for an instant "death" visual.
	jetski.visible = false

	# 3. Pause the obstacle spawner so nothing new appears during the delay.
	var spawner := get_tree().current_scene.find_child("ObstacleSpawner", true, false)
	if spawner and spawner.has_method("set_spawning"):
		spawner.set_spawning(false)

	# 4. Reload the scene after restart_delay seconds.
	get_tree().create_timer(restart_delay).timeout.connect(_restart_scene)


func _restart_scene() -> void:
	get_tree().reload_current_scene()

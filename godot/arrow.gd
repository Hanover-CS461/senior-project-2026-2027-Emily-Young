
extends Area3D

@export var speed: float = 18.0
@export var damage: float = 8.0
@export var lifetime: float = 5.0

# Set this to the collision layer used by walls.
@export_flags_3d_physics var wall_collision_mask: int = 1

var direction: Vector3 = Vector3.ZERO
var has_been_fired: bool = false

@onready var arrow_model: Node3D = $ArrowModel


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(
	new_direction: Vector3,
	new_damage: float,
	new_speed: float
) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed

	if direction.length() < 0.01:
		queue_free()
		return

	look_at(global_position + direction, Vector3.UP)
	arrow_model.rotation = Vector3(PI / 2.0, 0.0, 0.0)

	has_been_fired = true

	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	if not has_been_fired:
		return

	var next_position := global_position + direction * speed * delta

	# Check for walls between the current and next position.
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		next_position
	)

	query.collision_mask = wall_collision_mask
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if not result.is_empty():
		global_position = result["position"]
		queue_free()
		return

	global_position = next_position


func _on_body_entered(body: Node3D) -> void:
	if not has_been_fired:
		return

	if body.is_in_group("player1") or body.is_in_group("player2"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

		queue_free()

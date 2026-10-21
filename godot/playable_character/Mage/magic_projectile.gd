
extends MeshInstance3D

@export var speed: float = 12.0
@export var damage: int = 20

# Assign the three spell scenes in the Inspector.
@export var magic_fireball: PackedScene
@export var magic_heal: PackedScene
@export var magic_ice: PackedScene

var target_position: Vector3 = Vector3.ZERO
var spell_name: String = "Fireball"
var visual_instance: Node3D

var already_hit: bool = false

@onready var hit_area: Area3D = $Area3D


func _ready() -> void:
	print("DEBUG: Projectile ready. Spell = ", spell_name)

	if hit_area:
		hit_area.monitoring = true
		hit_area.monitorable = true


func set_target(target: Vector3) -> void:
	target_position = target


func set_spell(spell: String) -> void:
	spell_name = spell.strip_edges()
	print("Projectile spell: ", spell_name)

	var visual_scene: PackedScene = null

	match spell_name.to_lower():
		"fireball", "fire":
			spell_name = "Fireball"
			visual_scene = magic_fireball
			scale = Vector3(1.2, 1.2, 1.2)

		"ice":
			spell_name = "Ice"
			visual_scene = magic_ice
			scale = Vector3.ONE

		"heal", "healing":
			spell_name = "Heal"
			visual_scene = magic_heal
			scale = Vector3.ONE

		_:
			push_warning("Unknown spell: " + spell_name)
			return

	if visual_scene == null:
		push_warning("No visual scene assigned for " + spell_name)
		return

	if is_instance_valid(visual_instance):
		visual_instance.queue_free()

	visual_instance = visual_scene.instantiate() as Node3D

	if visual_instance == null:
		push_warning(
			"The visual for " + spell_name
			+ " must have a Node3D-compatible root."
		)
		return

	add_child(visual_instance)
	visual_instance.position = Vector3.ZERO
	visible = true

	print("Loaded visual for: ", spell_name)


func _physics_process(delta: float) -> void:
	if already_hit:
		return

	if not is_instance_valid(hit_area):
		return

	var distance := global_position.distance_to(target_position)

	if distance <= 0.05:
		global_position = target_position
		_check_for_hits()
		if not already_hit:
			print("Projectile reached target without a hit: ", spell_name)
			queue_free()
		return

	var direction := global_position.direction_to(target_position)
	var movement := speed * delta

	if movement >= distance:
		global_position = target_position
	else:
		global_position += direction * movement

	_check_for_hits()


func _check_for_hits() -> void:
	if already_hit or not is_instance_valid(hit_area):
		return

	# Detect enemies.
	for body in hit_area.get_overlapping_bodies():
		if not is_instance_valid(body):
			continue

		if body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				already_hit = true
				body.take_damage(damage)
				print("Mage ", spell_name, " hits enemy!")
				queue_free()
				return

	# Detect puzzle targets.
	for area in hit_area.get_overlapping_areas():
		if not is_instance_valid(area):
			continue

		if spell_name == "Fireball":
			if area.is_in_group("fire_targets"):
				if area.has_method("receive_spell"):
					already_hit = true
					area.call("receive_spell", "Fireball")
					print("Mage Fireball hits a puzzle target!")
					queue_free()
					return

		elif spell_name == "Ice":
			var is_ice_target := area.is_in_group("ice_targets")
			var is_ice_shrine := (
				area.name == "IceShrineInteraction"
				or area.has_method("freeze_channel")
				or area.has_method("receive_spell")
					and area.get_script() != null
					and str(area.get_script().resource_path).ends_with(
						"ice_shrine.gd"
					)
			)

			if is_ice_target or is_ice_shrine:
				if area.has_method("receive_spell"):
					already_hit = true
					print("DEBUG: Mage Ice hit ", area.get_path())
					area.call("receive_spell", "Ice")
					queue_free()
					return
				else:
					print(
						"DEBUG: Ice target detected, but it has no "
						+ "receive_spell() method: ",
						area.get_path()
					)

		elif spell_name == "Heal":
			if area.is_in_group("heal_targets"):
				if area.has_method("receive_spell"):
					already_hit = true
					area.call("receive_spell", "Heal")
					print("Mage Heal hits a puzzle target!")
					queue_free()
					return

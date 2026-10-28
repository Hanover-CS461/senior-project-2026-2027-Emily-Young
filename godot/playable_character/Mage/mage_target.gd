
extends Node3D

@export var minimum_distance: float = 0.0
@export var maximum_distance: float = 10.0

@export var projectile_scene: PackedScene

# Projectile spawn adjustments.
@export var spawn_forward_offset: float = 1.2
@export var spawn_height_offset: float = 0.8

var arduino: Node = null
var is_charging: bool = false
var has_initialized_slider: bool = false

@onready var circle: Node3D = $Circle
@onready var aim_line: Node3D = $AimLine


func _ready() -> void:
	arduino = ArduinoMage
	visible = false

	if circle == null:
		push_error("Mage aiming system: Circle node is missing.")

	if aim_line == null:
		push_error("Mage aiming system: AimLine node is missing.")


func _process(_delta: float) -> void:
	if not is_instance_valid(arduino):
		return

	if not arduino.has_received_slider:
		return

	# Initialize the slider without accidentally casting.
	if not has_initialized_slider:
		has_initialized_slider = true
		is_charging = false
		visible = false
		return

	var slider_value: float = float(arduino.slider)

	# CHARGING
	if slider_value < 0.95:
		is_charging = true
		visible = true

		var amount: float = clampf(
			(0.95 - slider_value) / 0.95,
			0.0,
			1.0
		)

		var distance: float = lerpf(
			minimum_distance,
			maximum_distance,
			amount
		)

		position = Vector3(0.0, 0.0, distance)

		var pulse: float = 1.0 + sin(
			float(Time.get_ticks_msec()) * 0.005
		) * 0.08

		if is_instance_valid(circle):
			circle.scale = Vector3(pulse, 1.0, pulse)

		if is_instance_valid(aim_line):
			aim_line.position = Vector3.ZERO
			aim_line.scale = Vector3(1.0, distance, 1.0)

	# RELEASE
	else:
		if is_charging:
			cast_spell()
			is_charging = false

		visible = false


func cast_spell() -> void:
	if projectile_scene == null:
		push_error("Mage aiming system: No projectile scene assigned!")
		return

	if not is_instance_valid(arduino):
		push_error("Mage aiming system: ArduinoMage is unavailable.")
		return

	var mage: Node3D = get_parent() as Node3D

	if not is_instance_valid(mage):
		push_error("Mage aiming system: Parent Mage node is missing.")
		return

	if not is_instance_valid(circle):
		push_error("Mage aiming system: Circle node is missing.")
		return

	# Preserve the current aiming target calculation.
	var target_position: Vector3 = (
		circle.global_position
		+ global_transform.basis.z * 0.5
	)

	var projectile: Node = projectile_scene.instantiate()

	if not is_instance_valid(projectile):
		push_error("Mage aiming system: Could not instantiate projectile.")
		return

	var active_scene: Node = get_tree().current_scene

	if not is_instance_valid(active_scene):
		projectile.free()
		push_error("Mage aiming system: No active scene is available.")
		return

	active_scene.add_child(projectile)

	# Spawn the projectile in front of and above the Mage.
	if not projectile is Node3D:
		projectile.queue_free()
		push_error("Mage aiming system: Projectile root must be Node3D.")
		return

	var projectile_3d: Node3D = projectile as Node3D

	var spawn_position: Vector3 = mage.global_position
	spawn_position += -mage.global_basis.z * spawn_forward_offset
	spawn_position.y += spawn_height_offset

	projectile_3d.global_position = spawn_position

	# Set the target.
	if not projectile.has_method("set_target"):
		projectile.queue_free()
		push_error(
			"Assigned projectile scene has no set_target() function. "
			+ "Attach the projectile script to its root."
		)
		return

	projectile.call("set_target", target_position)

	# Validate the selected spell before indexing the array.
	if not ("spells" in arduino and "selected_spell" in arduino):
		projectile.queue_free()
		push_error("ArduinoMage is missing spell selection data.")
		return

	var spells: Array = arduino.spells
	var selected_spell: int = int(arduino.selected_spell)

	if selected_spell < 0 or selected_spell >= spells.size():
		projectile.queue_free()
		push_error("Mage aiming system: Selected spell index is invalid.")
		return

	var spell_name: String = str(spells[selected_spell])

	# Set the spell.
	if not projectile.has_method("set_spell"):
		projectile.queue_free()
		push_error(
			"Assigned projectile scene has no set_spell() function. "
			+ "Attach the projectile script to its root."
		)
		return

	projectile.call("set_spell", spell_name)

	print("PROJECTILE CREATED: ", spell_name)
	print("Projectile position: ", projectile_3d.global_position)
	print("Projectile target: ", target_position)
	print("MAGE CASTS ", spell_name, "!")

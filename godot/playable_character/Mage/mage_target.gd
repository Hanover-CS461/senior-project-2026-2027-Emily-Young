
extends Node3D

@export var minimum_distance: float = 0.0
@export var maximum_distance: float = 10.0
@export var projectile_scene: PackedScene
@export var spawn_forward_offset: float = 1.2
@export var spawn_height_offset: float = 0.8

# Keyboard aiming charge speed
@export var keyboard_aim_distance_speed: float = 3.0

var arduino: Variant = null

var is_charging: bool = false
var has_initialized_slider: bool = false

var keyboard_was_aiming: bool = false
var keyboard_aim_distance: float = 0.0

@onready var circle: Node3D = $Circle
@onready var aim_line: Node3D = $AimLine


func _ready() -> void:
	arduino = ArduinoMage
	visible = false

	keyboard_aim_distance = minimum_distance

	if circle == null:
		push_error("Mage aiming: Circle node not found.")

	if aim_line == null:
		push_error("Mage aiming: AimLine node not found.")


func _process(delta: float) -> void:
	if not is_instance_valid(arduino):
		return

	# ----------------------------------------
	# KEYBOARD AIMING
	# Hold Control to extend the aim.
	# Release Control to cast.
	# ----------------------------------------

	var keyboard_aiming: bool = Input.is_action_pressed(
		"mage_cast_spell"
	)

	if keyboard_aiming:
		if not keyboard_was_aiming:
			# Start close to the Mage every time.
			keyboard_aim_distance = minimum_distance
			is_charging = false

		keyboard_was_aiming = true
		visible = true

		# Gradually extend the target while Control is held.
		keyboard_aim_distance += keyboard_aim_distance_speed * delta
		keyboard_aim_distance = clampf(
			keyboard_aim_distance,
			minimum_distance,
			maximum_distance
		)

		_update_aim_visuals(keyboard_aim_distance)
		return

	elif keyboard_was_aiming:
		# Releasing Control casts at the current distance.
		keyboard_was_aiming = false
		visible = false
		cast_spell()
		return

	# ----------------------------------------
	# ARDUINO SLIDER AIMING
	# Preserve existing controller behavior.
	# ----------------------------------------

	if not arduino.has_received_slider:
		return

	if not has_initialized_slider:
		has_initialized_slider = true
		is_charging = false
		visible = false
		return

	var slider_value: float = float(arduino.slider)

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

		_update_aim_visuals(distance)

	else:
		if is_charging:
			cast_spell()
			is_charging = false

		visible = false


func _update_aim_visuals(distance: float) -> void:
	if not is_instance_valid(circle):
		return

	if not is_instance_valid(aim_line):
		return

	position = Vector3(0.0, 0.0, distance)

	var pulse: float = 1.0 + sin(
		Time.get_ticks_msec() * 0.005
	) * 0.08

	circle.scale = Vector3(pulse, 1.0, pulse)

	aim_line.position = Vector3.ZERO
	aim_line.scale = Vector3(1.0, distance, 1.0)


func cast_spell() -> void:
	if projectile_scene == null:
		push_error("Mage aiming: Projectile scene is not assigned.")
		return

	if not is_instance_valid(arduino):
		push_error("Mage aiming: ArduinoMage is unavailable.")
		return

	var mage: Node3D = get_parent() as Node3D

	if not is_instance_valid(mage):
		push_error("Mage aiming: Parent Mage node not found.")
		return

	if not is_instance_valid(circle):
		push_error("Mage aiming: Circle node is unavailable.")
		return

	var target_position: Vector3 = (
		circle.global_position
		+ global_transform.basis.z * 0.5
	)

	var projectile: Node = projectile_scene.instantiate()
	var active_scene: Node = get_tree().current_scene

	if active_scene == null:
		push_error("Mage aiming: Current scene is unavailable.")
		projectile.free()
		return

	active_scene.add_child(projectile)

	if not projectile is Node3D:
		push_error("Mage aiming: Projectile must be a Node3D.")
		projectile.queue_free()
		return

	var projectile_3d: Node3D = projectile as Node3D

	var spawn_position: Vector3 = mage.global_position
	spawn_position += -mage.global_basis.z * spawn_forward_offset
	spawn_position.y += spawn_height_offset

	projectile_3d.global_position = spawn_position

	projectile.call("set_target", target_position)

	var spells_value: Variant = arduino.get("spells")
	var selected_value: Variant = arduino.get("selected_spell")

	if not spells_value is Array:
		push_error("Mage aiming: ArduinoMage.spells is not an Array.")
		projectile.queue_free()
		return

	var spells: Array = spells_value
	var selected_spell: int = int(selected_value)

	if selected_spell < 0 or selected_spell >= spells.size():
		push_error("Mage aiming: Selected spell index is invalid.")
		projectile.queue_free()
		return

	var spell_name: String = str(spells[selected_spell])

	projectile.call("set_spell", spell_name)

	print(
		"Mage cast: ",
		spell_name,
		" | Target: ",
		target_position
	)

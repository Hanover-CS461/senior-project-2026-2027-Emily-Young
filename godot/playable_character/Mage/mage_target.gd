extends Node3D

@export var minimum_distance: float = 0.0
@export var maximum_distance: float = 10.0

@export var projectile_scene: PackedScene

# Projectile spawn adjustments.
@export var spawn_forward_offset: float = 1.2
@export var spawn_height_offset: float = 0.8

var arduino
var is_charging: bool = false
var has_initialized_slider: bool = false

@onready var circle = $Circle
@onready var aim_line = $AimLine


func _ready() -> void:
	arduino = ArduinoMage
	visible = false


func _process(_delta: float) -> void:
	if arduino == null:
		return

	if not arduino.has_received_slider:
		return

	# INITIALIZE SLIDER
	if not has_initialized_slider:
		has_initialized_slider = true
		is_charging = false
		visible = false
		return

	# GET SLIDER
	var slider = arduino.slider

	# CHARGING
	if slider < 0.95:
		is_charging = true
		visible = true

		var amount = (0.95 - slider) / 0.95

		var distance = lerp(
			minimum_distance,
			maximum_distance,
			amount
		)

		position = Vector3(
			0,
			0,
			distance
		)

		var pulse = 1.0 + sin(
			Time.get_ticks_msec() * 0.005
		) * 0.08

		circle.scale = Vector3(
			pulse,
			1,
			pulse
		)

		aim_line.position = Vector3.ZERO

		aim_line.scale = Vector3(
			1,
			distance,
			1
		)

	# RELEASE
	else:
		if is_charging:
			cast_spell()
			is_charging = false

		visible = false


func cast_spell() -> void:
	if projectile_scene == null:
		push_error("No projectile scene assigned!")
		return

	var target_position = (
		circle.global_position
		+ global_transform.basis.z * 0.5
	)

	var projectile = projectile_scene.instantiate()

	if projectile == null:
		push_error("Could not create projectile!")
		return

	# Add the projectile to the active scene.
	get_tree().current_scene.add_child(projectile)

	var mage = get_parent()

	# Spawn the projectile in front of and above the Mage.
	var spawn_position = mage.global_position
	spawn_position += -mage.global_basis.z * spawn_forward_offset
	spawn_position.y += spawn_height_offset

	projectile.global_position = spawn_position

	# Set the target.
	if not projectile.has_method("set_target"):
		push_error(
			"The assigned projectile scene has no set_target() "
			+ "function. Attach your projectile script to its root."
		)
		projectile.queue_free()
		return

	projectile.set_target(target_position)

	# Get the selected spell.
	var spell_name: String = str(
		arduino.spells[arduino.selected_spell]
	)

	# Set the spell.
	if not projectile.has_method("set_spell"):
		push_error(
			"The assigned projectile scene has no set_spell() "
			+ "function. Attach your projectile script to its root."
		)
		projectile.queue_free()
		return

	projectile.set_spell(spell_name)

	print("PROJECTILE CREATED: ", spell_name)
	print("Projectile position: ", projectile.global_position)
	print("Projectile target: ", target_position)
	print("MAGE CASTS ", spell_name, "!")

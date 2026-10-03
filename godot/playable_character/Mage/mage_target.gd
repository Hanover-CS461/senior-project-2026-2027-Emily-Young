extends Node3D


@export var minimum_distance = 0.0
@export var maximum_distance = 10.0

@export var projectile_scene: PackedScene


var arduino
var is_charging = false
var has_initialized_slider = false


@onready var circle = $Circle
@onready var aim_line = $AimLine


func _ready():

	arduino = ArduinoMage

	visible = false


func _process(_delta):

	if arduino == null:

		return


	if not arduino.has_received_slider:

		return


	# --------------------------------------------------
	# INITIALIZE SLIDER
	# --------------------------------------------------

	if not has_initialized_slider:

		has_initialized_slider = true

		is_charging = false

		visible = false

		return


	# --------------------------------------------------
	# GET SLIDER
	# --------------------------------------------------

	var slider = arduino.slider


	# --------------------------------------------------
	# CHARGING
	# --------------------------------------------------

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


		aim_line.position = Vector3(
			0,
			0,
			0
		)


		aim_line.scale = Vector3(
			1,
			distance,
			1
		)


	# --------------------------------------------------
	# RELEASE
	# --------------------------------------------------

	else:

		if is_charging:

			cast_spell()

			is_charging = false


		visible = false


func cast_spell():

	if projectile_scene == null:

		print("ERROR: No projectile scene assigned!")

		return


	var target_position = (
		circle.global_position
		+ global_transform.basis.z * 0.5
	)


	var projectile = projectile_scene.instantiate()


	if projectile == null:

		print("ERROR: Could not create projectile!")

		return


	get_tree().current_scene.add_child(projectile)


	var mage = get_parent()


	projectile.global_position = mage.global_position


	projectile.set_target(target_position)


	projectile.set_spell(
		arduino.spells[arduino.selected_spell]
	)


	print(
		"PROJECTILE CREATED: ",
		arduino.spells[arduino.selected_spell]
	)


	print(
		"Projectile position: ",
		projectile.global_position
	)


	print(
		"Projectile target: ",
		target_position
	)


	print(
		"MAGE CASTS ",
		arduino.spells[arduino.selected_spell],
		"!"
	)

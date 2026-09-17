extends Node3D


@export var minimum_distance = 0.0
@export var maximum_distance = 10.0

var arduino

@onready var circle = $Circle
@onready var aim_line = $AimLine


func _ready():

	arduino = get_tree().current_scene.get_node("ArduinoMage")

	visible = false


func _process(_delta):

	if arduino == null:
		return


	var slider = arduino.slider


	# ==========================================
	# SHOW TARGET WHILE SLIDER IS PULLED
	# ==========================================

	if slider < 0.95:

		visible = true


		# Convert slider position into distance

		var amount = (0.95 - slider) / 0.95

		var distance = lerp(
			minimum_distance,
			maximum_distance,
			amount
		)


		# ==========================================
		# MOVE TARGET
		# ==========================================

		position = Vector3(
			0,
			0,
			distance
		)


		# ==========================================
		# MAKE CIRCLE PULSE
		# ==========================================

		var pulse = 1.0 + sin(
			Time.get_ticks_msec() * 0.005
		) * 0.08

		circle.scale = Vector3(
			pulse,
			1,
			pulse
		)


		# ==========================================
		# AIM LINE
		# ==========================================

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


	# ==========================================
	# HIDE TARGET WHEN SLIDER IS RELEASED
	# ==========================================

	else:

		visible = false

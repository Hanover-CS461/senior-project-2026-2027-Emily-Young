extends Node3D


var manager: GdSerialManager


var joystick_x = 0.0
var joystick_y = 0.0

var camera_x = 0.0
var camera_y = 0.0


var slider = 1.0
var previous_slider = 1.0

var has_received_slider = false
var slider_initialized = false
var slider_was_pulled = false


var jump_pressed = false
var sprint_pressed = false


var selected_spell = 0

var spells = [
	"Fireball",
	"Ice",
	"Lightning"
]


const LEFT_CENTER_X = 503.0
const LEFT_CENTER_Y = 536.0

const RIGHT_CENTER_X = 509.0
const RIGHT_CENTER_Y = 514.0

const DEAD_ZONE = 0.08


const CHARGE_THRESHOLD = 0.95


func _ready():

	manager = GdSerialManager.new()

	manager.data_received.connect(_on_data_received)


	if manager.open(
		"COM5",
		9600,
		1000,
		GdSerialManager.MODE_LINE_BUFFERED
	):

		print("Arduino connected!")

	else:

		print("Could not connect to Arduino!")


func _process(_delta):

	manager.poll_events()


# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func get_movement():

	var movement = Vector2(
		joystick_x,
		joystick_y
	)


	if movement.length() < DEAD_ZONE:

		return Vector2.ZERO


	return movement.normalized() * min(
		movement.length(),
		1.0
	)


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func get_look():

	var look = Vector2(
		camera_x,
		camera_y
	)


	if look.length() < DEAD_ZONE:

		return Vector2.ZERO


	return look.normalized() * min(
		look.length(),
		1.0
	)


# --------------------------------------------------
# JOYSTICK NORMALIZATION
# --------------------------------------------------

func normalize_joystick(
	raw_value: float,
	center: float
) -> float:

	var value = 0.0


	if raw_value >= center:

		value = (
			raw_value - center
		) / (
			1023.0 - center
		)

	else:

		value = (
			raw_value - center
		) / center


	value = clamp(
		value,
		-1.0,
		1.0
	)


	if abs(value) < DEAD_ZONE:

		value = 0.0


	return value


# --------------------------------------------------
# ARDUINO DATA
# --------------------------------------------------

func _on_data_received(
	port: String,
	data: PackedByteArray
):

	var text = data.get_string_from_utf8().strip_edges()

	var lines = text.split("\n")


	for line in lines:

		line = line.strip_edges()


		# ------------------------------------------
		# JUMP
		# ------------------------------------------

		if line == "JUMP":

			jump_pressed = true


		# ------------------------------------------
		# SPRINT
		# ------------------------------------------

		elif line == "SPRINT":

			sprint_pressed = true


		elif line == "SPRINT_RELEASE":

			sprint_pressed = false


		# ------------------------------------------
		# SPELL SELECT
		# ------------------------------------------

		elif line == "ENCODER_RIGHT":

			selected_spell += 1


			if selected_spell >= spells.size():

				selected_spell = 0


			print(
				"Selected spell: ",
				spells[selected_spell]
			)


		elif line == "ENCODER_LEFT":

			selected_spell -= 1


			if selected_spell < 0:

				selected_spell = spells.size() - 1


			print(
				"Selected spell: ",
				spells[selected_spell]
			)


		# ------------------------------------------
		# JOYSTICKS + SLIDER
		# ------------------------------------------

		else:

			var values = line.split(",")


			if values.size() == 5:

				var left_x = values[0].to_float()
				var left_y = values[1].to_float()

				var right_x = values[2].to_float()
				var right_y = values[3].to_float()

				var slider_raw = values[4].to_float()


				joystick_x = normalize_joystick(
					left_x,
					LEFT_CENTER_X
				)

				joystick_y = normalize_joystick(
					left_y,
					LEFT_CENTER_Y
				)


				camera_x = normalize_joystick(
					right_x,
					RIGHT_CENTER_X
				)

				camera_y = normalize_joystick(
					right_y,
					RIGHT_CENTER_Y
				)


				var new_slider = slider_raw / 1023.0


				# ----------------------------------
				# FIRST SLIDER READING
				# ----------------------------------

				if not slider_initialized:

					slider = new_slider
					previous_slider = new_slider

					has_received_slider = true
					slider_initialized = true

					# IMPORTANT:
					# Do NOT allow the first reading
					# to start a spell.

					slider_was_pulled = false

					return


				# ----------------------------------
				# NORMAL SLIDER READING
				# ----------------------------------

				previous_slider = slider

				slider = new_slider

				has_received_slider = true


				# ----------------------------------
				# START CHARGING
				# ----------------------------------

				if slider < CHARGE_THRESHOLD:

					slider_was_pulled = true


				# ----------------------------------
				# DEBUG
				# ----------------------------------

				if previous_slider >= CHARGE_THRESHOLD and slider < CHARGE_THRESHOLD:

					print("Mage started charging!")


				# ----------------------------------
				# RELEASE
				# ----------------------------------

				if (
					previous_slider < CHARGE_THRESHOLD
					and slider >= CHARGE_THRESHOLD
					and slider_was_pulled
				):

					print("Mage released spell!")

					slider_was_pulled = false

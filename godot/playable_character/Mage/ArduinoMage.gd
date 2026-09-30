extends Node3D


var manager: GdSerialManager

var joystick_x = 0.0
var joystick_y = 0.0

var camera_x = 0.0
var camera_y = 0.0

var slider = 1.0
var previous_slider = 1.0

var was_charged = false

var has_received_slider = false


# ==========================================
# JUMP
# ==========================================

var jump_pressed = false


# ==========================================
# SPRINT
# ==========================================

var sprint_pressed = false


# ==========================================
# SPELL SELECTION
# ==========================================

var selected_spell = 0

var spells = [
	"Fireball",
	"Ice",
	"Lightning"
]


# ==========================================
# JOYSTICK SETTINGS
# ==========================================

const LEFT_CENTER_X = 503.0
const LEFT_CENTER_Y = 536.0

const RIGHT_CENTER_X = 509.0
const RIGHT_CENTER_Y = 514.0

const DEAD_ZONE = 0.08


# ==========================================
# SLIDER SETTINGS
# ==========================================

const CHARGE_THRESHOLD = 0.95
const RELEASE_THRESHOLD = 0.95


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


func normalize_joystick(raw_value: float, center: float) -> float:

	var value = 0.0

	if raw_value >= center:

		value = (raw_value - center) / (1023.0 - center)

	else:

		value = (raw_value - center) / center

	value = clamp(value, -1.0, 1.0)

	if abs(value) < DEAD_ZONE:

		value = 0.0

	return value


func _on_data_received(port: String, data: PackedByteArray):

	var text = data.get_string_from_utf8().strip_edges()

	var lines = text.split("\n")


	for line in lines:

		line = line.strip_edges()


		# ==========================================
		# JUMP BUTTON
		# ==========================================

		if line == "JUMP":

			jump_pressed = true


		# ==========================================
		# SPRINT BUTTON
		# ==========================================

		elif line == "SPRINT":

			sprint_pressed = true


		elif line == "SPRINT_RELEASE":

			sprint_pressed = false


		# ==========================================
		# ROTARY ENCODER
		# ==========================================

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


		# ==========================================
		# CONTROLLER VALUES
		# ==========================================

		else:

			var values = line.split(",")

			if values.size() == 5:

				var left_x = values[0].to_float()
				var left_y = values[1].to_float()

				var right_x = values[2].to_float()
				var right_y = values[3].to_float()

				var slider_raw = values[4].to_float()


				# ==========================================
				# MOVEMENT JOYSTICK
				# ==========================================

				joystick_x = normalize_joystick(
					left_x,
					LEFT_CENTER_X
				)

				joystick_y = normalize_joystick(
					left_y,
					LEFT_CENTER_Y
				)


				# ==========================================
				# CAMERA JOYSTICK
				# ==========================================

				camera_x = normalize_joystick(
					right_x,
					RIGHT_CENTER_X
				)

				camera_y = normalize_joystick(
					right_y,
					RIGHT_CENTER_Y
				)


				# ==========================================
				# SLIDER
				# ==========================================

				slider = slider_raw / 1023.0

				has_received_slider = true


				# ==========================================
				# SPELL CAST
				# ==========================================

				if slider <= CHARGE_THRESHOLD:

					was_charged = true


				if was_charged and slider >= RELEASE_THRESHOLD:

					was_charged = false


				previous_slider = slider

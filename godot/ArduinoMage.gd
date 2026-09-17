extends Node3D


var manager: GdSerialManager

var joystick_x = 0.0
var joystick_y = 0.0

var camera_x = 0.0
var camera_y = 0.0

var slider = 1.0

var previous_slider = 1.0

var was_charged = false


# Left joystick centers
const LEFT_CENTER_X = 503.0
const LEFT_CENTER_Y = 536.0

# Right joystick centers
const RIGHT_CENTER_X = 509.0
const RIGHT_CENTER_Y = 514.0

# Joystick dead zone
const DEAD_ZONE = 0.08

# How far the slider must be pulled before it can cast
const CHARGE_THRESHOLD = 0.95

# How close to the top the slider must return to cast
const RELEASE_THRESHOLD = 0.95


func _ready():

	manager = GdSerialManager.new()

	manager.data_received.connect(_on_data_received)

	if manager.open("COM5", 9600, 1000, GdSerialManager.MODE_LINE_BUFFERED):
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

	var values = text.split(",")

	if values.size() == 5:

		var left_x = values[0].to_float()
		var left_y = values[1].to_float()

		var right_x = values[2].to_float()
		var right_y = values[3].to_float()

		var slider_raw = values[4].to_float()


		# Left joystick = movement

		joystick_x = normalize_joystick(
			left_x,
			LEFT_CENTER_X
		)

		joystick_y = normalize_joystick(
			left_y,
			LEFT_CENTER_Y
		)


		# Right joystick = camera

		camera_x = normalize_joystick(
			right_x,
			RIGHT_CENTER_X
		)

		camera_y = normalize_joystick(
			right_y,
			RIGHT_CENTER_Y
		)


		# Slider
		#
		# Top = 1.0
		# Bottom = 0.0

		slider = slider_raw / 1023.0


		# ==========================================
		# SLIDER CAST TEST
		# ==========================================

		# Pull the slider down far enough to charge

		if slider <= CHARGE_THRESHOLD:

			was_charged = true


		# If it was charged and returns to the top,
		# the Mage casts the spell

		if was_charged and slider >= RELEASE_THRESHOLD:

			print("MAGE CASTS!")

			was_charged = false


		previous_slider = slider

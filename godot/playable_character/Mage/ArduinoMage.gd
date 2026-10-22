
extends Node3D

var manager: GdSerialManager

var joystick_x: float = 0.0
var joystick_y: float = 0.0

var camera_x: float = 0.0
var camera_y: float = 0.0

var slider: float = 1.0
var previous_slider: float = 1.0

var has_received_slider: bool = false
var slider_initialized: bool = false
var slider_was_pulled: bool = false

var jump_pressed: bool = false
var sprint_pressed: bool = false
var interact_pressed: bool = false

var selected_spell: int = 0
var spells: Array[String] = ["Fireball", "Ice", "Heal"]

const LEFT_CENTER_X: float = 503.0
const LEFT_CENTER_Y: float = 536.0

const RIGHT_CENTER_X: float = 509.0
const RIGHT_CENTER_Y: float = 514.0

const DEAD_ZONE: float = 0.08
const CHARGE_THRESHOLD: float = 0.95


func _ready() -> void:
	# Continue receiving Arduino data while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

	manager = GdSerialManager.new()
	manager.data_received.connect(_on_data_received)

	if manager.open(
		"COM5",
		9600,
		1000,
		GdSerialManager.MODE_LINE_BUFFERED
	):
		print("Arduino Mage connected!")
	else:
		print("Could not connect to Mage Arduino!")


func _process(_delta: float) -> void:
	if manager != null:
		manager.poll_events()


# --------------------------------------------------
# INTERACTION
# --------------------------------------------------

func consume_interaction() -> bool:
	if not interact_pressed:
		return false

	interact_pressed = false
	return true


# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------

func get_movement() -> Vector2:
	var movement := Vector2(joystick_x, joystick_y)

	if movement.length() < DEAD_ZONE:
		return Vector2.ZERO

	return movement.normalized() * minf(movement.length(), 1.0)


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func get_look() -> Vector2:
	var look := Vector2(camera_x, camera_y)

	if look.length() < DEAD_ZONE:
		return Vector2.ZERO

	return look.normalized() * minf(look.length(), 1.0)


# --------------------------------------------------
# JOYSTICK NORMALIZATION
# --------------------------------------------------

func normalize_joystick(raw_value: float, center: float) -> float:
	var value: float = 0.0

	if raw_value >= center:
		value = (raw_value - center) / (1023.0 - center)
	else:
		value = (raw_value - center) / center

	value = clampf(value, -1.0, 1.0)

	if absf(value) < DEAD_ZONE:
		value = 0.0

	return value


# --------------------------------------------------
# ARDUINO DATA
# --------------------------------------------------

func _on_data_received(_port: String, data: PackedByteArray) -> void:
	var text := data.get_string_from_utf8().strip_edges()
	var lines := text.split("\n")

	for line in lines:
		line = line.strip_edges()

		if line == "JUMP":
			jump_pressed = true

		elif line == "SPRINT":
			sprint_pressed = true

		elif line == "SPRINT_RELEASE":
			sprint_pressed = false

		elif line == "INTERACT":
			interact_pressed = true

		elif line == "ENCODER_RIGHT":
			selected_spell += 1

			if selected_spell >= spells.size():
				selected_spell = 0

			print("Selected spell: ", spells[selected_spell])

		elif line == "ENCODER_LEFT":
			selected_spell -= 1

			if selected_spell < 0:
				selected_spell = spells.size() - 1

			print("Selected spell: ", spells[selected_spell])

		else:
			var values := line.split(",")

			if values.size() != 5:
				continue

			var left_x: float = values[0].to_float()
			var left_y: float = values[1].to_float()
			var right_x: float = values[2].to_float()
			var right_y: float = values[3].to_float()
			var slider_raw: float = values[4].to_float()

			joystick_x = normalize_joystick(left_x, LEFT_CENTER_X)
			joystick_y = normalize_joystick(left_y, LEFT_CENTER_Y)

			camera_x = normalize_joystick(right_x, RIGHT_CENTER_X)
			camera_y = normalize_joystick(right_y, RIGHT_CENTER_Y)

			var new_slider: float = slider_raw / 1023.0

			if not slider_initialized:
				slider = new_slider
				previous_slider = new_slider
				has_received_slider = true
				slider_initialized = true
				slider_was_pulled = false
				continue

			previous_slider = slider
			slider = new_slider
			has_received_slider = true

			if slider < CHARGE_THRESHOLD:
				slider_was_pulled = true

			if (
				previous_slider >= CHARGE_THRESHOLD
				and slider < CHARGE_THRESHOLD
			):
				print("Mage started charging!")

			if (
				previous_slider < CHARGE_THRESHOLD
				and slider >= CHARGE_THRESHOLD
				and slider_was_pulled
			):
				print("Mage released spell!")
				slider_was_pulled = false

extends Node


var manager


var move_x = 517
var move_y = 518

var look_x = 517
var look_y = 512

var sprint = false

var shield = false

var attack_pressed = false


func _ready():

	manager = GdSerialManager.new()

	manager.data_received.connect(_on_data_received)


	if manager.open(
		"COM6",
		9600,
		1000,
		GdSerialManager.MODE_LINE_BUFFERED
	):

		print("Knight Arduino connected!")

	else:

		print("Could not connect to Knight Arduino!")


func _process(_delta):

	manager.poll_events()


func _on_data_received(port: String, data: PackedByteArray):

	var text = data.get_string_from_utf8().strip_edges()

	var sections = text.split("|")


	for section in sections:

		if section.begins_with("MOVE:"):

			var values = section.trim_prefix("MOVE:").split(",")

			if values.size() == 2:

				move_x = int(values[0])
				move_y = int(values[1])


		elif section.begins_with("LOOK:"):

			var values = section.trim_prefix("LOOK:").split(",")

			if values.size() == 2:

				look_x = int(values[0])
				look_y = int(values[1])


		elif section.begins_with("SPRINT:"):

			var value = section.trim_prefix("SPRINT:")

			sprint = value == "1"


		elif section.begins_with("SHIELD:"):

			var value = section.trim_prefix("SHIELD:")

			shield = value == "1"


		elif section.begins_with("ATTACK:"):

			var value = section.trim_prefix("ATTACK:")

			if value == "1":

				attack_pressed = true


func get_movement():

	var x = (move_x - 517) / 506.0
	var y = (move_y - 518) / 505.0

	var movement = Vector2(x, y)

	if movement.length() < 0.15:

		return Vector2.ZERO

	return movement.normalized() * min(movement.length(), 1.0)


func get_look():

	var x = (look_x - 517) / 506.0
	var y = (look_y - 512) / 511.0

	var look = Vector2(x, y)

	if look.length() < 0.15:

		return Vector2.ZERO

	return look.normalized() * min(look.length(), 1.0)

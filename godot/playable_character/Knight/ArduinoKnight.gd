
extends Node

var manager

var move_x: int = 517
var move_y: int = 518

var look_x: int = 517
var look_y: int = 512

var sprint: bool = false
var shield: bool = false

var attack_pressed: bool = false
var jump_pressed: bool = false
var interact_pressed: bool = false
var dodge_pressed: bool = false

var interaction_count: int = 0


func _ready() -> void:
	manager = GdSerialManager.new()
	manager.data_received.connect(_on_data_received)

	if manager.open("COM6", 9600, 1000, GdSerialManager.MODE_LINE_BUFFERED):
		print("Knight Arduino connected!")
	else:
		print("Could not connect to Knight Arduino!")


func _process(_delta: float) -> void:
	if manager != null:
		manager.poll_events()


func _on_data_received(_port: String, data: PackedByteArray) -> void:
	var message: String = data.get_string_from_utf8().strip_edges()
	var sections: PackedStringArray = message.split("|")

	for section in sections:
		var part: String = section.strip_edges()

		if part == "JUMP":
			jump_pressed = true

		elif (
			part == "INTERACT"
			or part == "INTERACT:1"
			or part == "BUTTON:INTERACT"
		):
			interaction_count += 1
			interact_pressed = true

		elif part == "DODGE":
			dodge_pressed = true

		elif part.begins_with("MOVE:"):
			var move_values: PackedStringArray = part.trim_prefix("MOVE:").split(",")

			if move_values.size() == 2:
				move_x = int(move_values[0])
				move_y = int(move_values[1])

		elif part.begins_with("LOOK:"):
			var look_values: PackedStringArray = part.trim_prefix("LOOK:").split(",")

			if look_values.size() == 2:
				look_x = int(look_values[0])
				look_y = int(look_values[1])

		elif part.begins_with("SPRINT:"):
			sprint = part.trim_prefix("SPRINT:") == "1"

		elif part.begins_with("SHIELD:"):
			shield = part.trim_prefix("SHIELD:") == "1"

		elif part.begins_with("ATTACK:"):
			if part.trim_prefix("ATTACK:") == "1":
				attack_pressed = true


func consume_interaction() -> bool:
	if interaction_count > 0:
		interaction_count -= 1
		interact_pressed = interaction_count > 0
		return true

	return false


func get_movement() -> Vector2:
	var x: float = float(move_x - 517) / 506.0
	var y: float = float(move_y - 518) / 505.0

	var movement: Vector2 = Vector2(x, y)

	if movement.length() < 0.15:
		return Vector2.ZERO

	return movement.normalized() * minf(movement.length(), 1.0)


func get_look() -> Vector2:
	var x: float = float(look_x - 517) / 506.0
	var y: float = float(look_y - 512) / 511.0

	var look: Vector2 = Vector2(x, y)

	if look.length() < 0.15:
		return Vector2.ZERO

	return look.normalized() * minf(look.length(), 1.0)

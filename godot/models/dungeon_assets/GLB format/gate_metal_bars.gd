extends Node3D


@export var open_height = 3.0
@export var open_speed = 3.0

var gate_open = false
var starting_position: Vector3

@onready var gate_bars = get_node("gate-metal-bars")
@onready var detection_area = get_node("DetectionArea")


func _ready():

	starting_position = gate_bars.position

	detection_area.body_entered.connect(_on_body_entered)


func _process(delta):

	if not gate_open:
		return

	var target_position = starting_position + Vector3(0, open_height, 0)

	gate_bars.position = gate_bars.position.lerp(
		target_position,
		open_speed * delta
	)


func _on_body_entered(body):

	if body.is_in_group("player1") or body.is_in_group("player2"):

		if not gate_open:

			gate_open = true

			print("Gate opening!")

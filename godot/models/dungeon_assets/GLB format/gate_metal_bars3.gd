extends Node3D


@export var open_height = 3.0
@export var open_speed = 3.0

var gate_open = false
var starting_position: Vector3

@onready var gate_bars = get_node("gate-metal-bars")


func _ready():

	starting_position = gate_bars.position


func _process(delta):

	if not gate_open:

		var remaining_minions = get_tree().get_nodes_in_group("gate_minions")

		if remaining_minions.size() == 0:

			gate_open = true

			print("All three minions are dead! Opening gate!")


	if gate_open:

		var target_position = starting_position + Vector3(
			0,
			open_height,
			0
		)

		gate_bars.position = gate_bars.position.lerp(
			target_position,
			open_speed * delta
		)

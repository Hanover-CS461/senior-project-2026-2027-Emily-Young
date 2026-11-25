extends Node3D

@export var open_height: float = 3.0
@export var open_speed: float = 3.0

@export var detection_area_path: NodePath = ^"DetectionArea"

var gate_open: bool = false
var starting_position: Vector3

@onready var detection_area: Area3D = get_node(detection_area_path)


func _ready() -> void:
	starting_position = position

	detection_area.body_entered.connect(_on_body_entered)

	print("Metal gate ready. Waiting for player.")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("players") \
	or body.is_in_group("player1") \
	or body.is_in_group("player2"):

		gate_open = true
		print("Player entered! Opening metal gate!")


func _process(delta: float) -> void:
	if not gate_open:
		return

	var target_position: Vector3 = starting_position + Vector3.UP * open_height

	position = position.lerp(
		target_position,
		open_speed * delta
	)

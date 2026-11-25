
extends Node3D

@export var open_height: float = 3.0
@export var open_speed: float = 3.0
@export var close_speed: float = 3.0

@export var passage_area_path: NodePath = ^"PassageArea"

var gate_open: bool = false
var gate_closing: bool = false

var starting_position: Vector3
var target_open_position: Vector3

var player1_passed: bool = false
var player2_passed: bool = false

var debug_timer: float = 0.0

@onready var passage_area: Area3D = get_node(passage_area_path)


func _ready() -> void:
	starting_position = position
	target_open_position = starting_position + Vector3.UP * open_height

	passage_area.monitoring = true
	passage_area.monitorable = true
	passage_area.set_collision_mask_value(1, true)

	print("================================")
	print("BOSS DOOR INITIALIZED")
	print("PassageArea: ", passage_area.get_path())
	print("Monitoring: ", passage_area.monitoring)
	print("Collision mask: ", passage_area.collision_mask)
	print("================================")


func _process(delta: float) -> void:

	# Check Skeleton Warriors.
	if not gate_open and not gate_closing:
		if all_skeleton_warriors_defeated():
			gate_open = true
			print("ALL SKELETON WARRIORS DEFEATED! OPENING BOSS DOOR!")

	# Animate opening.
	if gate_open and not gate_closing:
		position = position.move_toward(
			target_open_position,
			open_speed * delta
		)

	# Continuously check players while the gate is open.
	if gate_open and not gate_closing:
		check_players_in_passage()

	# Animate closing.
	if gate_closing:
		position = position.move_toward(
			starting_position,
			close_speed * delta
		)

		if position.distance_to(starting_position) < 0.01:
			position = starting_position
			gate_closing = false
			print("BOSS DOOR FULLY CLOSED!")


func all_skeleton_warriors_defeated() -> bool:
	var warriors = get_tree().get_nodes_in_group("skeleton_warriors")

	if warriors.is_empty():
		return false

	for warrior in warriors:
		if is_instance_valid(warrior):
			if warrior.get("is_alive") == true:
				return false

	return true


func check_players_in_passage() -> void:
	var overlapping_bodies = passage_area.get_overlapping_bodies()

	# Print diagnostic information every second.
	debug_timer += get_process_delta_time()

	if debug_timer >= 1.0:
		debug_timer = 0.0
		print("PASSAGE CHECK: ", overlapping_bodies.size(), " overlapping bodies")

	for body in overlapping_bodies:
		if not is_instance_valid(body):
			continue

		var player = find_player_group(body)

		if player == null:
			if debug_timer == 0.0:
				print("Detected non-player body: ", body.get_path())
			continue

		if player.is_in_group("player1") and not player1_passed:
			player1_passed = true
			print("PLAYER 1 DETECTED IN PASSAGE!")

		if player.is_in_group("player2") and not player2_passed:
			player2_passed = true
			print("PLAYER 2 DETECTED IN PASSAGE!")

	if player1_passed and player2_passed:
		gate_closing = true
		print("BOTH PLAYERS DETECTED! CLOSING BOSS DOOR!")


func find_player_group(body: Node) -> Node:
	var current: Node = body

	while current != null:
		if current.is_in_group("player1"):
			return current

		if current.is_in_group("player2"):
			return current

		current = current.get_parent()

	return null

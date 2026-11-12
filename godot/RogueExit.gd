
extends Node3D

@export var open_height: float = 3.0
@export var open_speed: float = 3.0

var gate_open: bool = false
var starting_position: Vector3


func _ready() -> void:
	starting_position = position
	print("Rogue Exit ready. Waiting for all Rogue enemies to be defeated.")


func _process(delta: float) -> void:
	if not gate_open:
		var living_rogues: Array[Node] = get_living_rogues()

		if living_rogues.is_empty():
			gate_open = true

			print("ALL ROGUES DEFEATED!")
			print("Opening Rogue Room exit!")

			revive_dead_players()
		else:
			# Print the number of living rogues for debugging.
			# This only counts actual Rogue scripts, not parent nodes.
			if Engine.get_process_frames() % 120 == 0:
				print("Living Rogue enemies remaining: ", living_rogues.size())

	if gate_open:
		var target_position: Vector3 = starting_position + Vector3(
			0.0,
			open_height,
			0.0
		)

		position = position.lerp(
			target_position,
			open_speed * delta
		)


# ==========================================
# FIND LIVING ROGUES
# ==========================================

func get_living_rogues() -> Array[Node]:
	var living_rogues: Array[Node] = []

	var rogue_nodes: Array[Node] = (
		get_tree().get_nodes_in_group("rogue_room")
	)

	for rogue in rogue_nodes:
		if not is_instance_valid(rogue):
			continue

		# Only count nodes that actually have the Rogue script.
		if not ("is_dead" in rogue):
			continue

		# Ignore defeated rogues.
		if bool(rogue.get("is_dead")):
			continue

		living_rogues.append(rogue)

	return living_rogues


# ==========================================
# PLAYER REVIVAL
# ==========================================

func revive_dead_players() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("players")

	if players.is_empty():
		players.append_array(
			get_tree().get_nodes_in_group("player1")
		)

		players.append_array(
			get_tree().get_nodes_in_group("player2")
		)

	var revived_any_player: bool = false

	for player: Node in players:
		if not is_instance_valid(player):
			continue

		if not ("is_dead" in player):
			continue

		if not bool(player.get("is_dead")):
			continue

		if player.has_method("revive") and player is Node3D:
			var player_node: Node3D = player as Node3D

			player.call("revive", player_node.global_position)
			revived_any_player = true

	if revived_any_player:
		print("A fallen player has been revived!")
	else:
		print("Rogue exit opened. No dead players needed revival.")

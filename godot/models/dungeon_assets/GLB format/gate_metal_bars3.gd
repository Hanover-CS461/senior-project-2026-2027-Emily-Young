
extends Node3D

@export var open_height: float = 3.0
@export var open_speed: float = 3.0

var gate_open: bool = false
var starting_position: Vector3

@onready var gate_bars: Node3D = get_node("gate-metal-bars")


func _ready() -> void:
	starting_position = gate_bars.position


func _process(delta: float) -> void:
	if not gate_open:
		var remaining_minions: Array[Node] = (
			get_tree().get_nodes_in_group("gate_minions")
		)

		if remaining_minions.is_empty():
			gate_open = true
			print("All three minions are dead! Opening gate!")

			revive_dead_players()

	if gate_open:
		var target_position: Vector3 = starting_position + Vector3(
			0.0,
			open_height,
			0.0
		)

		gate_bars.position = gate_bars.position.lerp(
			target_position,
			open_speed * delta
		)


# ==========================================
# PLAYER REVIVAL
# ==========================================

func revive_dead_players() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("players")

	# Fallback if the players have not been added to a shared group.
	if players.is_empty():
		players.append_array(
			get_tree().get_nodes_in_group("player_1")
		)
		players.append_array(
			get_tree().get_nodes_in_group("player_2")
		)

	var revived_any_player: bool = false

	for player: Node in players:
		if not is_instance_valid(player):
			continue

		if not ("is_dead" in player):
			continue

		if not bool(player.get("is_dead")):
			continue

		if player.has_method("revive"):
			if player is Node3D:
				var player_node: Node3D = player as Node3D

				# Temporary: revive where the player currently is.
				player.call("revive", player_node.global_position)
				revived_any_player = true

	if revived_any_player:
		print("A fallen player has been revived!")
	else:
		print("Gate opened. No dead players needed revival.")

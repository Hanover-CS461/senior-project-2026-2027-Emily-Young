
extends Node

const GAME_OVER_SCENE: PackedScene = preload(
	"res://models/dungeon_assets/GLB format/game_over_screen.tscn"
)

@export_file("*.tscn") var first_scene_path: String = "res://main.tscn"
@export_file("*.tscn") var main_menu_path: String = "res://main_menu.tscn"


# ==================================================
# CHECKPOINT VARIABLES
# ==================================================

var checkpoint_active: bool = false
var checkpoint_scene_path: String = ""
var active_checkpoint_id: StringName = &""

var player1_checkpoint_position: Vector3 = Vector3.ZERO
var player2_checkpoint_position: Vector3 = Vector3.ZERO


# ==================================================
# GAME OVER VARIABLES
# ==================================================

var game_over_screen: GameOverScreen = null
var team_wipe_triggered: bool = false


# ==================================================
# CHECKPOINT
# ==================================================

func has_checkpoint() -> bool:
	return checkpoint_active


func activate_checkpoint(
	player1: Node3D,
	player2: Node3D,
	respawn_point: Node3D = null
) -> void:

	if not is_instance_valid(player1) or not is_instance_valid(player2):
		push_warning(
			"GameManager: Both players must exist to activate a checkpoint."
		)
		return

	if checkpoint_active:
		print("GameManager: A checkpoint is already active.")
		return

	checkpoint_active = true
	checkpoint_scene_path = get_tree().current_scene.scene_file_path

	if is_instance_valid(respawn_point):
		var right_direction: Vector3 = (
			respawn_point.global_basis.x.normalized()
		)

		player1_checkpoint_position = (
			respawn_point.global_position - right_direction
		)

		player2_checkpoint_position = (
			respawn_point.global_position + right_direction
		)

	else:
		player1_checkpoint_position = player1.global_position
		player2_checkpoint_position = player2.global_position

	print("================================")
	print("CHECKPOINT ACTIVATED!")
	print("Checkpoint ID: ", active_checkpoint_id)
	print("Scene: ", checkpoint_scene_path)
	print("Player 1 respawn: ", player1_checkpoint_position)
	print("Player 2 respawn: ", player2_checkpoint_position)
	print("================================")


# ==================================================
# TEAM WIPE DETECTION
# ==================================================

func check_team_wipe() -> void:
	if team_wipe_triggered:
		return

	var player1: Node = get_tree().get_first_node_in_group("player1")
	var player2: Node = get_tree().get_first_node_in_group("player2")

	if not is_instance_valid(player1):
		return

	if not is_instance_valid(player2):
		return

	var player1_dead: bool = bool(player1.get("is_dead"))
	var player2_dead: bool = bool(player2.get("is_dead"))

	if player1_dead and player2_dead:
		show_game_over()


# ==================================================
# GAME OVER
# ==================================================

func show_game_over() -> void:
	if team_wipe_triggered:
		return

	team_wipe_triggered = true

	print("TEAM WIPE! Both players have been defeated.")

	if not is_instance_valid(GAME_OVER_SCENE):
		push_error("GameManager: Game Over scene could not be loaded.")
		get_tree().paused = false
		return

	game_over_screen = GAME_OVER_SCENE.instantiate() as GameOverScreen

	if not is_instance_valid(game_over_screen):
		push_error("GameManager: Game Over scene has no GameOverScreen script.")
		get_tree().paused = false
		return

	game_over_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	get_tree().root.add_child(game_over_screen)

	game_over_screen.show_screen(
		"DEFEATED",
		"Both heroes have fallen. The dungeon awaits."
	)

	get_tree().paused = true


# ==================================================
# CLEAR ALL GAME SESSION DATA
# ==================================================

func clear_game_session() -> void:
	print("GameManager: Clearing previous game session.")

	# Clear checkpoint progress.
	checkpoint_active = false
	checkpoint_scene_path = ""
	active_checkpoint_id = &""

	# Clear saved respawn positions.
	player1_checkpoint_position = Vector3.ZERO
	player2_checkpoint_position = Vector3.ZERO

	# Reset team-wipe state.
	team_wipe_triggered = false

	# Remove any existing Game Over interface.
	_remove_game_over_screen()

	# Make sure the game is not paused.
	get_tree().paused = false

	print("GameManager: Game session completely reset.")


# ==================================================
# START A BRAND-NEW GAME
# ==================================================

func start_new_game() -> void:
	print("GameManager: Starting a brand-new game.")

	clear_game_session()

	var error: Error = get_tree().change_scene_to_file(first_scene_path)

	if error != OK:
		push_error(
			"GameManager: Could not start a new game: "
			+ first_scene_path
		)


# ==================================================
# RESTART FROM BEGINNING
# ==================================================

func restart_from_beginning() -> void:
	print("GameManager: Restarting dungeon from the beginning.")

	start_new_game()


# ==================================================
# RESTART FROM CHECKPOINT
# ==================================================

func restart_from_checkpoint() -> void:
	if not checkpoint_active:
		restart_from_beginning()
		return

	print("GameManager: Returning both players to checkpoint.")
	print("Active checkpoint: ", active_checkpoint_id)

	get_tree().paused = false
	_remove_game_over_screen()

	var scene_to_load: String = checkpoint_scene_path

	var error: Error = get_tree().change_scene_to_file(scene_to_load)

	if error != OK:
		push_error(
			"GameManager: Could not reload checkpoint scene: "
			+ scene_to_load
		)
		return

	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame

	var player1: Node = get_tree().get_first_node_in_group("player1")
	var player2: Node = get_tree().get_first_node_in_group("player2")

	if not is_instance_valid(player1) or not is_instance_valid(player2):
		push_error(
			"GameManager: Could not find both players after checkpoint reload."
		)
		return

	if player1.has_method("revive"):
		player1.call("revive", player1_checkpoint_position)
	else:
		push_warning("GameManager: Player 1 does not have a revive method.")

	if player2.has_method("revive"):
		player2.call("revive", player2_checkpoint_position)
	else:
		push_warning("GameManager: Player 2 does not have a revive method.")

	team_wipe_triggered = false

	print("================================")
	print("BOTH PLAYERS RESPAWNED!")
	print("Checkpoint remains active: ", active_checkpoint_id)
	print("================================")


# ==================================================
# RETURN TO MAIN MENU
# ==================================================

func return_to_main_menu() -> void:
	print("GameManager: Returning to main menu.")

	# Returning to the menu ends the current game session.
	clear_game_session()

	var error: Error = get_tree().change_scene_to_file(main_menu_path)

	if error != OK:
		push_error(
			"GameManager: Could not load main menu: "
			+ main_menu_path
		)


# ==================================================
# CLEANUP
# ==================================================

func _remove_game_over_screen() -> void:
	if is_instance_valid(game_over_screen):
		game_over_screen.queue_free()

	game_over_screen = null

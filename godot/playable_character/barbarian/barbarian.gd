
extends Node3D

@export var dungeon_scene: PackedScene

var player_in_range: bool = false
var interaction_used: bool = false


func _ready() -> void:
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if interaction_used or not player_in_range:
		return

	# Either player can interact through PlayerInput.
	var mage_interact: bool = PlayerInput.consume_interaction(1)
	var knight_interact: bool = PlayerInput.consume_interaction(2)

	if mage_interact or knight_interact:
		interaction_used = true
		print("Dungeon Keeper interacted!")
		enter_dungeon()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player1") or body.is_in_group("player2"):
		player_in_range = true
		print("Press your interact key or use your controller to enter the dungeon.")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player1") or body.is_in_group("player2"):
		# Only stop interaction when neither player remains nearby.
		call_deferred("_update_player_range")


func _update_player_range() -> void:
	player_in_range = false

	for body in $InteractionArea.get_overlapping_bodies():
		if body.is_in_group("player1") or body.is_in_group("player2"):
			player_in_range = true
			break


func enter_dungeon() -> void:
	if dungeon_scene == null:
		interaction_used = false
		push_warning("No dungeon scene assigned!")
		return

	print("Entering Dungeon 1!")
	get_tree().change_scene_to_packed(dungeon_scene)

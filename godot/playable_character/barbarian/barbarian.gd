extends Node3D


@export var dungeon_scene: PackedScene


var player_in_range = false
var interaction_used = false


func _ready():

	$InteractionArea.body_entered.connect(
		_on_body_entered
	)

	$InteractionArea.body_exited.connect(
		_on_body_exited
	)


func _process(_delta):

	if interaction_used:
		return


	# ==========================================
	# INTERACTION
	# ==========================================

	var interact_requested = false


	# Keyboard E
	if Input.is_key_pressed(KEY_E):

		interact_requested = true


	# Mage controller
	if ArduinoMage.interact_pressed:

		interact_requested = true
		ArduinoMage.interact_pressed = false


	# Knight controller
	if ArduinoKnight.interact_pressed:

		interact_requested = true
		ArduinoKnight.interact_pressed = false


	# ==========================================
	# ONLY INTERACT IF PLAYER IS IN THE AREA
	# ==========================================

	if interact_requested and player_in_range:

		interaction_used = true

		print("Dungeon Keeper interacted!")

		enter_dungeon()


func _on_body_entered(body):

	if (
		body.is_in_group("player1")
		or body.is_in_group("player2")
	):

		player_in_range = true

		print(
			"Press E or use your controller to enter the dungeon"
		)


func _on_body_exited(body):

	if (
		body.is_in_group("player1")
		or body.is_in_group("player2")
	):

		player_in_range = false


func enter_dungeon():

	if dungeon_scene == null:

		print(
			"No dungeon scene assigned!"
		)

		return


	print(
		"Entering Dungeon 1!"
	)


	get_tree().change_scene_to_packed(
		dungeon_scene
	)


extends Area3D

var puzzle_controller: Node = null

var furnace_flames: Node3D = null
var furnace_light: Node3D = null

var fire_started: bool = false


func _ready() -> void:
	print("DEBUG: Fire Station ready.")

	# Find the room and its puzzle controller.
	var puzzle_room := get_parent().get_parent()

	puzzle_controller = puzzle_room.get_node_or_null(
		"PuzzleController"
	)

	# Find the imported furnace visuals.
	furnace_flames = puzzle_room.find_child(
		"Furnace_Flames", true, false
	) as Node3D

	furnace_light = puzzle_room.find_child(
		"Furnace_Light", true, false
	) as Node3D

	# The furnace starts cold.
	if furnace_flames != null:
		furnace_flames.visible = false
	else:
		push_warning("Could not find Furnace_Flames.")

	if furnace_light != null:
		furnace_light.visible = false
	else:
		push_warning("Could not find Furnace_Light.")

	if puzzle_controller == null:
		push_warning("Could not find PuzzleController.")
	else:
		print("DEBUG: PuzzleController found.")


func ignite_from_spell(spell_name: String) -> void:
	# Only Fireball can ignite the furnace.
	if spell_name != "Fireball":
		print("DEBUG: Wrong spell for Fire Station: ", spell_name)
		return

	# Do not ignite repeatedly.
	if fire_started:
		print("DEBUG: Furnace is already lit.")
		return

	if puzzle_controller == null:
		push_warning("Cannot ignite furnace: PuzzleController missing.")
		return

	fire_started = true

	if furnace_flames != null:
		furnace_flames.visible = true

	if furnace_light != null:
		furnace_light.visible = true

	puzzle_controller.set_station_in_progress("fire")

	print("The Mage's Fireball ignites the furnace!")

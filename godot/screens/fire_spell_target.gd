
extends Area3D

@export var fire_station_path: NodePath = ^"../FireInteraction"

var fire_station: Node = null


func _ready() -> void:
	add_to_group("fire_targets")

	fire_station = get_node_or_null(fire_station_path)

	if fire_station == null:
		push_warning(
			"FireSpellTarget could not find FireInteraction. "
			+ "Check fire_station_path."
		)
	else:
		print("DEBUG: Fire spell target ready.")


func receive_spell(spell_name: String) -> void:
	print("DEBUG: Fire target received spell: ", spell_name)

	if fire_station == null:
		push_warning("Fire target has no Fire Station script.")
		return

	if fire_station.has_method("ignite_from_spell"):
		fire_station.ignite_from_spell(spell_name)
	else:
		push_warning(
			"FireInteraction does not have ignite_from_spell()."
		)

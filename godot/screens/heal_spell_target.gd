extends Area3D
## Mirrors fire_spell_target.gd: an Area3D the Mage's spells can aim at / hit.
## It simply forwards the spell to the HealStation.
## Registered in both "heal_targets" and "healing_targets" so it is found whichever
## naming your Mage targeting code uses.

@export var heal_station_path: NodePath = ^"../HealStation"

var heal_station: Node = null


func _ready() -> void:
	add_to_group("heal_targets")
	add_to_group("healing_targets")

	heal_station = get_node_or_null(heal_station_path)

	if heal_station == null:
		push_warning(
			"HealSpellTarget could not find HealStation. "
			+ "Check heal_station_path."
		)
	else:
		print("DEBUG: Heal spell target ready.")


func receive_spell(spell_name: String) -> void:
	print("DEBUG: Heal target received spell: ", spell_name)

	if heal_station == null:
		push_warning("Heal target has no Heal Station script.")
		return

	if heal_station.has_method("receive_spell"):
		heal_station.receive_spell(spell_name)
	else:
		push_warning("HealStation does not have receive_spell().")

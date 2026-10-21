
extends Area3D

var puzzle_controller: Node = null

var water_surface: Node3D = null
var ice_surface: Node3D = null
var frozen_formations: Node3D = null
var ice_crystal: Node3D = null
var small_crystal_1: Node3D = null
var small_crystal_2: Node3D = null
var small_crystal_3: Node3D = null
var crystal_light: Node3D = null
var lever_indicator: MeshInstance3D = null

var water_started: bool = false
var channel_frozen: bool = false
var lever_enabled: bool = false
var shrine_completed: bool = false

const INDICATOR_DIM_COLOR := Color(0.02, 0.12, 0.5)
const INDICATOR_BRIGHT_COLOR := Color(0.0, 0.45, 1.0)

const INDICATOR_DIM_ENERGY := 0.35
const INDICATOR_BRIGHT_ENERGY := 3.0


func _ready() -> void:
	print("DEBUG: Ice Shrine ready.")

	monitoring = true

	for layer in range(1, 33):
		set_collision_mask_value(layer, true)

	var parent_node := get_parent()
	var puzzle_room: Node = null

	if parent_node != null:
		puzzle_room = parent_node.get_parent()

	if puzzle_room == null:
		push_error("Ice Shrine: Could not find puzzle room.")
		return

	puzzle_controller = puzzle_room.get_node_or_null("PuzzleController")

	water_surface = puzzle_room.find_child(
		"Water_Surface", true, false
	) as Node3D

	ice_surface = puzzle_room.find_child(
		"Ice_Surface", true, false
	) as Node3D

	frozen_formations = puzzle_room.find_child(
		"Ice_Formations_Frozen", true, false
	) as Node3D

	ice_crystal = puzzle_room.find_child(
		"Ice_Crystal", true, false
	) as Node3D

	small_crystal_1 = puzzle_room.find_child(
		"Ice_Crystal_Small_1", true, false
	) as Node3D

	small_crystal_2 = puzzle_room.find_child(
		"Ice_Crystal_Small_2", true, false
	) as Node3D

	small_crystal_3 = puzzle_room.find_child(
		"Ice_Crystal_Small_3", true, false
	) as Node3D

	crystal_light = puzzle_room.find_child(
		"Ice_Crystal_Light", true, false
	) as Node3D

	lever_indicator = puzzle_room.find_child(
		"Ice_Lever_Indicator", true, false
	) as MeshInstance3D

	set_visual_visible(water_surface, false)
	set_visual_visible(ice_surface, false)
	set_visual_visible(frozen_formations, false)
	set_visual_visible(ice_crystal, false)
	set_visual_visible(small_crystal_1, false)
	set_visual_visible(small_crystal_2, false)
	set_visual_visible(small_crystal_3, false)
	set_visual_visible(crystal_light, false)

	if is_instance_valid(lever_indicator):
		lever_indicator.visible = true
		set_indicator_glow(false)

	if puzzle_controller == null:
		push_error("Ice Shrine: PuzzleController not found.")
	else:
		print("DEBUG: PuzzleController found.")

	check_missing_visuals()

	print("DEBUG: Ice Shrine setup complete.")


# ==========================================
# VISUAL HELPERS
# ==========================================

func set_visual_visible(
	visual: Node3D,
	should_be_visible: bool
) -> void:
	if is_instance_valid(visual):
		visual.visible = should_be_visible


func set_indicator_glow(is_bright: bool) -> void:
	if not is_instance_valid(lever_indicator):
		return

	lever_indicator.visible = true

	var target_color: Color
	var target_energy: float

	if is_bright:
		target_color = INDICATOR_BRIGHT_COLOR
		target_energy = INDICATOR_BRIGHT_ENERGY
	else:
		target_color = INDICATOR_DIM_COLOR
		target_energy = INDICATOR_DIM_ENERGY

	var surface_count := 0

	if lever_indicator.mesh != null:
		surface_count = lever_indicator.mesh.get_surface_count()

	var updated_material := false

	for surface_index in range(surface_count):
		var original_material: Material = (
			lever_indicator.get_active_material(surface_index)
		)

		if original_material is StandardMaterial3D:
			var new_material := (
				original_material.duplicate() as StandardMaterial3D
			)

			new_material.emission_enabled = true
			new_material.emission = target_color
			new_material.emission_energy_multiplier = target_energy

			lever_indicator.set_surface_override_material(
				surface_index,
				new_material
			)

			updated_material = true

	if lever_indicator.material_override is StandardMaterial3D:
		var original_override := (
			lever_indicator.material_override as StandardMaterial3D
		)

		var new_override := (
			original_override.duplicate() as StandardMaterial3D
		)

		new_override.emission_enabled = true
		new_override.emission = target_color
		new_override.emission_energy_multiplier = target_energy

		lever_indicator.material_override = new_override
		updated_material = true

	if not updated_material:
		push_warning(
			"Ice Shrine: Indicator has no StandardMaterial3D material. "
			+ "Check its material settings."
		)


func check_missing_visuals() -> void:
	var missing_count := 0

	if water_surface == null:
		push_warning("Ice Shrine: Water_Surface not found.")
		missing_count += 1

	if ice_surface == null:
		push_warning("Ice Shrine: Ice_Surface not found.")
		missing_count += 1

	if frozen_formations == null:
		push_warning("Ice Shrine: Ice_Formations_Frozen not found.")
		missing_count += 1

	if ice_crystal == null:
		push_warning("Ice Shrine: Ice_Crystal not found.")
		missing_count += 1

	if small_crystal_1 == null:
		push_warning("Ice Shrine: Ice_Crystal_Small_1 not found.")
		missing_count += 1

	if small_crystal_2 == null:
		push_warning("Ice Shrine: Ice_Crystal_Small_2 not found.")
		missing_count += 1

	if small_crystal_3 == null:
		push_warning("Ice Shrine: Ice_Crystal_Small_3 not found.")
		missing_count += 1

	if crystal_light == null:
		push_warning("Ice Shrine: Ice_Crystal_Light not found.")
		missing_count += 1

	if lever_indicator == null:
		push_warning("Ice Shrine: Ice_Lever_Indicator not found.")
		missing_count += 1

	if missing_count == 0:
		print("DEBUG: All Ice Shrine visuals found.")
	else:
		print(
			"DEBUG: Missing ",
			missing_count,
			" Ice Shrine visual node(s)."
		)


# ==========================================
# MAGE ICE SPELL
# ==========================================

func receive_spell(spell_name: String) -> void:
	print("DEBUG: Ice Shrine received spell: ", spell_name)

	if spell_name.to_lower() != "ice":
		print("DEBUG: The shrine requires Ice, not ", spell_name)
		return

	freeze_channel()


# ==========================================
# STAGE 1: START WATER
# ==========================================

func start_water() -> void:
	print("DEBUG: Knight interacted with the water inlet.")

	if shrine_completed:
		print("DEBUG: Ice Shrine is already complete.")
		return

	if water_started:
		print("DEBUG: Water is already flowing.")
		return

	if water_surface == null:
		push_error(
			"Ice Shrine: Cannot start water; Water_Surface is missing."
		)
		return

	water_started = true
	set_visual_visible(water_surface, true)

	print("The Knight starts the water flowing!")
	print("The Mage can now use the Ice spell on the channel.")


# ==========================================
# STAGE 2: FREEZE CHANNEL
# ==========================================

func freeze_channel() -> void:
	print("DEBUG: Attempting to freeze the Ice Shrine channel.")

	if shrine_completed:
		print("DEBUG: Ice Shrine is already complete.")
		return

	if channel_frozen:
		print("DEBUG: Channel is already frozen.")
		return

	if not water_started:
		print("DEBUG: The water must be flowing before it can freeze!")
		return

	channel_frozen = true
	lever_enabled = true

	set_visual_visible(water_surface, false)
	set_visual_visible(ice_surface, true)
	set_visual_visible(frozen_formations, true)
	set_visual_visible(ice_crystal, true)
	set_visual_visible(small_crystal_1, true)
	set_visual_visible(small_crystal_2, true)
	set_visual_visible(small_crystal_3, true)
	set_visual_visible(crystal_light, true)

	set_indicator_glow(true)

	if puzzle_controller != null:
		if puzzle_controller.has_method("set_station_in_progress"):
			puzzle_controller.set_station_in_progress("ice")
		else:
			push_warning(
				"PuzzleController is missing set_station_in_progress()."
			)

	print("The Mage freezes the channel!")
	print("The Ice Shrine lever is now enabled.")


# ==========================================
# STAGE 3: PULL LEVER
# ==========================================

func pull_lever() -> void:
	print("DEBUG: Knight interacted with the Ice Shrine lever.")

	if shrine_completed:
		print("DEBUG: Ice Shrine is already complete.")
		return

	if not water_started:
		print("The Knight must start the water first!")
		return

	if not channel_frozen:
		print("The Mage must freeze the water before the lever can work!")
		return

	if not lever_enabled:
		print("The ice lever is still locked!")
		return

	if puzzle_controller == null:
		push_error("Cannot complete Ice Shrine: PuzzleController missing.")
		return

	if not puzzle_controller.has_method("complete_station"):
		push_error("PuzzleController is missing complete_station().")
		return

	# Complete the station first so the room receives its signal.
	puzzle_controller.complete_station("ice")

	shrine_completed = true
	lever_enabled = false

	set_indicator_glow(false)

	print("The Knight activates the Ice Shrine!")
	print("DEBUG: Ice Shrine puzzle completed successfully.")

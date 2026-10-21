
extends Node3D

@export var puzzle_controller_path: NodePath

var puzzle_controller: Node


func _ready() -> void:
	print("Ancient Seal Puzzle Room ready.")

	# Find the PuzzleController.
	if puzzle_controller_path != NodePath(""):
		puzzle_controller = get_node_or_null(puzzle_controller_path)

	if puzzle_controller == null:
		var scene_root := get_tree().current_scene
		if scene_root != null:
			puzzle_controller = scene_root.find_child(
				"PuzzleController",
				true,
				false
			)

	if puzzle_controller == null:
		push_warning("Ancient Seal: PuzzleController was not found.")
		return

	print("Ancient Seal found controller: ", puzzle_controller.get_path())

	# Verify the controller exposes the required signals.
	var required_signals := [
		"station_completed",
		"seal_completed",
		"gate_unlocked"
	]

	for signal_name in required_signals:
		if not puzzle_controller.has_signal(signal_name):
			push_error(
				"Ancient Seal: PuzzleController is missing signal: "
				+ signal_name
				+ ". Check the script attached to PuzzleController."
			)
			return

	# Connect signals safely.
	if not puzzle_controller.is_connected(
		"station_completed",
		_on_station_completed
	):
		puzzle_controller.connect(
			"station_completed",
			_on_station_completed
		)

	if not puzzle_controller.is_connected(
		"seal_completed",
		_on_seal_completed
	):
		puzzle_controller.connect(
			"seal_completed",
			_on_seal_completed
		)

	if not puzzle_controller.is_connected(
		"gate_unlocked",
		_on_gate_unlocked
	):
		puzzle_controller.connect(
			"gate_unlocked",
			_on_gate_unlocked
		)

	# Restore visuals for completed puzzles.
	if puzzle_controller.has_method("is_station_complete"):
		if puzzle_controller.is_station_complete("fire"):
			_on_station_completed("fire")

		if puzzle_controller.is_station_complete("ice"):
			_on_station_completed("ice")

		if puzzle_controller.is_station_complete("heal"):
			_on_station_completed("heal")

	if _controller_bool("seal_is_complete"):
		_on_seal_completed()

	if _controller_bool("gate_is_unlocked"):
		_on_gate_unlocked()


func _controller_bool(property_name: String) -> bool:
	for property_info in puzzle_controller.get_property_list():
		if property_info.name == property_name:
			return bool(puzzle_controller.get(property_name))

	return false


# ==========================================
# STATION COMPLETION
# ==========================================

func _on_station_completed(station_name: String) -> void:
	match station_name:
		"fire":
			print("Fire puzzle completed!")

			_activate_visual("Gate_Lock_Fire", Color.RED)
			_activate_visual("Seal_Symbol_Fire", Color.RED)
			_activate_visual("Gate_Symbol_Fire", Color.RED)
			_activate_visual("Conduit_Fire", Color.RED)

			_release_fire_lock()

		"ice":
			print("Ice puzzle completed!")

			_activate_visual("Seal_Symbol_Ice", Color.DEEP_SKY_BLUE)
			_activate_visual("Gate_Symbol_Ice", Color.DEEP_SKY_BLUE)
			_activate_visual("Conduit_Ice", Color.DEEP_SKY_BLUE)
			_activate_visual("Gate_Lock_Ice", Color.DEEP_SKY_BLUE)

			_release_ice_lock()

		"heal":
			print("Healing puzzle completed!")

			_activate_visual("Seal_Symbol_Heal", Color.LIME_GREEN)
			_activate_visual("Gate_Symbol_Heal", Color.LIME_GREEN)

		_:
			push_warning("Unknown completed station: " + station_name)


# ==========================================
# FIRE LOCK MOVEMENT
# ==========================================

func _release_fire_lock() -> void:
	var fire_lock := _find_visual("Gate_Lock_Fire")

	if fire_lock == null:
		return

	if not fire_lock is Node3D:
		push_warning("Gate_Lock_Fire must be a Node3D.")
		return

	if fire_lock.has_meta("fire_lock_released"):
		return

	fire_lock.set_meta("fire_lock_released", true)

	print("The Fire latch is sliding left!")

	var target_position: Vector3 = fire_lock.position + Vector3(-1.0, 0.0, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fire_lock, "position", target_position, 1.2)


# ==========================================
# ICE LOCK MOVEMENT
# ==========================================

func _release_ice_lock() -> void:
	var ice_lock := _find_visual("Gate_Lock_Ice")

	if ice_lock == null:
		return

	if not ice_lock is Node3D:
		push_warning("Gate_Lock_Ice must be a Node3D.")
		return

	if ice_lock.has_meta("ice_lock_released"):
		return

	ice_lock.set_meta("ice_lock_released", true)

	print("The Ice latch is sliding left!")

	var target_position: Vector3 = ice_lock.position + Vector3(-1.0, 0.0, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ice_lock, "position", target_position, 1.2)


# ==========================================
# SEAL AND GATE
# ==========================================

func _on_seal_completed() -> void:
	print("The Threefold Seal is activated!")

	_activate_visual("Seal_Core", Color.CYAN)
	_activate_visual("Seal_Light", Color.CYAN)
	_activate_visual("Seal_Ring_Outer", Color.CYAN)
	_activate_visual("Seal_Ring_Middle", Color.CYAN)
	_activate_visual("Seal_Ring_Inner", Color.CYAN)


func _on_gate_unlocked() -> void:
	print("The Ancient Gate is unlocked!")

	_activate_visual("Gate_Glow", Color.CYAN)
	_activate_visual("Gate_Glow_Light", Color.CYAN)


# ==========================================
# FIND VISUALS
# ==========================================

func _find_visual(target_name: String) -> Node:
	var found_node := find_child(target_name, true, false)

	if found_node != null:
		return found_node

	var scene_root := get_tree().current_scene

	if scene_root != null:
		found_node = scene_root.find_child(target_name, true, false)

		if found_node != null:
			return found_node

	push_warning("Could not find visual: " + target_name)
	return null


# ==========================================
# GLOW VISUALS
# ==========================================

func _activate_visual(target_name: String, glow_color: Color) -> void:
	var target := _find_visual(target_name)

	if target == null:
		return

	_activate_node_and_children(target, glow_color)


func _activate_node_and_children(node: Node, glow_color: Color) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = true

	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var surface_count := 0

		if mesh_instance.mesh != null:
			surface_count = mesh_instance.mesh.get_surface_count()

		for surface_index in range(surface_count):
			var active_material := mesh_instance.get_active_material(surface_index)

			if active_material is StandardMaterial3D:
				var glowing_material := active_material.duplicate() as StandardMaterial3D
				glowing_material.emission_enabled = true
				glowing_material.emission = glow_color
				glowing_material.emission_energy_multiplier = 2.0

				mesh_instance.set_surface_override_material(
					surface_index,
					glowing_material
				)

		if mesh_instance.material_override is StandardMaterial3D:
			var glowing_override := (
				mesh_instance.material_override.duplicate()
				as StandardMaterial3D
			)

			glowing_override.emission_enabled = true
			glowing_override.emission = glow_color
			glowing_override.emission_energy_multiplier = 2.0
			mesh_instance.material_override = glowing_override

	if node is Light3D:
		var light := node as Light3D
		light.light_color = glow_color
		light.light_energy = 2.0

	for child in node.get_children():
		_activate_node_and_children(child, glow_color)

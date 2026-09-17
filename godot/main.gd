extends Node3D

@onready var player1_camera = $Player1/CameraPivot/Camera3D
@onready var player2_camera = $Player2/CameraPivot/Camera3D

@onready var player1_viewport = $SplitScreen/VBoxContainer/Player1Viewport/SubViewport
@onready var player2_viewport = $SplitScreen/VBoxContainer/Player2Viewport/SubViewport

@onready var player1_split_camera = $SplitScreen/VBoxContainer/Player1Viewport/SubViewport/Player1SplitCamera
@onready var player2_split_camera = $SplitScreen/VBoxContainer/Player2Viewport/SubViewport/Player2SplitCamera


func _ready():
	player1_camera.current = false
	player2_camera.current = false

	player1_viewport.world_3d = get_viewport().world_3d
	player2_viewport.world_3d = get_viewport().world_3d

	player1_split_camera.current = true
	player2_split_camera.current = true

func _process(_delta):
	player1_split_camera.global_transform = player1_camera.global_transform
	player2_split_camera.global_transform = player2_camera.global_transform

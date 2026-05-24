extends Control

const VERSION := "v0.0.1-alpha"

func _ready():
	get_tree().paused = false
	$VBox/ButtonBox/PlayButton.pressed.connect(_on_play)
	$VBox/ButtonBox/SimulatorButton.pressed.connect(_on_simulator)
	$VBox/ButtonBox/SettingsButton.pressed.connect(_on_settings)
	$VBox/ButtonBox/QuitButton.pressed.connect(_on_quit)
	$VersionLabel.text = VERSION

func _on_play():
	get_tree().change_scene_to_file("res://levels/GameModeScene.tscn")

func _on_simulator():
	get_tree().change_scene_to_file("res://levels/Arena.tscn")

func _on_settings():
	get_tree().change_scene_to_file("res://levels/SettingsScene.tscn")

func _on_quit():
	get_tree().quit()

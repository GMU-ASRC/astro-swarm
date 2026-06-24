extends Control

func _ready():
	$VBox/ButtonBox/SpaceMinnowsButton.pressed.connect(_on_space_minnows)
	$VBox/ButtonBox/ChallengesButton.pressed.connect(_on_challenges)
	$VBox/ButtonBox/BackButton.pressed.connect(_on_back)

func _on_space_minnows():
	print("Space Minnows mode selected")

func _on_challenges():
	print("Challenges mode selected")

func _on_back():
	get_tree().change_scene_to_file("res://levels/menus/HomeScene.tscn")

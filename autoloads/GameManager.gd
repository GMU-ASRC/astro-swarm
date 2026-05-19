extends Node

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS

func load_arena():
    get_tree().change_scene_to_file("res://levels/Arena.tscn")

func load_workspace():
    get_tree().change_scene_to_file("res://ui/workspace/Workspace.tscn")

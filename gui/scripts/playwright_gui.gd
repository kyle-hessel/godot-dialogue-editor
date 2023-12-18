@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")

@onready var playwright_graph: GraphEdit = $PlaywrightGraph
@onready var add_dialogue_button: Button = $AddDialogueButton

func _enter_tree():
	pass

func _on_add_dialogue_button_pressed():
	playwright_graph.add_child(PlaywrightDialogue.instantiate())

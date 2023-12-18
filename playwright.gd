@tool
extends EditorPlugin

const PlaywrightGUI: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_gui.tscn")

var playwright_gui_inst: Control

func _enter_tree():
	playwright_gui_inst = PlaywrightGUI.instantiate()
	# Add Playwright's GUI to the editor's main viewport.
	EditorInterface.get_editor_main_screen().add_child(playwright_gui_inst)
	# Hide the main panel by default.
	_make_visible(false)


func _exit_tree():
	if playwright_gui_inst:
		playwright_gui_inst.queue_free()

func _has_main_screen():
	return true

func _make_visible(visible: bool):
	if playwright_gui_inst:
		playwright_gui_inst.visible = visible

func _get_plugin_name():
	return "Playwright"

func _get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")

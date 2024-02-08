@tool
extends GraphNode

class_name PlaywrightAction

signal delete_node(node: PlaywrightAction)

@onready var action_name: LineEdit = $ActionNameLineEdit

func _ready():
	resizable = true

func _unhandled_input(event: InputEvent):
	if selected:
		if event is InputEventKey and event.is_pressed():
			#print(OS.get_keycode_string(event.keycode))
			if OS.get_keycode_string(event.keycode) == "Escape":
				delete_node.emit(self)

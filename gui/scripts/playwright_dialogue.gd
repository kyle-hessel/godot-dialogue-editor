@tool
extends GraphNode

@onready var dialogue_vbox: VBoxContainer = $DialogueVBox
@onready var speaker_line_edit: LineEdit = $DialogueVBox/SpeakerLineEdit
@onready var dialogue_type_button: OptionButton = $DialogueVBox/DialogueTypeOptionButton
@onready var add_line_button: Button = $DialogueVBox/AddLineButton
@onready var dialogue_text_edit: TextEdit = $DialogueTextEdit

func _ready():
	pass

func _on_dialogue_type_option_button_item_selected(index: int):
	match index:
		0:
			add_line_button.text = "Add Line"
		1: 
			add_line_button.text = "Add Response"
		_:
			add_line_button.text = "Add Other"

func _on_add_line_button_pressed():
	var new_dialogue_text: TextEdit = dialogue_text_edit.duplicate()
	new_dialogue_text.text = ""
	add_child(new_dialogue_text)

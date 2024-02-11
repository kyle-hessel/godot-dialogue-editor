@tool
# This Control needs Vertical Container Sizing set to Expand. See: https://github.com/godotengine/godot/issues/34497
extends Control

#region CONSTANTS
const PlaywrightDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_dialogue.tscn")
const PlaywrightActionAnimation: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_action_animation.tscn")
const PlaywrightActionCallable: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_action_callable.tscn")
const PlaywrightActionCamSwitch: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_action_cam_switch.tscn")
const PlaywrightActionDialogue: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_action_dialogue.tscn")
const PlaywrightActionTimer: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_action_timer.tscn")
const PlaywrightParallelActionContainer: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_parallel_action_container.tscn")
const PlaywrightSubActionContainer: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_sub_action_container.tscn")
const PlaywrightActionArray: PackedScene = preload("res://addons/playwright/gui/scenes/playwright_action_array.tscn")
const DLG_OFFSET_INCREMENT_X: float = 300.0
const DLG_OFFSET_INCREMENT_Y: float = 500.0
const DLG_TYPE_DEFAULT: int = 0
const DLG_TYPE_RESPONSE: int = 1
const DLG_TYPE_CALL: int = 2
const DLG_TYPE_MESSAGE: int = 3
const DLG_TYPE_SHOUT: int = 4
#endregion

var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
var res_prev: EditorResourcePreview = EditorInterface.get_resource_previewer()

@onready var playwright_graph: GraphEdit = $PlaywrightGraph # dialogue editor
@onready var playwright_graph2: GraphEdit = $PlaywrightGraph2 # cutscene editor

@onready var mode_switch_button: CheckButton = $ModeSwitchButton

@onready var dialogue_name_line_edit: LineEdit = $DialogueNameLineEdit
@onready var add_dialogue_button: Button = $AddDialogueButton
@onready var import_dialogue_button: Button = $ImportDialogueButton
@onready var serialize_dialogue_button: Button = $SerializeDialogueButton

@onready var event_name_line_edit: LineEdit = $EventNameLineEdit
@onready var action_option_button: OptionButton = $ActionOptionButton
@onready var add_action_button: Button = $AddActionButton
@onready var import_event_button: Button = $ImportEventButton
@onready var serialize_event_button: Button = $SerializeEventButton

@onready var export_dlg_file_dialog: FileDialog = $ExportDlgFileDialog
@onready var import_dlg_file_dialog: FileDialog = $ImportDlgFileDialog
@onready var export_event_file_dialog: FileDialog = $ExportEventFileDialog
@onready var import_event_file_dialog: FileDialog = $ImportEventFileDialog

signal file_operation_complete

var dialogue_edit_controls: Array
var cutscene_edit_controls: Array

var action_nodes: Array[GraphNode]
var generated_actions: Array[Action]

var dialogue_nodes: Array[GraphNode]
var generated_dialogues: Array[Dialogue]
var selected_files: Array

var dlg_offset_x: float = 0
var dlg_offset_y: float = 0
var dlg_name_increment: int = 0

func _enter_tree():
	pass
	#res_prev.preview_invalidated.connect(func(preview_path: String): print("Resource: " + preview_path + " invalidated."))

# use the ready signal of the parent node, as children may instantiate first but not yet have a parent.
func _on_ready():
	playwright_graph.snapping_enabled = false
	playwright_graph.show_grid = false
	
	# handle ImportDlgFileDialog if one file is selected.
	import_dlg_file_dialog.file_selected.connect(
		func(file_path: String):
			selected_files.clear()
			selected_files.append(file_path)
			import_dialogue_files(selected_files)
	)
	# handle ImportDlgFileDialog if multiple files are selected.
	import_dlg_file_dialog.files_selected.connect(
		func(file_paths: PackedStringArray):
			selected_files.clear()
			selected_files = Array(file_paths)
			import_dialogue_files(selected_files)
	)
	
	dialogue_edit_controls.append(playwright_graph)
	dialogue_edit_controls.append(dialogue_name_line_edit)
	dialogue_edit_controls.append(add_dialogue_button)
	dialogue_edit_controls.append(import_dialogue_button)
	dialogue_edit_controls.append(serialize_dialogue_button)
	
	cutscene_edit_controls.append(playwright_graph2)
	cutscene_edit_controls.append(event_name_line_edit)
	cutscene_edit_controls.append(action_option_button)
	cutscene_edit_controls.append(add_action_button)
	cutscene_edit_controls.append(import_event_button)
	cutscene_edit_controls.append(serialize_event_button)

func _on_mode_switch_button_toggled(toggled_on: bool):
	for d in dialogue_edit_controls:
		d.visible = !d.visible
	for c in cutscene_edit_controls:
		c.visible = !c.visible

func _on_add_action_button_pressed():
	instantiate_action_node(action_option_button.get_selected_id())

func instantiate_action_node(option_idx: int) -> GraphNode:
	var playwright_action_inst: PlaywrightAction
	match option_idx:
		0:
			playwright_action_inst = PlaywrightActionAnimation.instantiate()
		1:
			playwright_action_inst = PlaywrightActionCamSwitch.instantiate()
		2:
			playwright_action_inst = PlaywrightActionCallable.instantiate()
		3:
			playwright_action_inst = PlaywrightActionDialogue.instantiate()
		4:
			playwright_action_inst = PlaywrightActionTimer.instantiate()
		5:
			playwright_action_inst = PlaywrightSubActionContainer.instantiate()
		6:
			playwright_action_inst = PlaywrightParallelActionContainer.instantiate()
		7:
			playwright_action_inst = PlaywrightActionArray.instantiate()
	
	playwright_graph2.add_child(playwright_action_inst)
	action_nodes.append(playwright_action_inst)
	playwright_action_inst.delete_node.connect(_on_delete_action_node)
	
	return playwright_action_inst

func _on_serialize_event_button_pressed():
	var action_connection_list: Array[Dictionary] = playwright_graph2.get_connection_list()
	
	# if there is an action list, sort action nodes and then serialize them.
	if action_connection_list.size() > 0:
		print("Action chain present: sorting action nodes and serializing them.")
		var event_res: Event = Event.new()
		event_res.event_name = event_name_line_edit.text
		event_res.resource_name = event_name_line_edit.text
		var sorted_action_node_names: Array[String] = sort_action_nodes(action_connection_list)
		
		# use action node name data to fetch the nodes themselves and transcribe them into an array of action resources.
		var action_res_array: Array[Action]
		#var last_node_name: String = ""
		#var next_node: GraphNode
		
		var action_line_connections: Array[Dictionary] = filter_line_connections_action(action_connection_list)
		for node_name_pos: int in sorted_action_node_names.size():
			var node_path_str: String = "PlaywrightGraph2/" + sorted_action_node_names[node_name_pos]
			var action_node: GraphNode = get_node(NodePath(node_path_str))
			#if node_name_pos + 1 < sorted_action_node_names.size():
				#next_node = get_node(NodePath("PlaywrightGraph2/" + sorted_action_node_names[node_name_pos + 1]))
			#else: 
				#next_node = null
			var action: Action = transcribe_action_node_to_resource(action_node, action_line_connections)
			action_res_array.append(action)
			#last_node_name = action_node.name
		
		event_res.actions = action_res_array
		
		# save the event resource to disk.
		save_event_res_to_disk(event_res, event_name_line_edit.text)
		await file_operation_complete
		
	else:
		print("No action chain found, aborting event serialization.")

# NOTE: this is a helper function for _on_serialize_event_button_pressed just above.
# a function that interprets all existing graph node and connection data to extrapolate a sorted array of action node names.
func sort_action_nodes(connection_list: Array[Dictionary]) -> Array[String]:
	var sorted_action_node_names: Array[String]
	
	# filter for Action connections only (slot 0).
	var action_node_connections: Array[Dictionary]
	for connection: Dictionary in connection_list:
		if connection["from_port"] == 0 && connection["to_port"] == 0:
			action_node_connections.append(connection)
	
	# convert dictionary data into two separate arrays.
	var from_nodes: Array[String]
	var to_nodes: Array[String]
	for action_connection: Dictionary in action_node_connections:
		from_nodes.append(action_connection["from_node"])
		to_nodes.append(action_connection["to_node"])
	
	# determine the starting action node by finding the one that doesn't act as a to_node anywhere.
	var starting_node_name: String
	for from_node_name: String in from_nodes:
		var match_found: bool = false
		for to_node_name: String in to_nodes:
			if from_node_name == to_node_name:
				match_found = true
		if !match_found:
			starting_node_name = from_node_name
			break
	
	# use the determined starting node as a jumping off point, and sort the rest of the action nodes by pouring over their connection keys until everything is accounted for.
	var initial_action_name_array: Array[String]
	initial_action_name_array.append(starting_node_name)
	var node_temp: String = initial_action_name_array[0]
	
	return traverse_node_connection_array(action_node_connections, initial_action_name_array, node_temp)

func transcribe_action_node_to_resource(action_node: GraphNode, action_line_connections: Array[Dictionary] = []) -> Action:
	var action_res: Action = Action.new()
	action_res.resource_name = action_node.action_name.text
	
	# a bit of a weird setup, but this function transcribes any individual action data, and if the action is not of that type, it just returns the resource unmodified before proceeding.
	action_res = transcribe_individual_action(action_node, action_res)
	
	if action_node is PlaywrightActionArray:
		var action_data_array: Array
		var array_type: int = action_node.array_option_button.selected
		for action_pos: int in action_node.array_items.size():
			for connection: Dictionary in action_line_connections:
				if playwright_graph2.is_node_connected(StringName(connection["from_node"]), 0, StringName(action_node.name), action_pos + 1):
					var node_path_str: String = "PlaywrightGraph2/" + connection["from_node"]
					var array_action_data: GraphNode = get_node(NodePath(node_path_str))
					match array_type:
						0: # DIALOGUE
							if array_action_data is PlaywrightActionDialogue:
								action_data_array.append(load(array_action_data.dlg_res_path.text))
						# other types here, down the line (if necessary)
						_:
							pass
		
		action_res.action[action_data_array] = null
		
	elif action_node is PlaywrightParallelActionContainer:
		for action_pos: int in action_node.parallel_actions.size():
			for connection: Dictionary in action_line_connections:
				if playwright_graph2.is_node_connected(StringName(connection["from_node"]), 0, StringName(action_node.name), action_pos + 1):
					var node_path_str: String = "PlaywrightGraph2/" + connection["from_node"]
					var parallel_action_node: GraphNode = get_node(NodePath(node_path_str))
					
					action_res = transcribe_individual_action(parallel_action_node, action_res)
		
	elif action_node is PlaywrightSubActionContainer:
		var sub_action_array: Array[Action]
		
		for action_pos: int in action_node.sub_actions.size():
			var sub_action_res: Action = Action.new()
			for connection: Dictionary in action_line_connections:
				# check for main action
				if playwright_graph2.is_node_connected(StringName(connection["from_node"]), 0, StringName(action_node.name), 1):
					var node_path_str: String = "PlaywrightGraph2/" + connection["from_node"]
					var main_action_node: GraphNode = get_node(NodePath(node_path_str))
					
					action_res = transcribe_individual_action(main_action_node, action_res)
				
				# check for sub-actions
				if playwright_graph2.is_node_connected(StringName(connection["from_node"]), 0, StringName(action_node.name), action_pos + 2):
					var node_path_str: String = "PlaywrightGraph2/" + connection["from_node"]
					var child_action_node: GraphNode = get_node(NodePath(node_path_str))
					
					sub_action_res = transcribe_individual_action(child_action_node, sub_action_res)
			
			sub_action_array.append(sub_action_res)
		
		var action_keys: Array = action_res.action.keys()
		action_res.action[action_keys[0]] = sub_action_array
	
	return action_res

# NOTE: helper function for the above function that processes single actions (anything that isn't a parallel action, sub-action, or array action)
func transcribe_individual_action(action_node: GraphNode, action_res: Action) -> Action:
	#region transcription callables
	
	var anim_action_transcribe: Callable = func(action_node: GraphNode):
		var anim_track_data: Array
		var anim_data: Array
		
		anim_track_data.append(action_node.property_name.text)
		anim_track_data.append(action_node.anim_track.text.to_int())
		
		anim_data.append(action_node.node_name.text)
		anim_data.append(anim_track_data)
		anim_data.append(action_node.node_local_anim.text)
		
		action_res.action[load(action_node.anim_path.text)] = anim_data
	
	var cam_switch_action_transcribe: Callable = func(action_node: GraphNode):
		action_res.action[NodePath(action_node.camera_name.text)] = null
	
	var timer_action_transcribe: Callable = func(action_node: GraphNode):
		action_res.action[NodePath(action_node.timer_name.text)] = action_node.timer_duration.text.to_int()
	
	var callable_action_transcribe: Callable = func(action_node: GraphNode):
		action_res.action[NodePath(action_node.relative_node_path.text)] = action_node.callable_name.text
	
	var dialogue_action_transcribe: Callable = func(action_node: GraphNode):
		action_res.action[load(action_node.dlg_res_path.text)] = null
	#endregion
	
	# transcription from node to resource data for every node type.
	if action_node is PlaywrightActionAnimation:
		anim_action_transcribe.call(action_node)
		
	elif action_node is PlaywrightActionCamSwitch:
		cam_switch_action_transcribe.call(action_node)
		
	elif action_node is PlaywrightActionTimer:
		timer_action_transcribe.call(action_node)
		
	elif action_node is PlaywrightActionCallable:
		callable_action_transcribe.call(action_node)
		
	elif action_node is PlaywrightActionDialogue:
		dialogue_action_transcribe.call(action_node)
	
	return action_res

func save_event_res_to_disk(event_res: Event, res_name: String):
	var event_filename: String = res_name + ".tres"
	export_event_file_dialog.current_path = event_filename
	
	var confirmed_func: Callable = func():
		var save_result: Error = ResourceSaver.save(event_res, export_event_file_dialog.current_path)
		
		if save_result != OK:
			print(save_result)
		else:
			# there isn't an easy fix for immediate resource updating upon overwrite, see: https://github.com/godotengine/godot/issues/30302
			# but, relaunching the editor or sometimes clicking around a bit afterwards does the job.
			fs.update_file(export_event_file_dialog.current_path)
			print("File saved!")
		
		flush_file_dlg_signals(export_event_file_dialog, ["confirmed", "canceled"])
		file_operation_complete.emit()
	
	var canceled_func: Callable = func():
		print("File save aborted.")
		
		flush_file_dlg_signals(export_event_file_dialog, ["confirmed", "canceled"])
		file_operation_complete.emit()
	
	export_event_file_dialog.confirmed.connect(confirmed_func)
	export_event_file_dialog.canceled.connect(canceled_func)
	
	export_event_file_dialog.visible = true

func _on_import_event_button_pressed():
	pass

func _on_playwright_graph2_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph2.connect_node(from_node,from_port,	to_node, to_port)

func _on_playwright_graph2_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph2.disconnect_node(from_node, from_port, to_node, to_port)

func _on_delete_action_node(action_node: PlaywrightAction) -> void:
	var action_connection_list: Array[Dictionary] = playwright_graph2.get_connection_list()
	
	action_nodes.erase(action_node)
	
	if !action_connection_list.is_empty():
		for connection: Dictionary in action_connection_list:
			if connection["from_node"] == action_node.name || connection["to_node"] == action_node.name:
				playwright_graph2.disconnect_node(connection["from_node"], connection["from_port"], connection["to_node"], connection["to_port"])
			
			action_node.queue_free()
	else:
		action_node.queue_free()

#region Dialogue Editor Code
func _on_add_dialogue_button_pressed():
	instantiate_dialogue_node()

func _on_import_dialogue_button_pressed():
	import_dlg_file_dialog.visible = true

func _on_playwright_graph_connection_to_empty(from_node: StringName, from_port: int, release_position: Vector2):
	if from_port == 0:
		var dlg_node_inst: GraphNode = instantiate_dialogue_node()
		#dialogue_nodes.append(dlg_node_inst)
		var from_node_path: String = "PlaywrightGraph/" + String(from_node)
		var new_node_offset: Vector2 = get_node(NodePath(from_node_path)).position_offset
		new_node_offset.x += DLG_OFFSET_INCREMENT_X
		dlg_node_inst.position_offset = new_node_offset
		playwright_graph.connection_request.emit(from_node, 0, StringName(dlg_node_inst.name), 0)

func instantiate_dialogue_node() -> GraphNode:
	var playwright_dialogue_inst: GraphNode = PlaywrightDialogue.instantiate()
	playwright_graph.add_child(playwright_dialogue_inst)
	dialogue_nodes.append(playwright_dialogue_inst)
	dlg_name_increment += 1
	playwright_dialogue_inst.name = "PlaywrightDialogue" + str(dlg_name_increment)
	playwright_dialogue_inst.title = dialogue_name_line_edit.text + str(dlg_name_increment)
	playwright_dialogue_inst.delete_node.connect(_on_delete_dlg_node)
	return playwright_dialogue_inst

func import_dialogue_files(file_paths: Array) -> void:
	dlg_name_increment = 0
	# import every dialogue file that was selected.
	for file_path: String in file_paths:
		dlg_offset_x = 0.0
		var dlg_res: Dialogue = load(file_path)
		# Take the loaded dialogue resource and use it to make parallel arrays of dialogue nodes and resources.
		var dlg_node_array: Array[GraphNode]
		var dlg_res_array: Array[Dialogue]
		
		dialogue_name_line_edit.text = dlg_res.resource_name
		deserialize_dialogue(dlg_res, dlg_node_array, dlg_res_array)
		
		# if there's more than one dialogue node in the chain during deserialization, determine how to rewire connections between nodes.
		if dlg_node_array.size() > 1:
			for node_num: int in dlg_node_array.size():
				if node_num < dlg_node_array.size() - 1:
					var current_node: GraphNode = dlg_node_array[node_num]
					var next_node: GraphNode = dlg_node_array[node_num + 1]
					
					# rewire dialogue connections by manually firing GraphEdit's connection_request signal.
					playwright_graph.connection_request.emit(StringName(current_node.name), 0, StringName(next_node.name), 0)
					
					# if both this node and the next only have one dialogue branch, connecting is simple.
					if current_node.dialogue_options.size() == 1 && next_node.dialogue_options.size() == 1:
						playwright_graph.connection_request.emit(StringName(current_node.name), 1, StringName(next_node.name), 1)
					# otherwise, determine how to proceed based on dialogue type, etc.
					else:
						# for default nodes, just do a one-to-one match for wires (for now).
						if next_node.dialogue_type_button.selected == DLG_TYPE_DEFAULT:
							# one-to-one branching dialogue rewiring going into a default dialogue type
							if current_node.dialogue_options.size() == next_node.dialogue_options.size():
								for text_pos: int in current_node.dialogue_options.size():
									playwright_graph.connection_request.emit(StringName(current_node.name), text_pos + 1, StringName(next_node.name), text_pos + 1)
							# rewiring if branches are coming to an end on the current node.
							elif current_node.dialogue_options.size() > next_node.dialogue_options.size():
								# if the next node only has one option, just collapse every wire into it.
								if next_node.dialogue_options.size() == 1:
									for text_pos: int in current_node.dialogue_options.size():
										playwright_graph.connection_request.emit(StringName(current_node.name), text_pos + 1, StringName(next_node.name), 1)
								# otherwise, determine which rewires to skip and how to offset the rest.
								else:
									var branch_offset: int = 0
									for text_pos: int in current_node.dialogue_options.size():
										if current_node.dialogue_options[text_pos].text.contains("[end]"):
											branch_offset += 1
										else:
											playwright_graph.connection_request.emit(StringName(current_node.name), text_pos + 1, StringName(next_node.name), text_pos + 1 - branch_offset)
							else:
								print("The dialogue default node is bigger than the preceding response node.")
						# for response nodes, use array positioning from the resource itself. this is where the parallel arrays come into play.
						elif next_node.dialogue_type_button.selected == DLG_TYPE_RESPONSE:
							# branching dialogue rewiring going into a response dialogue type
							if next_node.dialogue_options.size() > 1:
								var continuing_branches: Array[int]
								for text_pos: int in current_node.dialogue_options.size():
									if !current_node.dialogue_options[text_pos].text.contains("[end]"):
										continuing_branches.append(text_pos)
								
								var slot_pos: int = 0
								for branch_pos: int in continuing_branches.size():
									var connection_count: int = dlg_res_array[node_num + 1].dialogue_options[branch_pos].size()
									for con_num: int in connection_count:
										playwright_graph.connection_request.emit(StringName(current_node.name), continuing_branches[branch_pos] + 1, StringName(next_node.name), slot_pos + 1 + con_num)
										#print("current node: " + str(current_node) + ". " + "slot left: " + str(continuing_branches[branch_pos]) + ", slot right: " + str(slot_pos + 1))
									slot_pos += connection_count
							# rewiring when every branch collapses into one slot on the next node.
							else:
								for text_pos: int in current_node.dialogue_options.size():
									if !current_node.dialogue_options[text_pos].text.contains("[end]"):
										playwright_graph.connection_request.emit(StringName(current_node.name), text_pos + 1, StringName(next_node.name), 1)
						# TODO: Decide how to handle other dialogue types in terms of rewiring nodes.
						else:
							pass
					
					# lastly, clean up [end] tags in TextEdit fields to complete deserialization.
					for dlg_line: TextEdit in current_node.dialogue_options:
						dlg_line.text = dlg_line.text.replace("[end]", "")
						dlg_line.text = dlg_line.text.replace("[/end]", "")
		
		dlg_offset_y += DLG_OFFSET_INCREMENT_Y

func deserialize_dialogue(dlg_res: Dialogue, out_node_array: Array[GraphNode], out_res_array: Array[Dialogue]) -> void:
	var dlg_node_inst: GraphNode = instantiate_dialogue_node()
	if out_node_array.is_empty():
		dlg_node_inst.title = dialogue_name_line_edit.text
	else:
		dlg_node_inst.title = dialogue_name_line_edit.text + "_" + str(dlg_name_increment - 1)
	
	dialogue_nodes.append(dlg_node_inst)
	out_node_array.append(dlg_node_inst)
	out_res_array.append(dlg_res)
	
	# offset dialogue nodes on the graph so they do not overlap.
	dlg_node_inst.position_offset.x += dlg_offset_x
	dlg_node_inst.position_offset.y += dlg_offset_y
	dlg_offset_x += DLG_OFFSET_INCREMENT_X
	
	# deserialize the straightforward information.
	dlg_node_inst.speaker_line_edit.text = dlg_res.speaker
	dlg_node_inst.dialogue_type_button.selected = dlg_res.dialogue_type
	
	if dlg_res.dialogue_type == Dialogue.DialogueType.DEFAULT:
		# determine how many TextEdits are needed for default dialogue data and instantiate them.
		var boxes_needed: int = dlg_res.dialogue_options.size() - 1
		for num: int in boxes_needed:
			dlg_node_inst.add_dialogue_text()
		
		# fill each TextEdit with each string in an array of dialogue lines being on a new line.
		for dlg_num: int in dlg_res.dialogue_options.size():
			var dlg_res_lines: Array = dlg_res.dialogue_options[dlg_num]
			for dlg_line_num: int in dlg_res_lines.size():
				var dlg_line: TextEdit = dlg_node_inst.dialogue_options[dlg_num]
				if dlg_line_num < dlg_res_lines.size() - 1:
					dlg_line.text += dlg_res_lines[dlg_line_num] + "\n"
				else:
					dlg_line.text += dlg_res_lines[dlg_line_num]
		
	elif dlg_res.dialogue_type == Dialogue.DialogueType.RESPONSE:
		# determine how many TextEdits are needed for response dialogue data and instantiate them.
		var boxes_needed: int = 0
		for dlg_option in dlg_res.dialogue_options:
			boxes_needed += dlg_option.size()
		for num: int in boxes_needed - 1:
			dlg_node_inst.add_dialogue_text()
		
		# make each response occupy its own TextEdit, regardless of whether or not they sit in different nested arrays.
		var dlg_pos: int = 0
		for dlg in dlg_res.dialogue_options:
			for dlg_line in dlg:
				dlg_node_inst.dialogue_options[dlg_pos].text = dlg_line
				dlg_pos += 1
	
	# resize every TextEdit according to its contents.
	for dlg_branch: TextEdit in dlg_node_inst.dialogue_options:
		dlg_branch.resize_on_instantiate()
	
	# if there is a next dialogue, recursively call this function again.
	if dlg_res.next_dialogue != null:
		deserialize_dialogue(dlg_res.next_dialogue, out_node_array, out_res_array)

func _on_serialize_dialogue_button_pressed():
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	
	# if there is a connection list, sort dialogue nodes and then serialize them.
	if dialogue_connection_list.size() > 0:
		print("Dialogue chain present: sorting dialogue nodes and serializing them.")
		var sorted_dialogue_node_names: Array[String] = sort_dialogue_nodes(dialogue_connection_list)
		
		# use dialogue node name data to fetch the nodes themselves and transcribe them into an array of dialogue resources.
		var dlg_res_array: Array[Dialogue]
		var last_node_name: String = ""
		var next_node: GraphNode
		
		var dialogue_line_connections: Array[Dictionary] = filter_line_connections_dlg(dialogue_connection_list)
		for node_name_pos: int in sorted_dialogue_node_names.size():
			var node_path_str: String = "PlaywrightGraph/" + sorted_dialogue_node_names[node_name_pos]
			var dlg_node: GraphNode = get_node(NodePath(node_path_str))
			if node_name_pos + 1 < sorted_dialogue_node_names.size():
				next_node = get_node(NodePath("PlaywrightGraph/" + sorted_dialogue_node_names[node_name_pos + 1]))
			else: 
				next_node = null
			var dlg: Dialogue = transcribe_dialogue_node_to_resource(dlg_node, last_node_name, next_node, dialogue_line_connections)
			dlg_res_array.append(dlg)
			last_node_name = dlg_node.name
		
		# chain each dialogue to the next dialogue in its array, unless its the last element. this is a linked list!
		for dlg_pos: int in dlg_res_array.size():
			if dlg_pos < dlg_res_array.size() - 1:
				var dlg_to_chain: Dialogue = dlg_res_array[dlg_pos]
				dlg_to_chain.next_dialogue = dlg_res_array[dlg_pos + 1]
				print("dlg: " + str(dlg_to_chain) + ", next dlg: " + str(dlg_to_chain.next_dialogue))
			
			# FIXME: this is for debugging, comment it out later or remove it.
			else:
				var dlg_to_chain: Dialogue = dlg_res_array[dlg_pos]
				print("dlg: " + str(dlg_to_chain) + ", end of list.")
		
		# save the first resource in the array to disk as a .tres. each resource afterwards is a nested subresource,
		# ... so only this is needed for the entire dialogue tree.
		save_dialogue_res_to_disk(dlg_res_array[0], dialogue_name_line_edit.text)
		await file_operation_complete
		
		# next, figure out if there are any non-connected dialogue nodes and save them separately.
		if sorted_dialogue_node_names.size() != dialogue_nodes.size():
			var floating_dialogues: Array[GraphNode]
			print("Saving separate dialogue nodes.")
			for dlg_node: GraphNode in dialogue_nodes:
				if dlg_node != null:
					if sorted_dialogue_node_names.find(dlg_node.name) == -1:
						floating_dialogues.append(dlg_node)
			
			serialize_unconnected_dlg_nodes(floating_dialogues)
	
	# if there isn't a connection list, dialogue nodes do not need to be sorted in any way - just serialize them.
	else:
		print("No dialogue chain present, serializing dialogue nodes individually.")
		serialize_unconnected_dlg_nodes(dialogue_nodes)

func serialize_unconnected_dlg_nodes(dlg_node_array: Array[GraphNode]) -> void:
	var dlg_res_array: Array[Dialogue]
	for dlg_node: GraphNode in dlg_node_array:
		var dlg: Resource = transcribe_dialogue_node_to_resource(dlg_node)
		dlg_res_array.append(dlg)
	
	var count_num: int = 0
	for dlg: Resource in dlg_res_array:
		count_num += 1
		var res_name: String = dialogue_name_line_edit.text + str(count_num)
		save_dialogue_res_to_disk(dlg, res_name)
		await file_operation_complete

func save_dialogue_res_to_disk(dlg_res: Dialogue, res_name: String):
	recursive_sub_dlg_res_rename(dlg_res, res_name) # renames the resource_name for this dialogue and any nested ones. good for clarity in resource data, especially in git.
	var dlg_filename: String = res_name + ".tres"
	export_dlg_file_dialog.current_path = dlg_filename
	
	var confirmed_func: Callable = func():
		var save_result: Error = ResourceSaver.save(dlg_res, export_dlg_file_dialog.current_path)
		
		if save_result != OK:
			print(save_result)
		else:
			# there isn't an easy fix for immediate resource updating upon overwrite, see: https://github.com/godotengine/godot/issues/30302
			# but, relaunching the editor or sometimes clicking around a bit afterwards does the job.
			fs.update_file(export_dlg_file_dialog.current_path)
			#res_prev.check_for_invalidation(dlg_file_dialog.current_path)
			print("File saved!")
		
		flush_file_dlg_signals(export_dlg_file_dialog, ["confirmed", "canceled"])
		file_operation_complete.emit()
	
	var canceled_func: Callable = func():
		print("File save aborted.")
		
		flush_file_dlg_signals(export_dlg_file_dialog, ["confirmed", "canceled"])
		file_operation_complete.emit()
	
	export_dlg_file_dialog.confirmed.connect(confirmed_func)
	export_dlg_file_dialog.canceled.connect(canceled_func)
	
	export_dlg_file_dialog.visible = true

func recursive_sub_dlg_res_rename(dlg_res: Dialogue, res_name: String, counter: int = 0) -> void:
	if counter == 0:
		dlg_res.resource_name = res_name
	else:
		dlg_res.resource_name = res_name + "_" + str(counter)
	
	counter += 1
	
	if dlg_res.next_dialogue != null:
		recursive_sub_dlg_res_rename(dlg_res.next_dialogue, res_name, counter)

func flush_file_dlg_signals(file_dlg: FileDialog, signals: Array[String]):
	var decrement: int = 1
	for sig in signals:
		var signal_list: Array[Dictionary] = file_dlg.get_signal_connection_list(sig)
		file_dlg.disconnect(sig, signal_list[decrement]["callable"])
		decrement -= 1 # this may have to change later, but maybe not

func filter_line_connections_dlg(connection_list: Array[Dictionary]) -> Array[Dictionary]:
	# filter for dlg line connections only (any slot but 0).
	var line_connections: Array[Dictionary]
	for connection: Dictionary in connection_list:
		if connection["from_port"] != 0 && connection["to_port"] != 0:
			line_connections.append(connection)
	
	return line_connections

func filter_line_connections_action(connection_list: Array[Dictionary]) -> Array[Dictionary]:
	# filter for action line connections only (0 on left, any other slot on right).
	var line_connections: Array[Dictionary]
	for connection: Dictionary in connection_list:
		if connection["from_port"] == 0 && connection["to_port"] != 0:
			line_connections.append(connection)
	
	return line_connections

# NOTE: this is a helper function for _on_serialize_dialogue_button_pressed up above.
# a function that interprets all existing graph node and connection data to extrapolate a sorted array of dialogue node names.
func sort_dialogue_nodes(connection_list: Array[Dictionary]) -> Array[String]:
	var sorted_dialogue_node_names: Array[String]
	
	# filter for Dialogue connections only (slot 0).
	var dialogue_node_connections: Array[Dictionary]
	for connection: Dictionary in connection_list:
		if connection["from_port"] == 0 && connection["to_port"] == 0:
			dialogue_node_connections.append(connection)
	
	# convert dictionary data into two separate arrays.
	var from_nodes: Array[String]
	var to_nodes: Array[String]
	for dlg_connection: Dictionary in dialogue_node_connections:
		from_nodes.append(dlg_connection["from_node"])
		to_nodes.append(dlg_connection["to_node"])
	
	# determine the starting dialogue node by finding the one that doesn't act as a to_node anywhere.
	var starting_node_name: String
	for from_node_name: String in from_nodes:
		var match_found: bool = false
		for to_node_name: String in to_nodes:
			if from_node_name == to_node_name:
				match_found = true
		if !match_found:
			starting_node_name = from_node_name
			break
	
	# use the determined starting node as a jumping off point, and sort the rest of the dialogue nodes by pouring over their connection keys until everything is accounted for.
	var initial_dialogue_name_array: Array[String]
	initial_dialogue_name_array.append(starting_node_name)
	var node_temp: String = initial_dialogue_name_array[0]
	
	return traverse_node_connection_array(dialogue_node_connections, initial_dialogue_name_array, node_temp)

# NOTE: this is a helper function for sort_dialogue_nodes and sort_action_nodes.
# a recursive function that traverses the same array of dictionaries over and over until all dialogue or action connections have been accounted for.
func traverse_node_connection_array(connections_array: Array[Dictionary], sorted_node_names: Array[String], node_temp: String) -> Array[String]:
	for node_connection: Dictionary in connections_array:
		if node_connection["from_node"] == node_temp:
			node_temp = node_connection["to_node"]
			sorted_node_names.append(node_connection["to_node"])
	
	if sorted_node_names.size() - 1 < connections_array.size():
		return traverse_node_connection_array(connections_array, sorted_node_names, node_temp)
	else:
		return sorted_node_names

func transcribe_dialogue_node_to_resource(dlg_node: GraphNode, last_node_name: String = "", next_node: GraphNode = null, dlg_line_connections: Array[Dictionary] = []) -> Dialogue:
	var dialogue_res: Dialogue = Dialogue.new()
	# fill the obvious fields first - speaker and dialogue type.
	dialogue_res.speaker = dlg_node.speaker_line_edit.text
	dialogue_res.dialogue_type = dlg_node.dialogue_type_button.selected
	
	if dialogue_res.dialogue_type == Dialogue.DialogueType.DEFAULT:
		# loop through each dialogue box on the node
		for dlg_lines_pos: int in dlg_node.dialogue_options.size():
			var lines: Array[String]
			# loop through each line in each dialogue box.
			for line: int in dlg_node.dialogue_options[dlg_lines_pos].get_line_count():
				# turn each dialogue box into an array of strings.
				lines.append(dlg_node.dialogue_options[dlg_lines_pos].get_line(line))
			
			# add the [end] tag to any ending branches.
			lines[0] = append_end_tag_to_string(lines[0], dlg_lines_pos, dlg_node, next_node, dlg_line_connections)
			
			dialogue_res.dialogue_options.append(lines)
	
	elif dialogue_res.dialogue_type == Dialogue.DialogueType.RESPONSE:
		if dlg_node.dialogue_options.size() == 1:
			var responses: Array[String]
			responses.append(dlg_node.dialogue_options[0].text)
			dialogue_res.dialogue_options.append(responses)
		else:
			# find relevant node connections for the given node.
			var relevant_connections: Array[Dictionary]
			var last_node_connection_total: Array[int]
			for connection: Dictionary in dlg_line_connections:
				if connection["from_node"] == last_node_name:
					relevant_connections.append(connection)
				if last_node_connection_total.has(connection["from_port"]) == false:
					last_node_connection_total.append(connection["from_port"])
			
			# sort relevant_connections in order of from_port number, ascending.
			relevant_connections.sort_custom(func(a, b): return a["from_port"] < b["from_port"])
			print(relevant_connections)
			
			# determine which ports on the prior node have connections running into the current node, and make an array based off of that.
			var last_node_connections: Array[int]
			for connection: Dictionary in relevant_connections:
				if !last_node_connections.has(connection["from_port"]):
					last_node_connections.append(connection["from_port"])
			
			# add the [end] tag to any ending branches. for response nodes this has to be added to the node text itself for simplicity, and then removed at the end of this elif.
			for dlg_lines_pos: int in dlg_node.dialogue_options.size():
				dlg_node.dialogue_options[dlg_lines_pos].text = append_end_tag_to_string(dlg_node.dialogue_options[dlg_lines_pos].text, dlg_lines_pos, dlg_node, next_node, dlg_line_connections)
			
			# package dialogue response data into nested arrays based on which port from the previous node feeds into them, and them package each array into the dialogue resource.
			for out_port: int in last_node_connections:
				var responses: Array[String]
				for dlg_options_pos: int in dlg_node.dialogue_options.size():
					if playwright_graph.is_node_connected(StringName(last_node_name), out_port, StringName(dlg_node.name), dlg_options_pos + 1):
						responses.append(dlg_node.dialogue_options[dlg_options_pos].text)
				dialogue_res.dialogue_options.append(responses)
			
			# remove the [end] tags from the response dialogue nodes themselves now that the information has been transcribed.
			for dlg_line: TextEdit in dlg_node.dialogue_options:
				dlg_line.text = dlg_line.text.replace("[end]", "")
				dlg_line.text = dlg_line.text.replace("[/end]", "")
	else:
		# TODO: Implement dialogue option sorting for other dialogue type transcription.
		pass
	
	return dialogue_res

# NOTE: helper function for the above function, does what it says.
func append_end_tag_to_string(base_string: String, dlg_lines_pos: int, dlg_node: GraphNode, next_node: GraphNode, dlg_line_connections: Array[Dictionary]) -> String:
	if dlg_node != null && next_node != null:
		var is_connected_to_something: bool = false
		for connection: Dictionary in dlg_line_connections:
			for dlg_option_pos: int in next_node.dialogue_options.size():
				if playwright_graph.is_node_connected(StringName(dlg_node.name), dlg_lines_pos + 1, StringName(next_node.name), dlg_option_pos + 1):
					is_connected_to_something = true
					break
			if is_connected_to_something:
				break
			
		if !is_connected_to_something:
			base_string = "[end]" + base_string + "[/end]"
		
		return base_string
	else:
		return base_string

func _on_playwright_graph_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.connect_node(from_node, from_port, to_node, to_port)
	
	# if the port isn't 0 (for dialogue to dialogue connections) change color.
	if from_port >= 1 && to_port >= 1:
		change_node_port_color(to_node, to_port, Color.LIME_GREEN)
	else:
		change_node_port_color(to_node, to_port, Color.PINK)

func _on_playwright_graph_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int):
	playwright_graph.disconnect_node(from_node, from_port, to_node, to_port)
	
	# if the port isn't 0 (for dialogue to dialogue connections) change color back.
	if from_port >= 1 && to_port >= 1:
		change_node_port_color(to_node, to_port, Color.ROYAL_BLUE)
	else:
		change_node_port_color(to_node, to_port, Color.PURPLE)

func change_node_port_color(node_name: StringName, port: int, color: Color) -> void:
	var dlg_node: GraphNode
	for graph_node: Control in playwright_graph.get_children():
		if graph_node.name == node_name:
			dlg_node = graph_node
			break
	
	var slot_idx: int = dlg_node.get_input_port_slot(port)
	dlg_node.get_child(slot_idx)
	dlg_node.set_slot_color_left(slot_idx, color)

func _on_delete_dlg_node(dialogue_node: GraphNode) -> void:
	#print(dialogue_node.name)
	var dialogue_connection_list: Array[Dictionary] = playwright_graph.get_connection_list()
	
	dialogue_nodes.erase(dialogue_node)
	
	if !dialogue_connection_list.is_empty():
		for connection: Dictionary in dialogue_connection_list:
			if connection["from_node"] == dialogue_node.name || connection["to_node"] == dialogue_node.name:
				playwright_graph.disconnect_node(connection["from_node"], connection["from_port"], connection["to_node"], connection["to_port"])
			
			dialogue_node.queue_free()
	else:
		dialogue_node.queue_free()
#endregion

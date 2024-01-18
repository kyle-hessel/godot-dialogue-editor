@tool
extends TextEdit

const DEFAULT_MINIMUM_SIZE: int = 50
const THEME_LINE_SPACING: int = 4
const THEME_FONT_SIZE: int = 16
var resize_amount: int = THEME_FONT_SIZE + THEME_LINE_SPACING + 10

var line_count_cached: int = 0

func _ready():
	line_count_cached = get_line_count()
	text_changed.connect(resize_text_edit)

func resize_text_edit() -> void:
	var line_count: int = get_line_count()
	if get_line_count() != line_count_cached:
		if line_count == 1:
			custom_minimum_size.y = DEFAULT_MINIMUM_SIZE
		else:
			if line_count > line_count_cached:
				custom_minimum_size.y += resize_amount - line_count
			elif line_count < line_count_cached:
				custom_minimum_size.y -= resize_amount - line_count
	line_count_cached = line_count

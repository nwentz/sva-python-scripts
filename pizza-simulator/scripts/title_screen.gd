class_name TitleScreen
extends CanvasLayer
## Full-screen title card shown before a play session starts.
##
## The camera rig captures the pointer when the kitchen is built, so this
## screen frees it while it is up: the player can move the cursor and click
## PRESS PLAY. Enter (or Space) starts the game as well. Once the game starts
## the pointer is handed back to the camera rig and this layer removes itself.

signal started

const DIM := Color(0.06, 0.04, 0.03, 0.94)
const BAND := Color(0.16, 0.06, 0.03, 0.92)
const GOLD := Color(0.98, 0.76, 0.28)
const CREAM := Color(1.0, 0.94, 0.78)
const MUTED := Color(0.82, 0.76, 0.66)
const RED := Color(0.72, 0.13, 0.11)

var _root: Control
var _play: Button
var _book: Control
var _book_open := false
var _rig: Node = null
var _t := 0.0
var _started := false


func _ready() -> void:
	# Keep the title responsive even if something pauses the game tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# The rig is a sibling of this layer under Main. Release the pointer so the
	# cursor is visible and the PRESS PLAY button can actually be clicked.
	_rig = get_parent().get_node_or_null("CameraRig")
	if _rig != null and _rig.has_method("release_mouse"):
		_rig.call("release_mouse")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build_ui()
	print("Title screen shown - mouse free (click PRESS PLAY or press ENTER)")


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallow clicks so they never fall through to the D-pad or the camera rig.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var band := ColorRect.new()
	band.color = BAND
	_place(band, 0.0, -160.0, 1080.0, 260.0)
	_root.add_child(band)

	var title := _label("PIZZA SIMULATOR", 78, GOLD)
	_place(title, 0.0, -185.0, 1100.0, 120.0)
	_root.add_child(title)

	var sub := _label("Fresh from the oven, straight to the customer", 26, CREAM)
	_place(sub, 0.0, -105.0, 1100.0, 48.0)
	_root.add_child(sub)

	_play = Button.new()
	_play.text = "PRESS PLAY"
	_play.focus_mode = Control.FOCUS_NONE
	_play.mouse_filter = Control.MOUSE_FILTER_STOP
	_play.add_theme_stylebox_override("normal", _button_style(RED))
	_play.add_theme_stylebox_override("hover", _button_style(Color(0.86, 0.18, 0.13)))
	_play.add_theme_stylebox_override("pressed", _button_style(Color(0.52, 0.08, 0.06)))
	_play.add_theme_color_override("font_color", CREAM)
	_play.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_play.add_theme_font_size_override("font_size", 42)
	_place(_play, 0.0, 30.0, 380.0, 96.0)
	_play.pressed.connect(_start)
	_root.add_child(_play)

	var hint := _label("Click the button  or  press ENTER to start", 21, MUTED)
	_place(hint, 0.0, 112.0, 1100.0, 44.0)
	_root.add_child(hint)

	_build_rulebook_button()
	_build_rulebook_overlay()


## A little cookbook-shaped tab on the title screen. Clicking it opens the
## rulebook in full view instead of printing hotkeys across the title.
func _build_rulebook_button() -> void:
	var tab := Button.new()
	tab.name = "RulebookButton"
	tab.text = "RULEBOOK"
	tab.focus_mode = Control.FOCUS_NONE
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.add_theme_stylebox_override("normal", _button_style(Color(0.42, 0.09, 0.08)))
	tab.add_theme_stylebox_override("hover", _button_style(Color(0.55, 0.12, 0.10)))
	tab.add_theme_stylebox_override("pressed", _button_style(Color(0.30, 0.06, 0.06)))
	tab.add_theme_color_override("font_color", CREAM)
	tab.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	tab.add_theme_font_size_override("font_size", 24)
	_place(tab, 0.0, 216.0, 260.0, 62.0)
	tab.pressed.connect(_open_rulebook)
	_root.add_child(tab)


## The full-view rulebook: an open pizza cookbook on a darkened backdrop.
## Built last so it draws over the title, and hidden until RULEBOOK is clicked.
func _build_rulebook_overlay() -> void:
	const PAPER := Color(0.95, 0.90, 0.76)
	const INK := Color(0.28, 0.16, 0.09)
	const COVER := Color(0.42, 0.09, 0.08)

	_book = Control.new()
	_book.name = "RulebookOverlay"
	_book.set_anchors_preset(Control.PRESET_FULL_RECT)
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.visible = false
	_root.add_child(_book)

	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.03, 0.02, 0.02, 0.88)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_rulebook())
	_book.add_child(veil)

	var book := Panel.new()
	book.name = "Rulebook"
	_place(book, 0.0, -6.0, 1040.0, 548.0)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(5)
	sb.border_color = COVER
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(4, 6)
	book.add_theme_stylebox_override("panel", sb)
	_book.add_child(book)

	var head := _label("PIZZA COOKBOOK", 34, COVER)
	head.add_theme_font_override("font", _book_font(4))
	head.add_theme_constant_override("outline_size", 0)
	head.position = Vector2(0, 12)
	head.size = Vector2(1040, 46)
	book.add_child(head)

	var tag := _label("A chef's guide to making pizzas", 17, INK)
	tag.add_theme_font_override("font", _book_font(2))
	tag.add_theme_constant_override("outline_size", 0)
	tag.position = Vector2(0, 58)
	tag.size = Vector2(1040, 28)
	book.add_child(tag)

	var rule := ColorRect.new()
	rule.position = Vector2(44, 96)
	rule.size = Vector2(952, 3)
	rule.color = Color(0.42, 0.09, 0.08, 0.7)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(rule)

	var spine := ColorRect.new()
	spine.position = Vector2(518, 116)
	spine.size = Vector2(3, 350)
	spine.color = Color(0.42, 0.09, 0.08, 0.3)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(spine)

	book.add_child(_page("CONTROLS", "G     grab / interact\n"
		+ "L     drop / start minigames\n"
		+ "K     knead the dough\n"
		+ "C     cut the cheese\n"
		+ "MOUSE spread sauce\n"
		+ "WASD  move\n"
		+ "SHIFT sprint\n"
		+ "ESC   free mouse", 44.0, 20))
	book.add_child(_page("HOW TO PLAY", "1  Take dough from the DOUGH stand.\n"
		+ "2  Knead it with K, then set it\n"
		+ "   on the PREP TABLE with L.\n"
		+ "3  Spread sauce with the MOUSE.\n"
		+ "4  Add cheese and shred with C.\n"
		+ "5  Add the toppings on the order.\n"
		+ "6  Bake in the OVEN, then take\n"
		+ "   the pizza to the COUNTER.", 546.0, 18))

	var close := Button.new()
	close.name = "CloseRulebook"
	close.text = "CLOSE   (ESC)"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_stylebox_override("normal", _button_style(COVER))
	close.add_theme_stylebox_override("hover", _button_style(Color(0.55, 0.12, 0.10)))
	close.add_theme_stylebox_override("pressed", _button_style(Color(0.30, 0.06, 0.06)))
	close.add_theme_color_override("font_color", CREAM)
	close.add_theme_font_size_override("font_size", 20)
	close.add_theme_font_override("font", _book_font(2))
	close.position = Vector2(400, 486)
	close.size = Vector2(240, 50)
	close.pressed.connect(_close_rulebook)
	book.add_child(close)


## One page column of the cookbook: a heading plus its body text.
func _page(heading: String, text: String, x: float, size: int) -> Label:
	var l := _label(heading + "\n\n" + text, size, Color(0.28, 0.16, 0.09))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_override("font", _book_font(2))
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("line_spacing", 9)
	l.position = Vector2(x, 116)
	l.size = Vector2(452, 360)
	return l


## Lightly letter-spaced version of the default font, used only in the
## rulebook. `base_font` left empty so it inherits the project's theme font.
func _book_font(spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.spacing_glyph = spacing
	fv.spacing_space = 1
	return fv


func _open_rulebook() -> void:
	if _book_open:
		return
	_book_open = true
	_book.show()


func _close_rulebook() -> void:
	if not _book_open:
		return
	_book_open = false
	_book.hide()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _button_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = GOLD
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb


## Anchor a control around the centre of the viewport (offsets are relative
## to the centre, so the layout survives window resizing).
func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = x - w * 0.5
	c.offset_right = x + w * 0.5
	c.offset_top = y - h * 0.5
	c.offset_bottom = y + h * 0.5


func _input(e: InputEvent) -> void:
	if _started:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k := (e as InputEventKey).keycode
		if _book_open:
			# While reading, keys only dismiss the book - never start the game.
			if k == KEY_ESCAPE or k == KEY_ENTER or k == KEY_KP_ENTER:
				_close_rulebook()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_start()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			# Don't let the camera rig re-capture the pointer behind the title.
			get_viewport().set_input_as_handled()
	# Mouse button events are deliberately NOT consumed here: the button needs
	# to receive them through the normal GUI pass.


func _process(delta: float) -> void:
	if _started or _play == null:
		return
	# The button never moves: it just swells in brightness to draw the eye.
	# Values above 1 brighten the red face, gold border and label together.
	_t += delta
	var glow := 0.5 + 0.5 * sin(_t * 2.2)
	_play.modulate = Color(1.0 + 0.3 * glow, 0.92 + 0.24 * glow, 0.82 + 0.18 * glow)


func _start() -> void:
	if _started:
		return
	_started = true

	# Time spent reading the title screen should not eat into the first order.
	GameManager.new_order()

	if _rig != null and _rig.has_method("capture_mouse"):
		_rig.call("capture_mouse")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	started.emit()
	print("Title screen: game started (mouse captured)")
	queue_free()

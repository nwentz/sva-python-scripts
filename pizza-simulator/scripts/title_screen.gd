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

	var keys := _label(
		"WASD move    G grab/interact    L interact    MOUSE spread sauce\n"
		+ "K knead    C cut cheese    SHIFT sprint    SPACE jump    ESC free mouse",
		16, Color(0.62, 0.58, 0.52))
	_place(keys, 0.0, 200.0, 1100.0, 64.0)
	_root.add_child(keys)


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
		if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
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

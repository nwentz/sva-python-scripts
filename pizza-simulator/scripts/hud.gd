class_name HUD
extends CanvasLayer

var _order: Label
var _score: Label
var _time: Label
var _hands: Label
var _hint: Label
var _keys: Label
var _flash: Label
var _timer_bar: ColorRect
var _timer_t := 0.0
var _flash_t := 0.0

func _ready() -> void:
	_order = _mk(24, 16, 760, 70, 24)
	_score = _mk(24, 92, 760, 40, 20)
	_time = _mk(24, 134, 760, 40, 20)
	_hands = _mk(24, 618, 900, 40, 20)
	_hint = _mk(24, 660, 1140, 44, 20)
	_keys = _mk(24, 584, 1140, 34, 16)
	_flash = _mk(0, 300, 1280, 60, 32)
	_timer_bar = ColorRect.new()
	_timer_bar.size = Vector2(0, 4)
	_timer_bar.position = Vector2(24, 148)
	_timer_bar.z_index = -1
	_timer_bar.modulate = Color(0.4, 0.8, 1)
	add_child(_timer_bar)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.text = "G = grab / interact     L = drop onto the prep table     WASD = move     SHIFT = sprint     SPACE = jump     ESC = free mouse"

	GameManager.order_changed.connect(_refresh)
	GameManager.hands_changed.connect(_refresh)
	GameManager.score_changed.connect(func(_v): _refresh())
	GameManager.hint_changed.connect(func(t): _hint.text = t)
	GameManager.feedback.connect(_on_feedback)
	_refresh()

func _mk(x: float, y: float, w: float, h: float, sz: int) -> Label:
	var l := Label.new()
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.theme_type_variation = "LabelBlackBoard"
	add_child(l)
	return l

func _refresh() -> void:
	var g := GameManager
	var pretty := {"pepperoni": "Pepperoni", "mushroom": "Mushroom", "olive": "Olives"}
	var parts: Array[String] = []
	for t in g.required:
		parts.append(str(pretty.get(t, t)))
	_order.text = "ORDER: " + (", ".join(parts) if parts.size() else "waiting...")
	_score.text = "Score: %d      Pizzas served: %d" % [g.score, g.served]

	var p = g.hands_pizza
	if p:
		_hands.text = "Hands: pizza (%s)" % _stage_name(p.stage)
	elif g.hands_ingredient != "":
		_hands.text = "Hands: %s" % g.hands_ingredient.capitalize()
	else:
		_hands.text = "Hands: empty"
	_hint.text = g.hint

func _process(delta: float) -> void:
	_time.text = "Order time left: %.0f s" % GameManager.time_left

	# Update timer bar
	_timer_t = GameManager.time_left / GameManager.order_time
	_timer_bar.size.x = 760 * _timer_t

	# Flash feedback
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.text = ""

func _stage_name(s: int) -> String:
	return {
		Pizza.Stage.DOUGH: "raw dough",
		Pizza.Stage.SAUCED: "sauced",
		Pizza.Stage.CHEESED: "cheesed",
		Pizza.Stage.TOPPED: "topped",
		Pizza.Stage.BAKING: "baking",
		Pizza.Stage.BAKED: "baked",
		Pizza.Stage.BURNT: "BURNT"
	}.get(s, "unknown")

func _on_feedback(text: String, good: bool) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", Color(0.4, 1.0, 0.45) if good else Color(1, 0.45, 0.4))
	_flash_t = 4.0
	_timer_bar.modulate = Color(1, 1, 1, 1) if good else Color(1, 0.4, 0.4)

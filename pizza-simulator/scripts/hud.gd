class_name HUD
extends CanvasLayer

var _order: Label
var _score: Label
var _time: Label
var _hands: Label
var _hint: Label
var _keys: Label
var _flash: Label
var _oven: Label
var _knead: Label
var _timer_bar: ColorRect
var _timer_t := 0.0
var _flash_t := 0.0

func _ready() -> void:
	_order = _mk(24, 16, 760, 70, 24)
	_score = _mk(24, 92, 760, 40, 20)
	_time = _mk(24, 134, 760, 40, 20)
	_oven = _mk(24, 176, 900, 40, 22)
	_knead = _mk(24, 218, 900, 44, 26)
	_knead.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	# The bottom block is anchored to the viewport bottom. Fixed y values used
	# to push the hints and hotkeys off the bottom of 16:9 windows.
	_hands = _mk(24, 0, 900, 40, 20)
	_hint = _mk(24, 0, 1120, 48, 20)
	_keys = _mk(24, 0, 1120, 52, 15)
	_flash = _mk(0, 300, 1152, 60, 32)
	_bottom(_keys, 104.0, 52.0)
	_bottom(_hands, 56.0, 40.0)
	_bottom(_hint, 4.0, 48.0)
	# Centre feedback on the real viewport instead of a fixed 1280-wide box.
	_flash.anchor_right = 1.0
	_flash.offset_right = 0.0
	_timer_bar = ColorRect.new()
	_timer_bar.size = Vector2(0, 6)
	# Sit below the time label (which ends around y 156) so the bar never
	# cuts through the text.
	_timer_bar.position = Vector2(24, 162)
	_timer_bar.z_index = -1
	add_child(_timer_bar)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_keys.text = ("G = grab / interact    L = drop / start minigames    K = knead    C = cut cheese\n"
		+ "MOUSE = spread sauce    WASD = move    SHIFT = sprint    ESC = free mouse")

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


## Pin a label's bottom edge `margin` pixels above the bottom of the viewport.
func _bottom(l: Label, margin: float, h: float) -> void:
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_top = -margin - h
	l.offset_bottom = -margin

func _refresh() -> void:
	var g := GameManager
	var pretty := {"pepperoni": "Pepperoni", "mushroom": "Mushroom", "olive": "Olives"}
	var parts: Array[String] = []
	var counts := {}
	for t in g.required:
		counts[t] = int(counts.get(t, 0)) + 1
	for t in counts:
		parts.append("%s x%d" % [str(pretty.get(t, t)), int(counts[t])])
	_order.text = "ORDER: " + (", ".join(parts) if parts.size() else "waiting...")
	_score.text = "Score: %d      Pizzas served: %d" % [g.score, g.served]

	var p = g.hands_pizza
	if p:
		var stage_name := _stage_name(p.stage)
		if p.stage == Pizza.Stage.DOUGH and p.kneaded:
			stage_name = "kneaded dough"
		_hands.text = "Hands: pizza (%s)" % stage_name
	elif g.hands_ingredient != "":
		_hands.text = "Hands: %s" % g.hands_ingredient.capitalize()
	else:
		_hands.text = "Hands: empty"
	_hint.text = g.hint

## Shows what is happening in the oven, so the player can tell that the pizza
## is cooking even when the oven is off screen.
func _update_oven() -> void:
	var st: KitchenStation = null
	for s in get_tree().get_nodes_in_group("stations"):
		if s is KitchenStation and s.kind == KitchenStation.Kind.OVEN:
			st = s
			break
	if st == null or st.oven_pizza == null:
		_oven.text = ""
		return
	var p := st.oven_pizza
	if p.stage == Pizza.Stage.BAKING:
		var left := maxf(0.0, p.bake_target - p.bake_time)
		_oven.text = "OVEN: cooking... %.0f s to pull it out" % left
		_oven.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	elif p.stage == Pizza.Stage.BAKED:
		_oven.text = "OVEN: pizza is ready - press G at the oven to take it out"
		_oven.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
	elif p.stage == Pizza.Stage.BURNT:
		_oven.text = "OVEN: BURNT! Press G at the oven to take it out"
		_oven.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_oven.text = ""

func _process(delta: float) -> void:
	_time.text = "Order time left: %.0f s" % GameManager.time_left
	_update_oven()

	# Prompt during the kneading close-up, with a live press counter.
	var p := GameManager.kneading_pizza
	if p != null and is_instance_valid(p) and not p.kneaded:
		_knead.text = "KNEAD THE DOUGH - press K  (%d / %d)" % [p.kneads, Pizza.KNEADS_REQUIRED]
	else:
		var sp := GameManager.spreading_pizza
		var ch := GameManager.cutting_cheese
		if sp != null and is_instance_valid(sp):
			_knead.text = "USE MOUSE TO SPREAD SAUCE - move in circles  (%d%%)" % int(100.0 * sp.sauce_spread)
		elif ch != null and is_instance_valid(ch):
			_knead.text = "PRESS C TO CUT CHEESE - shreds  (%d / %d)" % [ch.cheese_cuts, Pizza.CHEESE_CUTS_REQUIRED]
		else:
			_knead.text = ""

	# Update timer bar: shrinks and shifts from green to yellow to red.
	_timer_t = GameManager.time_left / GameManager.order_time
	_timer_bar.size.x = 760 * _timer_t
	_timer_bar.color = _timer_color(_timer_t)

	# Flash feedback
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.text = ""

## Full time is green, halfway yellow, and the last stretch red.
func _timer_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t <= 0.5:
		return Color(0.92, 0.20, 0.18).lerp(Color(1.0, 0.82, 0.15), t * 2.0)
	return Color(1.0, 0.82, 0.15).lerp(Color(0.25, 0.85, 0.35), (t - 0.5) * 2.0)


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
	# The bar's colour is owned by the countdown, so don't tint it here.

extends Node
## Autoload: current order, score, and what the player is holding.

signal hands_changed
signal order_changed
signal score_changed(value: int)
signal hint_changed(text: String)
signal feedback(text: String, good: bool)

const TOPPINGS := ["pepperoni", "mushroom", "olive"]

var score := 0
var served := 0
var time_left := 60.0
var order_time := 60.0
var required: Array[String] = []
var hands_ingredient := ""
var hands_pizza: Pizza = null
var hint := ""

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	new_order()

func _process(delta: float) -> void:
	if time_left <= 0.0:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left == 0.0:
		feedback.emit("Order expired!", false)
		new_order()

func new_order() -> void:
	var pool: Array = TOPPINGS.duplicate()
	required.clear()
	for i in 1 + _rng.randi_range(0, 2):
		required.append(str(pool.pop_at(_rng.randi_range(0, pool.size() - 1))))
	time_left = order_time
	order_changed.emit()

func set_hands_ingredient(v: String) -> void:
	hands_ingredient = v
	hands_changed.emit()

func set_hands_pizza(v: Pizza) -> void:
	hands_pizza = v
	hands_changed.emit()

func set_hint(v: String) -> void:
	if hint == v:
		return
	hint = v
	hint_changed.emit(v)

func serve(p: Pizza) -> void:
	var have := p.toppings
	var hit := 0
	for t in required:
		if have.has(t):
			hit += 1
	var denom := maxi(required.size(), have.size())
	var top := 100.0 if denom == 0 else 100.0 * float(hit) / float(denom)
	var bake := p.bake_score()
	var speed := 100.0 * time_left / order_time
	var total := int(round(0.4 * top + 0.4 * bake + 0.2 * speed))
	score += total
	served += 1
	score_changed.emit(score)
	feedback.emit("+%d    toppings %d%% | bake %d%% | speed %d%%" % [total, int(top), int(bake), int(speed)], true)
	new_order()

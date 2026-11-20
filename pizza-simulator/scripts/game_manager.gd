extends Node
## Autoload: current order, score, and what the player is holding.

signal hands_changed
signal order_changed
signal score_changed(value: int)
signal hint_changed(text: String)
signal feedback(text: String, good: bool)
signal knead_changed(p: Pizza)

const TOPPINGS := ["pepperoni", "mushroom", "olive"]
## Orders can ask for several of the same topping. `required` stores one entry
## per item, so counts are simply repeated entries.
const ORDER_COUNTS := {"pepperoni": 6, "mushroom": 3, "olive": 2}
## Five minutes per pizza - enough time to knead, build and bake without
## rushing the new cooking steps.
const ORDER_SECONDS := 300.0

var score := 0
var served := 0
var time_left := ORDER_SECONDS
var order_time := ORDER_SECONDS
var required: Array[String] = []
var hands_ingredient := ""
var hands_pizza: Pizza = null
## The pizza currently being kneaded. While set, the camera is zoomed in on
## it and only K is accepted as gameplay input.
var kneading_pizza: Pizza = null
## While this is set the camera is zoomed in and the player spreads sauce by
## moving the mouse in circles.
var spreading_pizza: Pizza = null
## Set while the C-key cheese cutting close-up is active.
var cutting_cheese: Pizza = null
## The seated customer at the serve table, used to play the eating animation
## instead of deleting a served pizza.
var customer_node: Node = null
var hint := ""

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	new_order()

func _process(delta: float) -> void:
	if kneading_pizza != null and not is_instance_valid(kneading_pizza):
		kneading_pizza = null
		knead_changed.emit(null)
	if spreading_pizza != null and not is_instance_valid(spreading_pizza):
		spreading_pizza = null
	if cutting_cheese != null and not is_instance_valid(cutting_cheese):
		cutting_cheese = null
	if time_left <= 0.0:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left == 0.0:
		feedback.emit("Order expired!", false)
		new_order()

func start_knead(p: Pizza) -> void:
	kneading_pizza = p
	knead_changed.emit(p)

func finish_knead() -> void:
	kneading_pizza = null
	knead_changed.emit(null)

func new_order() -> void:
	required.clear()
	for t in TOPPINGS:
		for i in int(ORDER_COUNTS.get(t, 0)):
			required.append(t)
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
	# Count-based comparison: each required pepperoni/mushroom/olive is a
	# separate item, so extra or missing copies both lower the score.
	var req_counts := {}
	for t in required:
		req_counts[t] = int(req_counts.get(t, 0)) + 1
	var have_counts := {}
	for t in have:
		have_counts[t] = int(have_counts.get(t, 0)) + 1
	var hit := 0
	for t in req_counts:
		hit += mini(int(req_counts[t]), int(have_counts.get(t, 0)))
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

# Pizza Simulator (Godot 4)

A first-person pizza shop game. Make pizzas at stations (dough, sauce, cheese, toppings, prep, oven, counter).

## Run
Open `project.godot` in Godot 4 and press Play. Main scene: `scenes/main.tscn`.

## Structure
- `scenes/` - main, character, pizza, ui_hud
- `scripts/` - gameplay code (main.gd builds the world at runtime)
- `addons/physics_placer/` - editor tool for baking topping layouts
- `models/` - character model

## Physics
See `PIZZA_PHYSICS_PLAN.md`.

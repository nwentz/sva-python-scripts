# Pizza Simulator (Godot 4)

A first-person pizza shop game. Make pizzas at stations (dough, sauce, cheese, toppings, prep, oven, counter).

## Run
Open `project.godot` in Godot 4 and press Play. Main scene: `scenes/main.tscn`.

## Structure
- `scenes/` - main, character, pizza, ui_hud
- `scripts/` - gameplay code (main.gd builds the world at runtime)
- `addons/physics_placer/` - editor tool for baking topping layouts
- `addons/godot_mcp_toolkit/` - MCP bridge for AI tooling
- `models/` - character model

## Gameplay
G grabs / interacts, L drops what you are holding onto the prep table.

1. Grab dough at the DOUGH station, drop it on the PREP table.
2. Grab sauce, drop it onto the dough.
3. Grab cheese, drop it onto the sauce.
4. Grab toppings (the station hands you whatever your order needs), drop them
   onto the cheese.
5. Pick the pizza up, put it in the OVEN, and take it out when it is done.
6. Carry it to the SERVE counter.

Dropped items fall with real physics, powered by the Physics Placer add-on's
simulation core (see `scripts/physics_dropper.gd`), so they land on whatever is
underneath them.

## Physics
See `PIZZA_PHYSICS_PLAN.md`.

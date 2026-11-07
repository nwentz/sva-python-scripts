# Pizza Physics Plan

## 1. Baked topping layouts (Physics Placer, editor-time)
Use the Physics Placer dock (Right dock) in the Godot editor:
- Select the pizza mesh (or a "toppings" container node).
- Activate **Drop** / **Shoot** subtool, set the scene colliders as environment.
- Drop cheese/topping instances onto the pizza; let them settle.
- Use the **Bake** action (dock) to write final transforms into the scene.
- Save scene. Runtime then just instances the baked layout.

This gives natural-looking scatter without runtime cost.

## 2. Runtime dough tossing (RigidBody3D)
For gameplay tossing, use a runtime RigidBody3D (not the addon). See
`scripts/pizza_toss.gd` for a minimal toss controller:
- Spawns a dough RigidBody3D above the prep table.
- Applies an impulse + torque on "toss".
- On landing (sleep or collision), freezes and parents to pizza.

Integrate by attaching `pizza_toss.gd` to the PREP_TABLE station node and
calling `toss_dough()` from interaction_controller on the PREP action.

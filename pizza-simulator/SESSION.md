# SESSION.md — Pizza Simulator (Godot 4.7.2)

Date: 2026-11-10
Branch: `A7-Research-Project-1` (repo `nwentz/sva-python-scripts`)
Commit: `6f4d698` — "Refined gameplay and visuals 11-10-26"
Working copy: `C:\Users\nwentz\Downloads\pizza-simulator`
Repo clone: `C:\Users\nwentz\sva-python-scripts\pizza-simulator`

---

## 1. Environment setup

**Godot MCP** was added to `C:\Users\nwentz\.config\opencode\opencode.jsonc`:

```jsonc
"godot": {
  "type": "local",
  "command": ["npx", "-y", "@coding-solo/godot-mcp"],
  "enabled": true,
  "environment": {
    "GODOT_PATH": "C:\\Users\\nwentz\\Downloads\\Godot_v4.7.2-stable_win64.exe"
  }
}
```

Verified: `get_godot_version` → `4.7.2.stable.official.ed1daf0bf`.

The project also ships `addons/godot_mcp_toolkit/` (untracked in git) which provides the
in-editor MCP dock and an `MCPRuntimeServer` autoload registered in `project.godot`.

---

## 2. Final state of the game

### Controls
| Key | Action |
|-----|--------|
| **G** | Grab / interact (dough, sauce, cheese, toppings, prep table, oven, counter) |
| **L** | Drop what you are holding onto the prep table (falls with real physics) |
| **K** | Knead the dough (5 presses, after dropping it on the prep table) |
| **L** (with sauce/cheese) | Start the sauce-spreading or cheese-cutting close-up |
| **C** | Cut/shred the cheese (8 presses, in the cheese close-up) |
| **ESC** | Toggle the mouse; inside a close-up it cancels the minigame and returns to the normal camera |
| WASD / arrows | Move (on-screen D-pad bottom-right also works) |
| SHIFT | Sprint |
| SPACE | Jump |
| ESC | Free the mouse |

`E` was replaced by `G` ("grab"); `D` was rejected for drop because it conflicts with
WASD-right, so **L** is used.

### Gameplay loop
1. **G** at DOUGH station → **L** at prep table → dough falls onto the table
2. **G** at SAUCE → **L** → sauce drops onto the dough
3. **G** at CHEESE → **L** → cheese drops onto the sauce
4. **G** at TOPPINGS → **L** → toppings drop onto the cheese
   (the topping station hands you whichever topping the current order still needs)
5. **G** at prep table picks the pizza up → **G** at OVEN → bakes → **G** again to take it out
6. **G** at SERVE counter → scored

### Station layout (`scenes/main.tscn`)
The whole cooking line runs along the `z = 5` counter and reads left to right
from the player's starting view (the camera looks towards +Z, so +X is on the
left of the screen).

| Station | Position (x, z) |
|---------|-----------------|
| DOUGH | 6.3, 5 |
| SAUCE | 4.8, 5 |
| CHEESE | 3.3, 5 |
| TOPPINGS | 1.8, 5 |
| PREP TABLE | 2.55, 2 (in front of the row) |
| OVEN | 0, 5 |
| COUNTER | -6.3, 5 |

Room is 17 × 9.4, centred on the cooking line (`ROOM_CZ = 1.35`) so the
counters fill the view instead of leaving the player in an empty floor. The
oven and counter are deliberately separated — at their old spacing the counter
blocked the camera ray to the oven.

### Room decorations
`main.gd::_decor()` adds:
- a **checkered tile floor** — a 64×64 brown/white checker drawn once into
  an `ImageTexture` and mapped over a single plane (`uv1_scale` = room size,
  so one repeat is one 1 m tile) instead of hundreds of tile meshes;
- a **door** on the wall behind the player (frame, panel, handle and a lamp);
- **two windows with curtains** on that same wall — frame, emissive sky pane,
  mullions, sill, two curtain panels and a rod;
- a **doormat** and two **potted plants**;
- a tiled **splashback**, a **wall clock**, a **menu board**, a **shelf with
  jars**, **framed pictures** on the side walls and **pendant lamps** over the
  counter row;
- a **drink fridge** on the wall behind the customer (-X), another step away
  at `z = 0.8` and turned to face the same direction as the customer (+X): a
  dark cabinet with shelves of coloured soda cans (grey lids) and capped water
  bottles behind an alpha-blended clear glass door; no collider. The framed
  picture above it was raised one step to `y = 3.0`;
- a **soda can on the round serve table** beside the customer.

Decorations are mesh only — no colliders — so they can never block the player
or the interaction ray.

### Chef costume
`main.gd::_dress_body()` colours the rigged model by mesh name: the torso and
arms become a **white chef's jacket**, the legs **white trousers**, the feet
**black shoes**, while the head, neck and hands keep their skin tone.

`main.gd::_dress_model()` adds the accessories from primitives and parents
them to `BoneAttachment3D`s on the rig, so they follow the walk cycle and the
gestures:
- a **red apron** — bib, a short tapered skirt, shoulder straps that meet in a
  straps that wrap round the neck and meet at the back in a **bunny bow**
  (two loops, two tails and a knot), plus a short waist-style **neck band**
  joining them, replacing the awkward flat bar and the invisible torus, and a
  waist tie that forms
  a **closed loop all the
  way around the shirt**, knotted at the back with a bow and two loose ends;
- a **white chef's hat** (band + puff) and a **dark brown handlebar moustache**
  on the head bone.

The apron skirt deliberately stops just below the hips (bottom at y 0.99).
An earlier full-length panel floated 5–6 cm off the body and was swept through
by the thighs at full stride; the short, tapered skirt sits flush and clears
every leg swing. The skirt top overlaps the bib so no skin shows at the seam.

### Serve area
The serve counter is now a **round pedestal table** (`station.gd`
`_build_round_table()`): a `0.78 m` radius top, a stem and a base, with a
matching cylindrical collision shape. `setup_station()` now rebuilds the node
after `kitchen_init.gd` assigns its kind — previously the station was built
once with the default DOUGH kind, so kind-specific geometry was ignored.

`main.gd::_serve_area()` (called *after* station init, when the counter's kind
is known) adds a full-size wooden **chair** and a **customer** reusing the same
low-poly GLB as the player. The customer is the **same scale as the chef**,
repainted in civilian colours, dropped until its `DEF-spine` hip bone lines up
with the seat, and controlled by `scripts/customer.gd`: bent thighs/shins for
sitting, upper arms in the same lowered rest pose as the chef, and an eating
animation. All serve-area pieces are mesh only.

Serving no longer deletes the pizza. `GameManager.customer_node.eat(p)`
reparents it to a mouth mount on the customer, then over 6 bites (~4.8 s) the
arm lifts it to the mouth, the head nods with each chew, the pizza shrinks to
nothing and is finally freed. (Scripts attached at runtime need an explicit
`set_process(true)` for `_process` to run.)

### Pizza stages
`DOUGH → SAUCED → CHEESED → TOPPED → BAKING → BAKED / BURNT`
(the old `STRETCHED` stage was removed — stretching no longer applies)

Layer heights: dough top `0.07`, sauce top `0.09`, cheese top `0.12`.
Bake target 7 s, burns at `bake_target * 1.9`. While baking, `melt_cheese()`
flattens and spreads the shreds, then fades in a thin, glossy translucent
melted layer. The sauce disc is also thinned as it cooks (its top surface
stays put), so the finished pizza no longer reads as a thick "hat". Burnt
pizzas darken both.

### Kneading minigame
Dropping the dough on the prep table no longer leaves it ready to sauce. The
camera eases into a close-up of the dough (`camera_rig.gd` `focus_on()`), the
HUD shows **"KNEAD THE DOUGH - press K (n/5)"**, and only K is accepted until
it is done (G/L and mouse-look are ignored). The character's movement is frozen
while focused.

`Pizza.knead()` counts the presses. The dough is a `SphereMesh` (radius `0.18`,
height `0.36`) that is scaled outward in X/Z and down in Y on each press;
after 5 presses it matches the `0.35` m, `0.07` m-tall base that the rest of the
game expects. A Tween adds a small squash-and-stretch on each hit. Sauce is
refused until `Pizza.kneaded` is true. Finishing snaps the camera back to the
third-person view so station aiming is never left pointing at the prep table.

Each order now lasts **5 minutes** (`GameManager.ORDER_SECONDS = 300`) instead
of 60 seconds.

### Sauce bottle
The SAUCE station now holds a tapered red **bottle with a white cap** instead
of a plain cylinder, and the held ingredient uses the same shape. Sauce is no
longer a physics drop. Press **L** with the bottle at the prep table to enter a
close-up like the kneading one, then **move the mouse in a circle**. The
controller integrates the angle of a virtual cursor driven by mouse-relative
motion; four full turns now fill the base, so the gesture is slower.
`Pizza.set_sauce_spread()` grows the red
sauce disc from a tiny dot to its full radius, and a small red marker follows
the cursor over the dough. The E key was removed entirely.

### Cheese shredding
Cheese is no longer dropped as a solid disc. Pressing **L** with the cheese at
the prep table starts another close-up; eight presses of **C** call
`Pizza.cut_cheese()`, each scattering five short, thick yellow box "shreds"
(`0.16 × 0.028 × 0.022`) over the sauce at random angles. `add_cheese()` now
just finalises the stage, so toppings still require `CHEESED`. The sauce marker
was also lowered to sit directly on the sauce layer rather than hovering above
the dough. Its orbit was tightened (`SPREAD_MAX_RADIUS 0.16`, step `0.005`) so
the marker stays near the middle, and the shreds were shrunk to
`0.10 × 0.024 × 0.018` and clustered within `DOUGH_RADIUS * 0.45` of the centre.

`Pizza.attach_topping()` now nudges each new topping away from the ones already
on the base until it has a clear spot (min gap `TOPPING_RADIUS * 2`). This
stops a mushroom dropped onto olive/pepperoni from clipping through them; a
headless check measured pairwise gaps of 0.184–0.305 m after three toppings.
The cheese shreds were lowered so their top is exactly `0.12`, matching the
bottom of a topping (`top_y() + TOPPING_HEIGHT/2`), so toppings sit on the
cheese instead of sinking into it.

`camera_rig.clear_focus()` now sets a short mouse-settle window. Without it,
the same circular mouse motions used to spread sauce continued straight into
the orbit camera the moment the close-up ended.

### Customer pose
The customer's upper-arm rest offsets are slightly shallower than the chef's
(`±0.72` instead of `±1.0` about BACK) so its hands no longer sink into the
chair seat. While eating, **both** arms come up to hold the pizza — the right
arm's lift delta is negated because its rest offset has the opposite sign.

### Orders and scoring
Orders are now **count-based**: `GameManager.ORDER_COUNTS` asks for 6 pepperoni,
3 mushroom and 2 olive, and `required` holds one entry per item. The topping
station hands out the next type whose count is still short, `Pizza.toppings`
keeps duplicates, and scoring compares per-type counts (hit = sum of
min(required, placed)). 300 s per order.

`camera_rig` keeps extending `_mouse_settle` while mouse motion continues after
a close-up, so the circles used to spread sauce can no longer spin the orbit
camera once the view returns.

---

## 3. Physics Placer integration (the hard part)

`addons/physics_placer/` is an **editor** tool, but its `PPSim` core only touches editor
APIs behind `Engine.is_editor_hint()` guards, so it can be driven in-game.
New file `scripts/physics_dropper.gd` wraps it.

Getting this working required four separate fixes, each found by instrumentation:

1. **`PhysicsServer3D.set_active()`** — `PPSim._activate_server()` took over the global
   physics server and `_deactivate_server()` deactivated it, which would freeze the whole
   running game. Subclassed as `RuntimeSim`: activate the server, never deactivate it.

2. **No gravity in the bubble** — the sim runs in its own `World3D`, whose space has no
   gravity. Set `use_project_gravity = false` + `gravity_direction = DOWN` +
   `gravity_magnitude = 9.8` so `PPSim` installs an explicit gravity override area.
   (`PhysicsServer3D.space_set_gravity()` does not exist in Godot 4.7.)

3. **Body slept before falling** — a body that starts at rest is judged "settled" and
   put to sleep before gravity acts. Fixed with `body.can_sleep = false` and by driving
   the settling with `stop_when_settled = true` / `sleep_settled = false`.

4. **The dropped item rested on a copy of itself** — `PPSim.build_environment()` bakes the
   scene's colliders into the bubble, including the dropped node's own collider.
   `PPSim` excludes by node, but the exclusion did not cover nested shapes.

**Final approach:** rather than fight `build_environment()`'s scene scan, the dropper now
builds the bubble's collision world **explicitly** from a list of surfaces declared by the
caller (`PhysicsDropper.Surface.box()` / `.cyl()`). The caller passes the prep table top,
the room floor, and (for toppings) the pizza's current top layer. This is deterministic:
an item lands on exactly the declared surfaces and nothing else.

---

## 4. Key bugs found and fixed

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| No movement, pill-shaped body | `scenes/character.tscn` failed to parse — the script `ExtResource` had no matching `[ext_resource]` entry, so `main.gd` silently fell back to building a plain capsule with no movement script | Added the missing `[ext_resource]`; removed the capsule mesh |
| Character rendered but unphysical | I wrote a **singular** `Transform3D` (z-column `(0,1,0)` instead of `(0,0,1)`); Jolt rejected every physics transform | Corrected the basis to identity rotation |
| Stations rendered outside the room | `main.tscn` gave every station's Mesh/Collision child the *same world transform as its parent* — all geometry was at double its intended offset | Rewrote `main.tscn` with plain nodes; the script builds its own mesh at local origin |
| Camera was first-person | The rig looked for a node named `SpringArm3D` but `main.gd` named it `CameraArm`, so the arm never excluded the character and collapsed to zero length | Rewrote the rig as a deterministic third-person orbit at 3.2 units behind |
| Character could leave the room | No boundary | Clamped in `character.gd` (`BOUNDS_X`, `BOUNDS_Z_MIN/MAX`) and in `camera_rig.gd` |
| "E doesn't grab toppings" | The interaction ray originated at the camera, 3.2 units *behind* the player, and the stations are only 0.8 m tall — the ray sailed over them. My first fix (a 30° cone) then picked the *wrong* station, because all stations sit in one row | Ray re-aimed at countertop height + **screen-space picking** (station whose centre projects closest to screen centre wins) |
| Every interaction threw an error | `interaction_controller.gd` called `c.project(...)` — no such method on `Camera3D`. It aborted the handler before the pickup logic ran | Replaced with a 3D marker sphere at the hit point |
| `st.kind` was null | `interaction_controller.gd` read `st.kind`, but `KitchenStation` only had a `metadata` dict | Added `kind` / `label` / `ingredient` properties |
| Pizza could never leave the oven | `Pizza.bake()` reset a `BAKED` pizza back to `BAKING` every frame, restarting the timer forever | `BAKED` is now a terminal state |
| Dropped items did not fall | See section 3 | See section 3 |
| `Label3D.z_index` error | Not a valid property in Godot 4 | Changed to `render_priority` |
| `GPUParticles3D.emission_rate` error | Not a valid property | Removed; used `process_material.emission_shape` instead |
| Project would not run after deleting `.godot` | Assets needed re-importing | `godot --headless --import <project.godot>` |
| Character sank into the outer counters when walking along the side wall | The movement clamp (`x ±7.2`, `z ≤5.4`) was *wider* than the station footprint, so after `move_and_slide` shoved the capsule out of a counter, the clamp teleported it straight back in | Tightened both `character.gd` and `camera_rig.gd` to `x ±6.6` / `z ≤4.0` — the capsule radius (0.3) short of the counter edges. Also fixed `kitchen_init.gd`, which still placed the serve counter at `x +6` while `main.tscn` has it at `x −6.3` |
| Carried pizza clipped through the serve counter | It was held nearly vertical (`rotation −72°`) at chest height, so its near edge dipped below the 1.1 m counter top | Carry pose is now `(0, 1.40, −0.45)` with `−30°` tilt, keeping the lowest point above every counter top |
| Chef hat filled the kneading close-up | The focus camera sat just behind the player at the same height as the white chef hat, so the hat occluded the dough | Focus camera now sits in front of and above the player (`focus_point + (0, 1.55, −0.85)`), looking steeply down; station labels are hidden during the close-up too |
| Toppings floated above the pizza after pickup | The drop surface cylinder was *centred* on the pizza's top layer, so its top face was 4 cm higher than the real base; the prep-table surface was also slightly above the pizza | The cylinder centre is now `top_y − height/2` so its top face matches the pizza, and the table surface is omitted whenever a pizza is on the table. `Pizza.attach_topping()` also snaps every topping flat onto the surface (and clamps it inside the base), so a tilted or high drop can never leave the olive hovering |

---

## 5. Verification method (important for future work)

A throwaway `capture.gd` was used as an **autoload** to drive and screenshot the game
headlessly. Add to `project.godot` temporarily:

```ini
[autoload]
Capture="*res://capture.gd"
```

The script:
- injects key events with `Input.parse_input_event()` (note: the event is processed on the
  **next** frame, so wait 2 frames before asserting)
- positions the player and aims the camera with `rig.set("yaw", atan2(-dir.x, -dir.z))`
- saves screenshots with `get_viewport().get_texture().get_image().save_png("user://shot.png")`
  (lands in `%APPDATA%/Godot/app_userdata/Pizza Simulator/`)
- was **removed** before the final commit

A full automated playthrough asserted all 13 steps and ended with `score=70, served=1`.

**Debugging pattern that worked:** when something looked wrong, write a script that dumps
the actual runtime state (positions, collider shapes, env contents) rather than guessing.
Several rounds of guessing were wasted before switching to instrumentation.

---

## 6. Files changed in commit `6f4d698`

```
pizza-simulator/GAME_GUIDE.md                       (new controls + flow)
pizza-simulator/README.md                           (gameplay section)
pizza-simulator/scenes/character.tscn               (fixed basis, GLB-friendly)
pizza-simulator/scenes/main.tscn                    (rewritten, correct transforms)
pizza-simulator/scripts/camera_rig.gd              (third-person, clamped)
pizza-simulator/scripts/character.gd                (bounds, ui_input)
pizza-simulator/scripts/hud.gd                      (key hints, stage names)
pizza-simulator/scripts/interaction_controller.gd   (G/L flow, targeting)
pizza-simulator/scripts/kitchen_init.gd             (station positions)
pizza-simulator/scripts/main.gd                     (GLB char, D-pad)
pizza-simulator/scripts/physics_dropper.gd          NEW - Physics Placer wrapper
pizza-simulator/scripts/physics_dropper.gd.uid      NEW
pizza-simulator/scripts/pizza.gd                    (layered build, bake states)
pizza-simulator/scripts/station.gd                  (grey stations, props)
```

Deliberately **excluded** from the commit:
- `addons/godot_mcp_toolkit/` — untracked on this branch (it is a third-party addon)
- `capture.gd.uid` — leftover from the temp test harness
- `__pycache__/` — unrelated Python bytecode

---

## 7. Known issues / not done

- The character model has no walk animation; the rigged `Low-Poly Character.glb` is tinted
  flat skin colour and posed in its rest/T-pose.
- The GLB is tinted uniformly via surface overrides in `main.gd::_tint_skin()`.
- `scenes/pizza.tscn` and `scripts/pizza_toss.gd` still exist but are unused by the new
  flow (`Pizza` is instantiated in code).
- The dropped topping mesh lands wherever physics puts it, but the sauce/cheese layers are
  full-disc meshes that snap to the pizza rather than keeping the drop pose.
- `GameManager` autoload UID is referenced as `uid://dj84sgqt4m5h7` in `project.godot`.
- `__pycache__/` remains untracked in the repo root; consider adding it to `.gitignore`.

---

## 8. Bug fix round: "first person camera" + "pizza won't go in the oven"

Reported symptoms:
1. *The character sometimes switches to a first person view while moving.*
2. *A pizza cannot be cooked in the oven - it just spawns back on the prep table.*

### Root causes (found by instrumenting the running game, see §5)

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| First person camera | `camera_rig.gd` clamped the camera's **global** position to the room bounds. Writing a global position on a child node rewrites its **local** offset, so the boom between rig and camera was permanently shortened every time the camera touched a wall - the camera collapsed into the character (distance 0.61 instead of 3.2) and stayed there. | The rig now only writes the camera's **local** position. When the camera would leave the room the *boom length* is shortened (never below 1.8) so the camera always stays behind the character. The character bounds were tightened (`x ±5.0`, `z ±6.4`) so the boom rarely has to shrink at all. |
| Pizza won't go in the oven | The carried pizza has its own collider, and the interaction ray starts at the camera *behind* the player - so the ray hit the pizza in the player's hands and the game fell back to screen-space picking. That fallback also considered stations **behind** the camera (their mirrored projection lands near the crosshair), so the prep table behind the player could win. The hint then said *"Drop the dough on the table with L"*, and L always drops onto the prep table - hence "it spawns back to the prep table". | The interaction ray now excludes the player **and everything they carry**. Stations behind the camera are skipped. The crosshair position now decides between stations that are in a row (the ray often grazes the corner of the nearer counter). |
| Oven / pizza glow missing | `StandardMaterial3D.emissive` does not exist in Godot 4 (it is `emission` + `emission_enabled`) - every frame logged *"remapped parameter not found: emissive"*. | `station.gd` and `pizza.gd` now use `emission_enabled` / `emission`. |

### Regression test

`tests/flow_test.gd` (+ `tests/flow_test.tscn`) drives the whole game headlessly:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path <project> res://tests/flow_test.tscn
```

It checks that

* the camera never ends up in front of the character, never drops below the
  floor and never leaves the room (40 position/yaw combinations),
* every station can be reached **and** picked: DOUGH, SAUCE, CHEESE, TOPPINGS,
  PREP TABLE, OVEN, SERVE, and
* the full order still works: dough → sauce → cheese → toppings → prep table →
  **oven** → baked → serve (score 92, served 1), and
* the oven is picked as the target while the player carries a pizza.

---

## 9. Follow-up: "I can't reach the dough station"

The fix in §8 tightened the character bounds to `x ±5.0` to keep room for the
camera boom. That was too aggressive: the DOUGH station sits at **x = -6**, so
the player could no longer walk up to it.

The camera was then rebuilt so the two constraints no longer fight each other:

| Problem | Fix |
|---------|-----|
| Camera had to fit behind the player, which restricted where the player could walk | The **camera** now yields, not the player. The boom is shortened along its own axis (never sideways) when a wall is in the way, and the character keeps its own generous bounds (`x ±7.2`, `z ±8.0`) so every station stays reachable. |
| Camera could end up outside the room (showing the inside of a wall) | The boom is clamped so the camera stays inside the room, and the room was grown from 16×18 to **18×20** to give the camera and the player more space. |
| Camera dipped into the back of the player's head when squeezed against a wall | When the boom gets short the camera **lifts** (up to 0.9) and **tilts down** (up to 32°) so it looks over the shoulder instead of clipping into the character. |

### A second bug found along the way

`interaction_controller.gd::_next_topping()` used
`var have: Array[String] = placed.toppings if placed != null else []`.
The ternary produced an untyped `Array`, so the assignment threw
*"Trying to assign an array of type Array to a variable of type Array[String]"*
whenever the topping station was used with no pizza on the prep table.
Replaced with `have.assign(placed.toppings)`.

---

## 10. The oven got a real model

`models/Pizza-Oven.glb` (from `Downloads/`) replaces the grey box that used to
stand in for the oven.

### The model

A professional range with two drawer ovens and a worktop on top. It arrives
with odd baked-in scales - the body ends up **4.86 x 3.58 x 7.91** in world
units - and its front (the drawer handles) faces **+X**.

### How it is fitted

`KitchenStation` can now use a model instead of the generated box:

```gdscript
station.setup_model("res://models/Pizza-Oven.glb", Vector3(1.5, 1.0, 0.9), 90.0)
```

`setup_model(path, size, yaw_deg)` scales the model so it fills the station's
footprint (width, height, depth), turns it by `yaw_deg` so the front faces
the room, and places it with its base on the floor and centred on the station.
The scale is derived from the model's own bounding box, so it adapts if the
GLB is re-exported.

The oven station is 1.5 wide, 1.0 tall and 0.9 deep; the collision box, the
label height and the pizza anchor all follow from that, so the pizza rests on
the worktop at y = 1.02.

### Art direction

The GLB is untextured plain white, which looked like a blank slab next to the
flat-shaded counters. `KitchenStation._apply_model_materials()` now tints the
model: the body takes the station's colour (dark steel for the oven) and the
handles are a shade brighter and metallic, so the shape still reads.

### Baking glow

`StandardMaterial3D.emissive` does not exist in Godot 4 (it is `emission` +
`emission_enabled`) - every frame logged *"remapped parameter not found:
emissive"*. Fixed in `station.gd` and `pizza.gd`. The glow is now applied to
the **model's** materials while the pizza bakes.

---

## 11. Backwards labels and "is it cooking?"

### The labels on the far wall read backwards

`Label3D` faces **+Z** by default. The counter row (dough ... prep table) sits
at z = -5.2 and is looked at from +Z, so those labels were fine - but the
oven and the serve counter are at z = +5 and are looked at from **-Z**, so
their text was mirrored ("OVEN" rendered as "ИƎVO").

`KitchenStation._facing()` now works out the direction from the station
towards the middle of the kitchen and turns the label (and its offset) to
face that way, so every label is readable from the room.

### Making it obvious that the pizza is cooking

Three things now happen while a pizza is in the oven:

| Cue | Where |
|-----|-------|
| The oven glows orange (pulsing) and a warm light spills into the room | `station.gd::_set_effects()` |
| Smoke rises from the pizza and fades out | `station.gd` + `scripts/fx.gd` |
| A HUD line shows the oven status and a countdown | `hud.gd::_update_oven()` |

```
OVEN: cooking... 6 s to pull it out     (orange)
OVEN: pizza is ready - press G at the oven to take it out   (green)
OVEN: BURNT! Press G at the oven to take it out              (red)
```

### A third broken effect

`GPUParticles3D` draws **nothing** unless it has a mesh to draw. Both the
oven smoke and the burnt-pizza smoke were created without a draw pass, so
neither was ever visible. `scripts/fx.gd` (`Fx.make_smoke()`) now builds the
particles with a soft, billboarded quad and a fade-out ramp, and both the
oven and the pizza use it.





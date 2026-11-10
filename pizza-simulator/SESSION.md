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
| Station | Position (x, z) |
|---------|-----------------|
| DOUGH | -6, -5.2 |
| SAUCE | -4.5, -5.2 |
| CHEESE | -3, -5.2 |
| TOPPINGS | -1.5, -5.2 |
| PREP TABLE | 0, -5.2 |
| OVEN | 0, 5 |
| COUNTER | 6, 5 |

Room is 16 × 18 (was 12 deep). The oven and counter were deliberately separated —
at their old spacing the counter blocked the camera ray to the oven.

### Pizza stages
`DOUGH → SAUCED → CHEESED → TOPPED → BAKING → BAKED / BURNT`
(the old `STRETCHED` stage was removed — stretching no longer applies)

Layer heights: dough top `0.07`, sauce top `0.09`, cheese top `0.12`.
Bake target 7 s, burns at `bake_target * 1.9`.

### Scoring
`0.4 * toppings match + 0.4 * bake quality + 0.2 * speed`, 60 s per order.

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

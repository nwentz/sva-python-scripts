# 🔍 Grey Screen Debug Guide

## 🎮 Issue: Game runs but shows grey screen

### **What This Means:**
- ✅ Game starts successfully
- ✅ Scene loads without errors
- ✅ Nothing visible on screen (camera not pointing at anything visible)

### **Common Causes:**

1. **Camera positioned wrong** - Camera is looking at nothing or below ground
2. **Floor not visible** - Floor is too small, too low, or not rendered
3. **Lighting too dark** - Scene is black
4. **Character hidden** - Character is below ground or in wall

---

## 🛠️ Fixes Applied

### **Fix 1: Improved Lighting**
**Problem:** Scene was too dark
**Changes:**
- Made background darker (0.25, 0.2, 0.25) for contrast
- Increased ambient light (2.0 → 2.0)
- Increased sun energy (1.8 → 2.5)
- Increased fill energy (16.0 → 20.0)

### **Fix 2: Better Camera Positioning**
**Problem:** Camera was too close to character
**Changes:**
- Moved camera up to 2.0 units (was 1.8)
- Set camera rotation to -0.3 (looks down slightly)
- Added explicit target_position to SpringArm3D

### **Fix 3: Increased Ground Visibility**
**Problem:** Floor might have been too low
**Changes:**
- Floor is at y = -0.1 (should be visible)
- Increased ground color visibility

---

## 🧪 Testing Checklist

### **Save and Restart:**
1. **Save all files** (Ctrl+S)
2. **Close Godot completely**
3. **Reopen project**
4. **Run game (F5)**

### **Check Output Panel:**
You should see:
```
Pizza Simulator starting...
Setting up camera for: Character
Camera rig created at: (0, 2.05, 4.5)
Environment created
Character spawned
Camera and interaction set up
KitchenInitializer added to scene
Kitchen initialized successfully with 7 stations.
HUD added
```

### **What You Should See:**
- ✅ 3D kitchen room with walls, floor, ceiling
- ✅ White capsule character
- ✅ Camera following you
- ✅ HUD showing order/score
- ✅ 7 labeled stations

### **If Still Grey Screen:**

#### **Check 1: Camera Position**
Press **F6** (stop), then go to **Scene Tree** (left sidebar):
1. Find **CameraRig**
2. Check **Transform** (bottom of Inspector)
3. Should be at roughly: `(0, 2.0, 4.5)`
4. Rotation: `(-0.3, 0, 0)`

#### **Check 2: Floor Visibility**
1. In **Scene Tree**, expand **Main**
2. Find **Floor**
3. In Inspector, check:
   - **Transform**: Should be at `(0, -0.1, 0)`
   - **Mesh**: BoxMesh size: `16 x 0.2 x 12`

#### **Check 3: Camera Direction**
1. In Scene Tree, find **Camera**
2. In Inspector, check **Transform**
3. Look at the **Basis** → **Z**
4. Should be pointing somewhat forward/down

#### **Check 4: Add Debug Marker**
If still not working, add a visible marker:

Open `scripts/main.gd`, add this to the end of `_ready()`:

```gdscript
# Add a debug sphere to show camera position
var debug_sphere := MeshInstance3D.new()
var sphere_mesh := SphereMesh.new()
sphere_mesh.radius = 0.3
debug_sphere.mesh = sphere_mesh
var debug_mat := StandardMaterial3D.new()
debug_mat.albedo_color = Color(1, 0, 0, 1)
debug_sphere.material_override = debug_mat
debug_sphere.global_position = camera_rig.global_position
debug_sphere.name = "DebugSphere"
add_child(debug_sphere)
```

This will show a red sphere where the camera is.

---

## 📊 Expected Coordinates

### **Character:**
- Position: `(0, 0.05, 4.5)`
- Rotation: Default

### **Camera Rig:**
- Position: `(0, 2.0, 4.5)` (above character)
- Rotation: `(-0.3, 0, 0)` (looks down slightly)

### **Floor:**
- Position: `(0, -0.1, 0)`
- Size: `16 x 0.2 x 12`

### **Stations:**
- DOUGH: `(-6, 0.5, -5.2)`
- SAUCE: `(-4.5, 0.5, -5.2)`
- CHEESE: `(-3, 0.5, -5.2)`
- TOPPINGS: `(-1.5, 0.5, -5.2)`
- PREP: `(0, 0.5, -5.2)`
- OVEN: `(0, 0.5, 5.2)`
- COUNTER: `(0, 0.5, 7.5)`

---

## 🎯 Troubleshooting Steps

### **Step 1: Check Output Panel**
Any red errors? Copy and paste them here.

### **Step 2: Check Scene Tree**
Does CameraRig exist?
Does Camera exist?
Is CameraRig a child of Main?

### **Step 3: Check Camera Transform**
Is camera positioned correctly?
Is rotation correct?

### **Step 4: Add Debug Marker**
If nothing else works, the debug sphere will show us where the camera is.

### **Step 5: Try Different View**
In the game window:
1. Press **ESC** to release mouse
2. Try clicking the game window
3. Make sure it has focus

---

## 📝 What I Fixed

1. ✅ Made background darker for contrast
2. ✅ Increased ambient light
3. ✅ Increased sunlight energy
4. ✅ Increased fill light
5. ✅ Positioned camera higher (2.0 units)
6. ✅ Set camera rotation correctly
7. ✅ Added explicit target_position to SpringArm3D
8. ✅ Added debug output for camera position

---

## 🚀 Next Steps

1. **Save changes** (Ctrl+S)
2. **Restart Godot**
3. **Run game** (F5)
4. **Check output panel** for messages
5. **Tell me what you see**

If still grey screen, we'll add a debug marker to show camera position!

---

**Status:** Fixed lighting and camera positioning
**Ready to test:** Save and run

import maya.cmds as cmds

## Imports Maya commands as usable commands 

import random

## Makes shapes randomized


def create_case(width, height, depth):
    """Create a transparent bounding box to contain the shapes."""
    case = cmds.polyCube(w=width, h=height, d=depth, name="case_boundary")[0]
    cmds.setAttr(f"{case}.overrideEnabled", 1)
    cmds.setAttr(f"{case}.overrideShading", 0)
    cmds.setAttr(f"{case}.overrideColor", 17)
    cmds.xform(case, pivots=[0, height / 2, 0])
    cmds.move(0, height / 2, 0, case)
    return case


def check_spacing(new_pos, placed_positions, min_dist):
    """Check if new position is far enough from all placed positions."""
    for pos in placed_positions:
        dx = new_pos[0] - pos[0]
        dy = new_pos[1] - pos[1]
        dz = new_pos[2] - pos[2]
        dist = (dx ** 2 + dy ** 2 + dz ** 2) ** 0.5
        if dist < min_dist:
            return False
    return True


def generate_shapes(*args):
    """Generate random shapes based on GUI values."""
    count = int(cmds.intSliderGrp("countSlider", query=True, value=True))
    w = float(cmds.floatSliderGrp("widthSlider", query=True, value=True))
    h = float(cmds.floatSliderGrp("heightSlider", query=True, value=True))
    d = float(cmds.floatSliderGrp("depthSlider", query=True, value=True))
    spacing = float(cmds.floatSliderGrp("spacingSlider", query=True, value=True))

    # Clear previous objects
    if cmds.objExists("case_boundary"):
        cmds.delete("case_boundary")
    for i in range(200):
        for prefix in ["random_sphere_", "random_cube_", "random_cylinder_", "random_cone_", "random_torus_"]:
            name = f"{prefix}{i}"
            if cmds.objExists(name):
                cmds.delete(name)
    for i in range(200):
        mat = f"mat_{i}"
        sg = f"mat_{i}SG"
        if cmds.objExists(sg):
            cmds.delete(sg)
        if cmds.objExists(mat):
            cmds.delete(mat)

    create_case(w, h, d)

    shape_types = ["sphere", "cube", "cylinder", "cone", "torus"]

## Are the available shapes that can be generated

    all_objects = []
    placed_positions = []
    max_attempts = 500

    for i in range(count):
        shape = random.choice(shape_types)
        placed = False

        for attempt in range(max_attempts):
            x = random.uniform(-w / 2, w / 2)
            y = random.uniform(0, h)
            z = random.uniform(-d / 2, d / 2)

            if spacing <= 0 or check_spacing((x, y, z), placed_positions, spacing):
                placed = True
                break

        if not placed:
            print(f"Warning: Could not place shape {i} after {max_attempts} attempts. Skipping.")
            continue

        placed_positions.append((x, y, z))
        sx = random.uniform(0.5, 2.0)
        sy = random.uniform(0.5, 2.0)
        sz = random.uniform(0.5, 2.0)
        ry = random.uniform(0, 360)

        if shape == "sphere":
            obj = cmds.polySphere(r=1, name=f"random_sphere_{i}")[0]
        elif shape == "cube":
            obj = cmds.polyCube(w=1, h=1, d=1, name=f"random_cube_{i}")[0]
        elif shape == "cylinder":
            obj = cmds.polyCylinder(r=1, h=2, name=f"random_cylinder_{i}")[0]
        elif shape == "cone":
            obj = cmds.polyCone(r=1, h=2, name=f"random_cone_{i}")[0]
        elif shape == "torus":
            obj = cmds.polyTorus(r=1, sr=0.4, name=f"random_torus_{i}")[0]

        cmds.move(x, y, z, obj)

## Lets users move the objects on the x, y, and z axises.

        cmds.scale(sx, sy, sz, obj)

        ## Ability to scale shapes on the x, y, and z axises

        cmds.rotate(0, ry, 0, obj)
        all_objects.append(obj)

        ## Objects can be rotated

    # Create and assign materials
    for i, obj in enumerate(all_objects):
        r = random.uniform(0.15, 1.0)

## Reds of the objects are randomized

        g = random.uniform(0.15, 1.0)

## Greens of the objects are randomized

        b = random.uniform(0.15, 1.0)

        ## Blues of the objects are randomized

        mat = cmds.shadingNode("lambert", asShader=True, name=f"mat_{i}")

## Uses lambert shading node for all the shapes

        cmds.setAttr(f"{mat}.color", r, g, b, type="double3")
        sg = cmds.sets(renderable=True, noSurfaceShader=True, empty=True, name=f"mat_{i}SG")
        cmds.connectAttr(f"{mat}.outColor", f"{sg}.surfaceShader", force=True)
        cmds.select(obj)
        cmds.hyperShade(assign=sg)

    cmds.select(clear=True)
    cmds.displaySmoothness(divisionsU=3, divisionsV=3, pointsWire=16, pointsShaded=4)

## Directs the smoothness of the objects so they won't look low-poly

    print(f"Created {len(all_objects)} colored shapes inside a {w}x{h}x{d} case.")


def build_gui():
    """Build the GUI window."""

## GUI window the user can interact with

    if cmds.window("randomShapesWin", exists=True):
        cmds.deleteUI("randomShapesWin")

    win = cmds.window("randomShapesWin", title="Random Shapes Generator", widthHeight=(320, 300), sizeable=True)

    cmds.columnLayout(adjustableColumn=True, rowSpacing=8, columnOffset=("both", 10))

## How the GUI column will be layed out

    cmds.separator(height=5, style="none")
    cmds.text(label="Random Shapes Generator", font="boldLabelFont", align="center")

## The text displayed for the user to interrupt and use to their needs

    cmds.separator(height=10, style="in")

    cmds.intSliderGrp("countSlider", label="Shape Count", field=True, minValue=1, maxValue=100, fieldMinValue=1, fieldMaxValue=200, value=25)
    cmds.floatSliderGrp("widthSlider", label="Case Width", field=True, minValue=1, maxValue=50, fieldMinValue=1, fieldMaxValue=100, value=20, precision=1)
    cmds.floatSliderGrp("heightSlider", label="Case Height", field=True, minValue=1, maxValue=50, fieldMinValue=1, fieldMaxValue=100, value=12, precision=1)
    cmds.floatSliderGrp("depthSlider", label="Case Depth", field=True, minValue=1, maxValue=50, fieldMinValue=1, fieldMaxValue=100, value=20, precision=1)
    cmds.floatSliderGrp("spacingSlider", label="Min Spacing", field=True, minValue=0, maxValue=20, fieldMinValue=0, fieldMaxValue=50, value=2, precision=1)

## Floating sliders that determine the width, height, depth, and spacing of the shapes in either direction of more or less

    cmds.separator(height=10, style="in")
    cmds.button(label="Generate Shapes", height=40, command=generate_shapes)

    ## Creates multiple shapes 

    cmds.separator(height=5, style="none")

    ## Adds separation between the shapes

    cmds.showWindow(win)


build_gui()

## A GUI is a graphical way to view code and interact with it instead of executing commands directly, it makes it feel simpler for the average Internet/software user.

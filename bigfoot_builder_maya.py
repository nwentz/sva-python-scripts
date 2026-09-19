# ============================================================
# BIGFOOT BUILDER for Autodesk Maya (2022-2027) - SCULPT VERSION
# Reference: classic upright Sasquatch - conical sagittal crest,
#   heavy brow / deep-set eyes, stern mouth, no neck, massive traps,
#   barrel chest, very long arms to knees, huge flat feet (namesake),
#   dark brown shaggy fur, mid-stride walking pose.
#
# NO RIG - static sculpt base with FLAT LAMBERT colors. No textures,
# no displacement, no fur system. Fur parts = fur color, face/hands/feet
# = skin color. Pick colors > Apply Preset > BUILD.
#
# HOW TO USE IN MAYA:
# 1. Windows > General Editors > Script Editor > Python tab
# 2. Open this file, press Ctrl+Enter
# 3. Window "Bigfoot Builder" appears
# 4. Pick a Preset - the model builds itself, then updates live as you
#    drag any slider. No build button.
#
# Output:
#   Bigfoot_GRP - all meshes (torso / head / face detail / limbs / feet)
#   Flat lamberts: bigfoot_fur_MAT, bigfoot_skin_MAT, bigfoot_dark_MAT,
#   bigfoot_nose_MAT, bigfoot_lips_MAT, bigfoot_nails_MAT, bigfoot_toes_MAT.
# ============================================================

try:
    import maya.cmds as cmds
    import maya.mel as mel
    MAYA = True
except Exception:
    MAYA = False
    class _Dummy(object):
        def __getattr__(self, a):
            def _f(*x, **k):
                return None
            return _f
    cmds = _Dummy()
    mel = _Dummy()

import random
import time

WIN = "bigfootBuilderWin"
UI = {}
MAT = {}

# ------------------------------------------------------------
# PRESETS - tuned to the reference image
# ------------------------------------------------------------
PRESETS = {
    "Reference Classic (image)": {
        "height": 7.6, "bulk": 1.25, "belly": 0.45, "chestW": 1.30,
        "shoulderW": 1.35, "hunch": 0.55, "neck": 0.20,
        "headSize": 1.05, "crestH": 0.85, "crestW": 0.90, "brow": 0.85,
        "eyeSize": 0.65, "eyeDepth": 0.70, "noseW": 1.10, "muzzle": 0.35,
        "jawW": 1.05, "beard": 0.60,
        "armL": 1.28, "upperArm": 1.15, "forearm": 1.25,
        "handSize": 1.20, "fingerL": 1.00, "fingerT": 1.15,
        "legL": 1.00, "thigh": 1.20, "calf": 1.05,
        "footL": 1.60, "footW": 1.25, "toeL": 1.00,
        "muscle": 0.65, "wrinkles": 0.75, "furClump": 0.60,
        "furColor": (0.16, 0.13, 0.10), "skinColor": (0.30, 0.25, 0.20),
        "greyAmt": 0.15, "furLength": 0.70, "furDensity": 0.80,
        "chestBald": 0.55, "rough": 0.95,
        "stance": 0.55, "kneeBend": 0.35, "elbowBend": 0.20,
        "headPitch": 0.25, "walkPose": 0.65,
    },
    "Alpha Brute (bigger)": {
        "height": 8.4, "bulk": 1.55, "belly": 0.60, "chestW": 1.50,
        "shoulderW": 1.55, "hunch": 0.60, "neck": 0.15,
        "headSize": 1.12, "crestH": 1.00, "crestW": 1.00, "brow": 1.00,
        "eyeSize": 0.60, "eyeDepth": 0.80, "noseW": 1.20, "muzzle": 0.40,
        "jawW": 1.20, "beard": 0.75,
        "armL": 1.32, "upperArm": 1.35, "forearm": 1.45,
        "handSize": 1.35, "fingerL": 1.05, "fingerT": 1.30,
        "legL": 1.02, "thigh": 1.40, "calf": 1.25,
        "footL": 1.70, "footW": 1.35, "toeL": 1.05,
        "muscle": 0.90, "wrinkles": 0.70, "furClump": 0.65,
        "furColor": (0.12, 0.10, 0.08), "skinColor": (0.28, 0.23, 0.18),
        "greyAmt": 0.05, "furLength": 0.85, "furDensity": 0.90,
        "chestBald": 0.50, "rough": 0.95,
        "stance": 0.60, "kneeBend": 0.38, "elbowBend": 0.25,
        "headPitch": 0.28, "walkPose": 0.60,
    },
    "Lean Juvenile": {
        "height": 6.6, "bulk": 0.95, "belly": 0.25, "chestW": 1.05,
        "shoulderW": 1.10, "hunch": 0.45, "neck": 0.30,
        "headSize": 1.00, "crestH": 0.55, "crestW": 0.80, "brow": 0.55,
        "eyeSize": 0.80, "eyeDepth": 0.45, "noseW": 0.95, "muzzle": 0.30,
        "jawW": 0.90, "beard": 0.30,
        "armL": 1.20, "upperArm": 0.90, "forearm": 0.95,
        "handSize": 1.00, "fingerL": 0.95, "fingerT": 0.90,
        "legL": 1.05, "thigh": 0.95, "calf": 0.90,
        "footL": 1.40, "footW": 1.10, "toeL": 0.95,
        "muscle": 0.40, "wrinkles": 0.35, "furClump": 0.45,
        "furColor": (0.22, 0.18, 0.13), "skinColor": (0.34, 0.28, 0.22),
        "greyAmt": 0.0, "furLength": 0.55, "furDensity": 0.70,
        "chestBald": 0.60, "rough": 0.92,
        "stance": 0.50, "kneeBend": 0.30, "elbowBend": 0.18,
        "headPitch": 0.20, "walkPose": 0.55,
    },
    "Elder Grey": {
        "height": 7.4, "bulk": 1.15, "belly": 0.65, "chestW": 1.20,
        "shoulderW": 1.25, "hunch": 0.75, "neck": 0.20,
        "headSize": 1.05, "crestH": 0.80, "crestW": 0.90, "brow": 0.90,
        "eyeSize": 0.60, "eyeDepth": 0.75, "noseW": 1.10, "muzzle": 0.35,
        "jawW": 1.00, "beard": 0.85,
        "armL": 1.28, "upperArm": 1.05, "forearm": 1.10,
        "handSize": 1.20, "fingerL": 1.00, "fingerT": 1.10,
        "legL": 0.96, "thigh": 1.10, "calf": 1.00,
        "footL": 1.60, "footW": 1.25, "toeL": 1.00,
        "muscle": 0.45, "wrinkles": 1.00, "furClump": 0.75,
        "furColor": (0.28, 0.26, 0.24), "skinColor": (0.36, 0.30, 0.25),
        "greyAmt": 0.85, "furLength": 0.90, "furDensity": 0.75,
        "chestBald": 0.55, "rough": 0.98,
        "stance": 0.55, "kneeBend": 0.45, "elbowBend": 0.30,
        "headPitch": 0.35, "walkPose": 0.40,
    },
    "Female (slimmer)": {
        "height": 7.0, "bulk": 1.00, "belly": 0.35, "chestW": 1.05,
        "shoulderW": 1.10, "hunch": 0.45, "neck": 0.30,
        "headSize": 0.95, "crestH": 0.55, "crestW": 0.80, "brow": 0.55,
        "eyeSize": 0.75, "eyeDepth": 0.50, "noseW": 0.95, "muzzle": 0.28,
        "jawW": 0.90, "beard": 0.30,
        "armL": 1.22, "upperArm": 0.90, "forearm": 0.95,
        "handSize": 1.00, "fingerL": 1.00, "fingerT": 0.90,
        "legL": 1.05, "thigh": 1.00, "calf": 0.95,
        "footL": 1.40, "footW": 1.10, "toeL": 0.95,
        "muscle": 0.45, "wrinkles": 0.45, "furClump": 0.55,
        "furColor": (0.19, 0.15, 0.11), "skinColor": (0.32, 0.27, 0.21),
        "greyAmt": 0.10, "furLength": 0.75, "furDensity": 0.85,
        "chestBald": 0.50, "rough": 0.94,
        "stance": 0.50, "kneeBend": 0.32, "elbowBend": 0.20,
        "headPitch": 0.22, "walkPose": 0.60,
    },
}

# ------------------------------------------------------------
# UI helpers
# ------------------------------------------------------------
def _get_f(name, default=1.0):
    try:
        return cmds.floatSliderGrp(UI[name], q=True, v=True)
    except Exception:
        return default

def _get_chk(name, default=0):
    try:
        return cmds.checkBox(UI[name], q=True, v=True)
    except Exception:
        return default

def _get_opt(name, default=""):
    try:
        return cmds.optionMenu(UI[name], q=True, v=True)
    except Exception:
        return default

def _get_col(name, default=(0.5, 0.5, 0.5)):
    try:
        return cmds.colorSliderGrp(UI[name], q=True, rgbValue=True)
    except Exception:
        return default

def _set_f(name, val):
    if name in UI and cmds.floatSliderGrp(UI[name], ex=True):
        cmds.floatSliderGrp(UI[name], e=True, v=val)

def _set_col(name, val):
    if name in UI and cmds.colorSliderGrp(UI[name], ex=True):
        cmds.colorSliderGrp(UI[name], e=True, rgbValue=(val[0], val[1], val[2]))

def _set_opt(name, val):
    if name in UI and cmds.optionMenu(UI[name], ex=True):
        items = cmds.optionMenu(UI[name], q=True, ill=True) or []
        labels = [cmds.menuItem(i, q=True, l=True) for i in items]
        if val in labels:
            cmds.optionMenu(UI[name], e=True, v=val)

def _set_chk(name, val):
    if name in UI and cmds.checkBox(UI[name], ex=True):
        cmds.checkBox(UI[name], e=True, v=bool(val))

# ------------------------------------------------------------
# Scene helpers
# ------------------------------------------------------------
# exact node names this tool created this session - deletion uses ONLY
# this list plus the Bigfoot_GRP group. Never wildcards: a pattern like
# bf_fur_* would also eat a stranger's bf_fur_coat node.
_CREATED = []

# shading-group cache: avoids a scene query per mesh (~150x per rebuild)
_SGC = {}

def _track(*names):
    for n in names:
        if n and n not in _CREATED:
            _CREATED.append(n)

def clear_old(keep_materials=False):
    global _CREATED
    # the group takes all member meshes with it - exact, no pattern match
    doomed = []
    try:
        if cmds.objExists("Bigfoot_GRP"):
            doomed.append("Bigfoot_GRP")
    except Exception:
        pass
    if not keep_materials:
        # shaders + SGs this session created (legacy bf_fur_* texture nodes
        # from older script versions are deliberately left alone: this
        # session did not make them, so they are not ours to delete)
        for n in _CREATED:
            try:
                if cmds.objExists(n):
                    doomed.append(n)
            except Exception:
                pass
    # one by one so a single stale name can't block the rest
    for n in doomed:
        try:
            if cmds.objExists(n):
                cmds.delete(n)
        except Exception:
            pass
    if not keep_materials:
        MAT.clear()
        _SGC.clear()
        _CREATED = []

def make_lambert(name, color):
    """One flat lambert, nothing else. Healthy same-named nodes are reused
    (just the color updates) so live rebuilds skip delete/create churn."""
    try:
        if cmds.objExists(name):
            sgList = cmds.listConnections(name, t="shadingEngine") or []
            if sgList and cmds.objExists(sgList[0]):
                try:
                    cmds.setAttr(name + ".color", color[0], color[1], color[2], type="double3")
                    MAT[name] = name
                    _SGC[name] = sgList[0]
                    _track(name, sgList[0])
                    return name
                except Exception:
                    pass
            try:
                cmds.delete([name] + [s for s in sgList if cmds.objExists(s)])
            except Exception:
                try:
                    cmds.delete(name)
                except Exception:
                    pass
        mat = cmds.shadingNode("lambert", asShader=True, n=name)
        sgName = name + "SG"
        if cmds.objExists(sgName):
            try:
                cmds.delete(sgName)
            except Exception:
                pass
        sg = cmds.sets(renderable=True, noSurfaceShader=True, empty=True, n=sgName)
        cmds.connectAttr(mat + ".outColor", sg + ".surfaceShader", f=True)
        try:
            cmds.setAttr(mat + ".color", color[0], color[1], color[2], type="double3")
        except Exception:
            pass
        MAT[name] = mat
        _SGC[name] = sg
        _track(mat, sg)
        return mat
    except Exception as e:
        print("WARNING: material %s failed (%s)." % (name, e))
        return None

def _mesh_sg(obj):
    """Shading group of a mesh: MUST query the shape node, not the transform
    (Maya connects dagSetMembers on the shape - asking the transform
    returns nothing even when assignment is fine)."""
    try:
        shapes = cmds.listRelatives(obj, shapes=True, fullPath=True) or [obj]
        return cmds.listConnections(shapes, t="shadingEngine") or []
    except Exception:
        return []

def assign(obj, mat):
    """Assign material, reusing or repairing its shading group.
    The SG lookup is cached per build (see _SGC)."""
    try:
        if not mat or not cmds.objExists(mat) or not cmds.objExists(obj):
            return False
        sg = _SGC.get(mat)
        if not sg or not cmds.objExists(sg):
            sgList = cmds.listConnections(mat, t="shadingEngine") or []
            sg = sgList[0] if sgList else (mat + "SG")
            if not cmds.objExists(sg):
                sg = cmds.sets(renderable=True, noSurfaceShader=True, empty=True, n=sg)
            # ensure this shader actually drives the SG
            try:
                cur = cmds.listConnections(sg + ".surfaceShader", s=True, d=False) or []
                if mat not in cur:
                    cmds.connectAttr(mat + ".outColor", sg + ".surfaceShader", f=True)
            except Exception:
                pass
            _SGC[mat] = sg
        cmds.sets(obj, e=True, forceElement=sg)
        return True
    except Exception:
        return False

def _sg_validated():
    """Re-check the SG cache once per build (7 queries instead of ~170).
    assign() trusts it after this; falls back to lookup on any miss."""
    try:
        for m, sg in list(_SGC.items()):
            if not sg or not cmds.objExists(sg):
                _SGC.pop(m, None)
                continue
            try:
                cur = cmds.listConnections(sg + ".surfaceShader", s=True, d=False) or []
                if m not in cur:
                    _SGC.pop(m, None)
            except Exception:
                _SGC.pop(m, None)
    except Exception:
        pass

# ------------------------------------------------------------
# PART BUILDERS - refined sculpt base, no rig, flat lamberts
# ------------------------------------------------------------
def build_torso(grp, P):
    s = P["height"] / 7.6
    bulk = P["bulk"]
    belly = P["belly"]
    hunch = P["hunch"]

    pelvis = cmds.polySphere(r=0.62 * bulk * s, sx=24, sy=18, n="bf_pelvis")[0]
    cmds.move(0, 3.35 * s, 0, pelvis)
    cmds.scale(bulk, 0.9, bulk * 0.85, pelvis)

    bellyM = cmds.polySphere(r=0.68 * bulk * s, sx=26, sy=20, n="bf_belly")[0]
    cmds.move(0, 4.15 * s + hunch * 0.2, -0.05 * hunch, bellyM)
    cmds.scale(bulk * (1.0 + belly * 0.30), 1.05 + belly * 0.30, bulk * 0.88, bellyM)

    chest = cmds.polySphere(r=0.74 * bulk * s, sx=28, sy=22, n="bf_chest")[0]
    cmds.move(0, 5.05 * s + hunch * 0.12, -0.20 * hunch, chest)
    cmds.scale(P["chestW"] * bulk * 0.95, 1.08, bulk * 0.88, chest)
    cmds.rotate(hunch * 26, 0, 0, chest)

    traps = cmds.polySphere(r=0.55 * bulk * s, sx=24, sy=18, n="bf_traps")[0]
    cmds.move(0, 5.75 * s, -0.25 * hunch, traps)
    cmds.scale(P["shoulderW"] * 1.30, 0.62, bulk * 0.80, traps)

    for o in (pelvis, bellyM, chest, traps):
        cmds.parent(o, grp)
        assign(o, MAT["fur"])

    # paired pectoral lobes seated on the chest surface (built like the
    # glutes: two masses meeting at the middle), nipples capping each one
    _chY = 5.05 * s + hunch * 0.12
    _chZ = -0.20 * hunch
    _chRx = 0.74 * bulk * s * (P["chestW"] * bulk * 0.95)
    _chRy = 0.74 * bulk * s * 1.08
    _chRz = 0.74 * bulk * s * (bulk * 0.88)
    for sx, nm in ((-1, "_R"), (1, "_L")):
        _pecR = 0.30 * bulk * s * P["chestW"]
        _pecX = sx * 0.34 * bulk * s * P["chestW"]
        _pecY = 5.02 * s
        _pf = max(0.2, 1.0 - (_pecX / _chRx) ** 2 - ((_pecY - _chY) / _chRy) ** 2) ** 0.5
        _pecZ = _chZ + _chRz * _pf - _pecR * 0.6 + 0.14 * s
        pec = cmds.polySphere(r=_pecR, sx=20, sy=14, n="bf_pec" + nm)[0]
        cmds.move(_pecX, _pecY, _pecZ, pec)
        cmds.scale(1.1, 0.75, 0.6, pec)
        cmds.parent(pec, grp)
        assign(pec, MAT["skin"] if P["chestBald"] > 0.5 else MAT["fur"])
        # nipple caps the lobe front
        _nipR = 0.045 * bulk * s + 0.012
        nip = cmds.polySphere(r=_nipR, sx=10, sy=8, n="bf_nipple" + nm)[0]
        cmds.move(_pecX, 4.90 * s, _pecZ + _pecR * 0.6 - _nipR * 0.5 + 0.015 * s, nip)
        cmds.scale(1.0, 0.6, 0.5, nip)
        cmds.parent(nip, grp)
        assign(nip, MAT["dark"])
    for sx, nm in ((-1, "_R"), (1, "_L")):
        # lat mass - widens back like ref
        lat = cmds.polySphere(r=0.34 * bulk * s, sx=16, sy=12, n="bf_lat" + nm)[0]
        cmds.move(sx * 0.58 * bulk * s * P["chestW"], 4.75 * s, -0.32 * bulk * s, lat)
        cmds.scale(0.65, 1.25, 0.85, lat)
        cmds.rotate(0, 0, sx * -12, lat)
        cmds.parent(lat, grp)
        assign(lat, MAT["fur"])
    # six-pack: 3 rows x 2 columns riding the belly surface, small gaps
    # between blocks reading as tendon lines
    if belly < 1.0:
        _bcy = 4.15 * s + hunch * 0.2
        _bcz = -0.05 * hunch
        _brx = 0.68 * bulk * s * (bulk * (1.0 + belly * 0.30))
        _bry = 0.68 * bulk * s * (1.05 + belly * 0.30)
        _brz = 0.68 * bulk * s * (bulk * 0.88)
        for r in range(3):
            for sx, nm in ((-1, "_R"), (1, "_L")):
                _abR = 0.12 * bulk * s + 0.025
                _abX = sx * _brx * 0.15
                _abY = (4.42 - r * 0.32) * s
                _af = max(0.2, 1.0 - (_abX / _brx) ** 2 - ((_abY - _bcy) / _bry) ** 2) ** 0.5
                ab = cmds.polySphere(r=_abR, sx=14, sy=12, n="bf_ab%d%s" % (r, nm))[0]
                cmds.move(_abX, _abY, _bcz + _brz * _af - _abR * 0.55 + 0.12 * s, ab)
                cmds.scale(1.0, 0.8, 0.55, ab)
                cmds.parent(ab, grp)
                assign(ab, MAT["skin"] if P["chestBald"] > 0.65 else MAT["fur"])
    # navel - small dark ring seated on the belly surface between the blocks
    nav = cmds.polyTorus(r=0.035 * s + 0.01, sr=0.018 * s, sx=10, sy=6, n="bf_navel")[0]
    cmds.move(0, 3.95 * s, -0.05 * hunch + (0.60 * bulk * bulk * s) * 0.95 - 0.005, nav)
    cmds.parent(nav, grp)
    assign(nav, MAT["dark"])

    # glutes raised: two lobes only (top mass, hip pads and cleft removed)
    _gz = P.get("glutes", 1.0)
    for sx, nm in ((-1, "_R"), (1, "_L")):
        _lobe = cmds.polySphere(r=0.26 * bulk * s * _gz, sx=18, sy=14, n="bf_gluteLobe" + nm)[0]
        cmds.move(sx * 0.24 * bulk * s * _gz, 3.22 * s, -0.52 * bulk * s * _gz, _lobe)
        cmds.scale(1.12, 1.12, 1.0, _lobe)
        cmds.parent(_lobe, grp)
        assign(_lobe, MAT["fur"])

    return {"chestY": 5.05 * s, "pelvisY": 3.35 * s, "s": s}

def build_head(grp, P, chestY, s):
    hunch = P["hunch"]
    hs = P["headSize"]
    neckL = P["neck"]
    wr = P["wrinkles"]

    neck = cmds.polyCylinder(r=0.34 * P["bulk"] * hs * s, h=(0.35 + neckL * 0.6) * s, sx=16, n="bf_neck")[0]
    cmds.move(0, chestY + 1.05 * s, -0.18 * hunch, neck)
    cmds.rotate(hunch * 18, 0, 0, neck)

    hy = chestY + 1.45 * s + P["headPitch"] * 0.15
    hz = 0.28 * s - hunch * 0.18 + P["headPitch"] * 0.12

    head = cmds.polySphere(r=0.46 * hs * s, sx=28, sy=22, n="bf_head")[0]
    cmds.move(0, hy, hz, head)
    cmds.scale(1.0, 1.02, 1.02, head)

    # sagittal dome - smooth rounded peak (texture carries the strands,
    # not a sharp cone). crestH = taller dome, crestW = wider dome.
    crest = cmds.polySphere(r=0.34 * hs * s, sx=22, sy=18, n="bf_crest")[0]
    cmds.move(0, hy + 0.30 * hs * s + P["crestH"] * 0.22, hz - 0.10 * s, crest)
    cmds.scale(0.95 * P["crestW"] + 0.10, 0.85 + P["crestH"] * 0.55, 1.05, crest)
    cmds.rotate(-10 - hunch * 8, 0, 0, crest)

    # widow's peak - low hairline point, flattened (texture does the strands)
    peak = cmds.polySphere(r=0.11 * hs * s, sx=12, sy=10, n="bf_widowsPeak")[0]
    cmds.move(0, hy + 0.28 * hs * s, hz + 0.32 * hs * s, peak)
    cmds.scale(1.15, 0.75, 0.6, peak)
    cmds.rotate(18, 0, 0, peak)

    # rear mane down to shoulders
    mane = cmds.polySphere(r=0.42 * hs * s, sx=22, sy=18, n="bf_mane")[0]
    cmds.move(0, hy - 0.10 * s, hz - 0.30 * s, mane)
    cmds.scale(1.15, 1.35, 0.95, mane)

    # heavy brow ridge
    brow = cmds.polyTorus(r=0.055 * s * (0.5 + P["brow"]), sr=0.30 * hs * s, sx=16, sy=10, n="bf_brow")[0]
    cmds.move(0, hy + 0.10 * hs * s, hz + 0.36 * hs * s, brow)
    cmds.scale(1.05, 0.42, 0.55, brow)

    # forehead wrinkle - 1 arc, strength follows wrinkles slider
    if wr > 0.05:
        for i in range(1):
            w = cmds.polyTorus(r=0.045 * s + 0.02, sr=0.22 * hs * s, sx=14, sy=6, n="bf_foreheadWrinkle_%d" % i)[0]
            cmds.move(0, hy + (0.22 + i * 0.09) * hs * s, hz + 0.30 * hs * s, w)
            cmds.scale(1.0, 0.30, 0.45, w)
            cmds.parent(w, grp)
            assign(w, MAT["fur"] if wr < 0.7 else MAT["skin"])
            # fade by scaling thin when low
            cmds.scale(1.0, 0.30 * wr + 0.08, 0.45, w)

    # muzzle - flat ape face
    muz = cmds.polySphere(r=0.24 * hs * s, sx=20, sy=14, n="bf_muzzle")[0]
    cmds.move(0, hy - 0.14 * hs * s, hz + 0.38 * hs * s + P["muzzle"] * 0.20, muz)
    cmds.scale(P["jawW"], 0.72, 0.85 + P["muzzle"] * 0.45, muz)
    # muzzle-front solver (audit: lips/mouth sat inside the muzzle mass).
    # Seats below derive from this surface: they track Head/Muzzle size.
    _mzcy = hy - 0.14 * hs * s
    _mzcz = hz + 0.38 * hs * s + P["muzzle"] * 0.20
    _mry = (0.24 * hs * s) * 0.72
    _mrz = (0.24 * hs * s) * (0.85 + P["muzzle"] * 0.45)

    def _mzfront(y):
        _f = max(0.2, 1.0 - ((y - _mzcy) / _mry) ** 2) ** 0.5
        return _mzcz + _mrz * _f

    # nose bridge + wide nose
    bridge = cmds.polyCylinder(r=0.06 * hs * s * P["noseW"] + 0.015, h=0.22 * hs * s + 0.05, sx=10, n="bf_noseBridge")[0]
    cmds.move(0, hy + 0.0 * hs * s, hz + 0.44 * hs * s + P["muzzle"] * 0.22, bridge)
    cmds.rotate(18, 0, 0, bridge)

    nose = cmds.polySphere(r=0.095 * hs * s + 0.03 * P["noseW"], sx=16, sy=12, n="bf_nose")[0]
    cmds.move(0, hy - 0.06 * hs * s, hz + 0.50 * hs * s + P["muzzle"] * 0.30, nose)
    cmds.scale(1.35 * P["noseW"], 0.80, 0.75, nose)

    for sx, nm in ((-1, "_R"), (1, "_L")):
        nos = cmds.polySphere(r=0.035 * hs * s + 0.008, sx=10, sy=8, n="bf_nostril" + nm)[0]
        cmds.move(sx * 0.07 * hs * s * P["noseW"], hy - 0.09 * hs * s, hz + 0.55 * hs * s + P["muzzle"] * 0.30, nos)
        cmds.parent(nos, grp)
        assign(nos, MAT["nose"])
        # nostril rim
        rim = cmds.polyTorus(r=0.035 * hs * s + 0.008, sr=0.014 * s, sx=10, sy=6, n="bf_nostrilRim" + nm)[0]
        cmds.move(sx * 0.07 * hs * s * P["noseW"], hy - 0.09 * hs * s, hz + 0.56 * hs * s + P["muzzle"] * 0.30, rim)
        cmds.parent(rim, grp)
        assign(rim, MAT["nose"])
        # nasolabial fold - nose to mouth corner
        fold = cmds.polyTorus(r=0.02 * s, sr=0.14 * hs * s, sx=10, sy=6, n="bf_nasolabial" + nm)[0]
        cmds.move(sx * 0.17 * hs * s * P["jawW"], hy - 0.16 * hs * s, hz + 0.44 * hs * s, fold)
        cmds.rotate(10, sx * -18, sx * -22, fold)
        cmds.scale(1.0, 1.0, 0.6, fold)
        cmds.parent(fold, grp)
        assign(fold, MAT["skin"])

    # jaw + beard
    jaw = cmds.polySphere(r=0.27 * hs * s, sx=20, sy=14, n="bf_jaw")[0]
    cmds.move(0, hy - 0.32 * hs * s, hz + 0.20 * hs * s + P["muzzle"] * 0.12, jaw)
    cmds.scale(P["jawW"], 0.62 + P["beard"] * 0.25, 0.92, jaw)

    beard = cmds.polySphere(r=0.20 * hs * s * P["jawW"], sx=16, sy=12, n="bf_beard")[0]
    cmds.move(0, hy - 0.52 * hs * s - P["beard"] * 0.12, hz + 0.16 * s, beard)
    cmds.scale(1.0, 0.9 + P["beard"] * 0.55, 0.9, beard)

    # lips cap the muzzle front - ref has tight straight stern mouth
    _ulY = hy - 0.185 * hs * s
    _ulRz = (0.13 * hs * s * P["jawW"] + 0.02) * 0.55
    upperLip = cmds.polySphere(r=0.13 * hs * s * P["jawW"] + 0.02, sx=14, sy=8, n="bf_upperLip")[0]
    cmds.move(0, _ulY, _mzfront(_ulY) - _ulRz + 0.04 * s, upperLip)
    cmds.scale(1.15, 0.32, 0.55, upperLip)

    _llY = hy - 0.245 * hs * s
    _llRz = (0.10 * hs * s * P["jawW"] + 0.015) * 0.55
    lowerLip = cmds.polySphere(r=0.10 * hs * s * P["jawW"] + 0.015, sx=12, sy=8, n="bf_lowerLip")[0]
    cmds.move(0, _llY, _mzfront(_llY) - _llRz + 0.04 * s, lowerLip)
    cmds.scale(1.0, 0.35, 0.55, lowerLip)

    _moY = hy - 0.20 * hs * s
    _moTz = (0.025 * s + 0.20 * hs * s * P["jawW"]) * 0.6
    mouth = cmds.polyTorus(r=0.025 * s, sr=0.20 * hs * s * P["jawW"], sx=18, sy=8, n="bf_mouth")[0]
    cmds.move(0, _moY, _mzfront(_moY) - _moTz + 0.02 * s, mouth)
    cmds.scale(1.0, 0.32, 0.6, mouth)

    for sx, nm in ((-1, "_R"), (1, "_L")):
        ear = cmds.polySphere(r=0.11 * hs * s, sx=12, sy=10, n="bf_ear" + nm)[0]
        cmds.move(sx * 0.40 * hs * s, hy + 0.08 * hs * s, hz - 0.12 * s, ear)
        cmds.scale(1.0, 1.15, 0.55, ear)
        cmds.parent(ear, grp)
        assign(ear, MAT["skin"])
        # inner ear cup
        inner = cmds.polySphere(r=0.06 * hs * s, sx=8, sy=6, n="bf_earInner" + nm)[0]
        cmds.move(sx * 0.40 * hs * s, hy + 0.08 * hs * s, hz - 0.06 * s, inner)
        cmds.scale(1.0, 1.0, 0.4, inner)
        cmds.parent(inner, grp)
        assign(inner, MAT["dark"])

    for o in (neck, head, crest, peak, mane, brow, bridge, muz, nose, jaw, beard,
              upperLip, lowerLip, mouth):
        try:
            cmds.parent(o, grp)
        except Exception:
            pass
    assign(neck, MAT["fur"])
    assign(head, MAT["fur"])
    assign(crest, MAT["fur"])
    assign(peak, MAT["fur"])
    assign(mane, MAT["fur"])
    assign(brow, MAT["fur"])
    assign(bridge, MAT["skin"])
    assign(muz, MAT["skin"])
    assign(nose, MAT["nose"])
    assign(jaw, MAT["skin"])
    assign(beard, MAT["fur"])
    assign(upperLip, MAT["lips"])
    assign(lowerLip, MAT["lips"])
    assign(mouth, MAT["lips"])

    return (hy, hz, hs)

def build_eyes(grp, P, headPos, s):
    hy, hz, hs = headPos
    es = P["eyeSize"]
    depth = P["eyeDepth"]
    spread = 0.21 * hs * s
    # no eyeballs - only the lower bags remain under the brow shadow,
    # forming the closed deep-set eye region
    for sx, nm in ((-1, "_R"), (1, "_L")):
        # lower bag
        bag = cmds.polySphere(r=(0.09 * hs * es + 0.015) * s, sx=12, sy=8, n="bf_eyeBag" + nm)[0]
        cmds.move(sx * spread, hy + 0.005 * hs * s, hz + 0.41 * hs * s - depth * 0.035, bag)
        cmds.scale(1.0, 0.45, 0.6, bag)
        cmds.parent(bag, grp)
        assign(bag, MAT["skin"])

def build_arms(grp, P, chestY, s):
    bulk = P["bulk"]
    al = P["armL"]
    walk = P["walkPose"]
    shY = chestY + 0.55 * s
    shX = 0.78 * bulk * s * P["shoulderW"]
    for sx, nm in ((-1, "_R"), (1, "_L")):
        # arms hang at the sides: near-zero swing, minimal splay
        swing = walk * (0.10 if (sx < 0) else -0.10)
        # deltoid cap rounds the shoulder like the reference figure
        delt = cmds.polySphere(r=(0.26 * P["upperArm"] * bulk + 0.03) * s, sx=18, sy=14, n="bf_delt" + nm)[0]
        cmds.move(sx * shX, shY + 0.02, 0.05 * s + swing * 0.15, delt)
        cmds.scale(1.0, 1.05, 1.0, delt)
        cmds.parent(delt, grp)
        assign(delt, MAT["fur"])
        # upper arm
        _upX = sx * (shX + 0.10)
        _upZ = 0.06 * s + swing * 0.25
        _armR = 0.20 * P["upperArm"] * bulk * s
        up = cmds.polyCylinder(r=_armR, h=0.95 * al * s, sx=16, n="bf_upperArm" + nm)[0]
        cmds.move(_upX, shY - 0.40 * al * s, _upZ, up)
        cmds.rotate(-6 + swing * 18 + P["elbowBend"] * 10, 0, sx * 3, up)
        cmds.parent(up, grp)
        assign(up, MAT["fur"])
        # shoulder joint rounds the traps-to-arm junction
        _sho = cmds.polySphere(r=_armR * 1.1, sx=16, sy=12, n="bf_shoulder" + nm)[0]
        cmds.move(sx * (shX + 0.05), shY + 0.04 * s, 0.05 * s + swing * 0.2, _sho)
        cmds.scale(1.0, 1.05, 1.0, _sho)
        cmds.parent(_sho, grp)
        assign(_sho, MAT["fur"])
        # bicep caps the upper-arm front like the reference figure
        _bicR = (0.15 * P["upperArm"] * bulk + 0.05) * s
        bic = cmds.polySphere(r=_bicR, sx=14, sy=12, n="bf_bicep" + nm)[0]
        cmds.move(_upX, shY - 0.42 * al * s, _upZ + _armR - _bicR * 0.85 + 0.06 * s, bic)
        cmds.scale(0.9, 1.3, 0.85, bic)
        cmds.parent(bic, grp)
        assign(bic, MAT["fur"])
        elb = cmds.polySphere(r=0.17 * P["upperArm"] * bulk * s, sx=14, sy=12, n="bf_elbow" + nm)[0]
        cmds.move(sx * (shX + 0.16), shY - 0.90 * al * s, 0.14 * s + swing * 0.5, elb)
        cmds.parent(elb, grp)
        assign(elb, MAT["fur"])
        # forearm tapers toward the wrist: thick upper segment stepping
        # down to a slimmer lower one (no more pipe limbs)
        _foX = sx * (shX + 0.18)
        _foZ = 0.20 * s + swing * 0.65
        _foR = 0.16 * P["forearm"] * bulk * s
        foU = cmds.polyCylinder(r=_foR, h=0.50 * al * s, sx=16, n="bf_forearmU" + nm)[0]
        cmds.move(_foX, shY - 1.12 * al * s, _foZ, foU)
        cmds.rotate(-10 + swing * 14 - P["elbowBend"] * 28, 0, sx * 2, foU)
        cmds.parent(foU, grp)
        assign(foU, MAT["fur"])
        fo = cmds.polyCylinder(r=_foR * 0.78, h=0.48 * al * s, sx=14, n="bf_forearm" + nm)[0]
        cmds.move(_foX, shY - 1.55 * al * s, _foZ, fo)
        cmds.rotate(-10 + swing * 14 - P["elbowBend"] * 28, 0, sx * 2, fo)
        cmds.parent(fo, grp)
        assign(fo, MAT["fur"])
        # wrist bridges forearm end into hand top (no gap at any Arm Length)
        wrist = cmds.polyCylinder(r=0.11 * P["handSize"] * bulk * s + 0.02, h=0.30 * s, sx=12, n="bf_wrist" + nm)[0]
        handY = shY - 1.85 * al * s
        handZ = 0.30 * s + swing * 0.80
        cmds.move(sx * (shX + 0.18), handY + 0.16 * s, handZ - 0.05 * s, wrist)
        cmds.parent(wrist, grp)
        assign(wrist, MAT["fur"])
        # palm + thumb/pinky mounds; all finger/thumb bases derive from
        # these anchors so the hand holds together at any Hand Size
        _hx = sx * (shX + 0.18)
        _inner = -sx  # body side of the hand, where the thumb lives
        hand = cmds.polySphere(r=(0.20 * P["handSize"] * bulk + 0.05) * s, sx=18, sy=14, n="bf_hand" + nm)[0]
        cmds.move(_hx, handY, handZ, hand)
        cmds.scale(1.0, 1.15, 1.25, hand)
        cmds.parent(hand, grp)
        assign(hand, MAT["fur"])
        palm = cmds.polySphere(r=(0.14 * P["handSize"] + 0.03) * s, sx=14, sy=10, n="bf_palm" + nm)[0]
        cmds.move(_hx, handY - 0.02, handZ + 0.16 * s, palm)
        cmds.scale(1.0, 1.15, 0.55, palm)
        cmds.parent(palm, grp)
        assign(palm, MAT["skin"])
        thenar = cmds.polySphere(r=0.085 * P["handSize"] * s, sx=12, sy=10, n="bf_thenar" + nm)[0]
        cmds.move(_hx + _inner * 0.20 * s, handY - 0.10 * s, handZ + 0.30 * s, thenar)
        cmds.parent(thenar, grp)
        assign(thenar, MAT["skin"])
        hypo = cmds.polySphere(r=0.07 * P["handSize"] * s, sx=10, sy=8, n="bf_hypo" + nm)[0]
        cmds.move(_hx - _inner * 0.22 * s, handY - 0.08 * s, handZ + 0.28 * s, hypo)
        cmds.parent(hypo, grp)
        assign(hypo, MAT["skin"])
        # fingers - middle longest, outer fingers curl more, nails ride
        # the segment tips so they track Finger Length
        _fLen = (0.92, 1.0, 1.02, 0.85)
        _fCurl = (4, 0, 2, 10)
        for f in range(4):
            off = (f - 1.5) * 0.11 * P["handSize"] * s
            flen = (0.30 * P["fingerL"] + 0.10) * s * _fLen[f]
            bx = _hx + off
            _ky = handY - 0.30 * s - abs(off) * 0.55
            _kz = handZ + 0.18 * s
            _c1 = -32 - P["elbowBend"] * 20 + _fCurl[f]
            _c2 = _c1 - 16 - _fCurl[f] * 0.5
            # knuckle straddles the fist's lower edge
            kn = cmds.polySphere(r=(0.048 * P["fingerT"] + 0.014) * s, sx=10, sy=8, n="bf_knuckle%s_%d" % (nm, f))[0]
            cmds.move(bx, _ky, _kz, kn)
            cmds.parent(kn, grp)
            assign(kn, MAT["skin"])
            seg1 = cmds.polyCylinder(r=(0.040 * P["fingerT"] + 0.015) * s, h=flen * 0.6, sx=10, n="bf_finger%s_%dA" % (nm, f))[0]
            cmds.move(bx, _ky - flen * 0.28, _kz + 0.02 * s, seg1)
            cmds.rotate(_c1, 0, 0, seg1)
            cmds.parent(seg1, grp)
            assign(seg1, MAT["skin"])
            seg2 = cmds.polyCylinder(r=(0.034 * P["fingerT"] + 0.012) * s, h=flen * 0.5, sx=8, n="bf_finger%s_%dB" % (nm, f))[0]
            cmds.move(bx, _ky - flen * 0.62, _kz + 0.08 * s, seg2)
            cmds.rotate(_c2, 0, 0, seg2)
            cmds.parent(seg2, grp)
            assign(seg2, MAT["skin"])
            nail = cmds.polyCube(w=0.055 * P["fingerT"] * s + 0.015, h=0.02 * s + 0.008, d=0.07 * s + 0.015, n="bf_nail%s_%d" % (nm, f))[0]
            cmds.move(bx, _ky - flen * 0.87, _kz + 0.08 * s + flen * 0.20, nail)
            cmds.rotate(_c2, 0, 0, nail)
            cmds.parent(nail, grp)
            assign(nail, MAT["nails"])
        # thumb - climbs the front-inner edge of the fist, tip clear of it
        th1 = cmds.polyCylinder(r=(0.045 * P["fingerT"] + 0.015) * s, h=0.18 * P["fingerL"] * s + 0.05, sx=10, n="bf_thumbA" + nm)[0]
        cmds.move(_hx + _inner * 0.22 * s, handY - 0.08 * s, handZ + 0.30 * s, th1)
        cmds.rotate(-35, 0, _inner * 25, th1)
        cmds.parent(th1, grp)
        assign(th1, MAT["skin"])
        th2 = cmds.polyCylinder(r=(0.038 * P["fingerT"] + 0.012) * s, h=0.16 * P["fingerL"] * s + 0.04, sx=8, n="bf_thumbB" + nm)[0]
        cmds.move(_hx + _inner * 0.30 * s, handY - 0.20 * s, handZ + 0.38 * s, th2)
        cmds.rotate(-50, 0, _inner * 20, th2)
        cmds.parent(th2, grp)
        assign(th2, MAT["skin"])
        thn = cmds.polyCube(w=0.05 * s + 0.012, h=0.018 * s + 0.006, d=0.06 * s + 0.012, n="bf_thumbNail" + nm)[0]
        cmds.move(_hx + _inner * 0.34 * s, handY - 0.30 * s, handZ + 0.46 * s, thn)
        cmds.rotate(-40, 0, 0, thn)
        cmds.parent(thn, grp)
        assign(thn, MAT["nails"])

def build_legs_feet(grp, P, pelvisY, s):
    bulk = P["bulk"]
    ll = P["legL"]
    walk = P["walkPose"]
    stance = P["stance"]
    for sx, nm in ((-1, "_R"), (1, "_L")):
        fwd = walk * (0.55 * s if (sx < 0) else -0.55 * s)
        side = sx * (0.36 * bulk * s + stance * 0.18)
        _thighZ = fwd * 0.35
        _thighR = 0.24 * P["thigh"] * bulk * s
        # thigh tapers toward the knee: full upper segment, slimmer lower one
        thighU = cmds.polyCylinder(r=_thighR, h=0.50 * ll * s, sx=18, n="bf_thighU" + nm)[0]
        cmds.move(side, pelvisY - 0.28 * ll * s, _thighZ, thighU)
        cmds.rotate(P["kneeBend"] * 32 * (1 if sx < 0 else 0.6), 0, sx * -4, thighU)
        cmds.parent(thighU, grp)
        assign(thighU, MAT["fur"])
        thigh = cmds.polyCylinder(r=_thighR * 0.85, h=0.48 * ll * s, sx=16, n="bf_thigh" + nm)[0]
        cmds.move(side, pelvisY - 0.60 * ll * s, _thighZ, thigh)
        cmds.rotate(P["kneeBend"] * 32 * (1 if sx < 0 else 0.6), 0, sx * -4, thigh)
        cmds.parent(thigh, grp)
        assign(thigh, MAT["fur"])
        # quad sweeps the thigh front like the reference figure
        _quadR = (0.16 * P["thigh"] * bulk + 0.06) * s
        quad = cmds.polySphere(r=_quadR, sx=14, sy=12, n="bf_quad" + nm)[0]
        cmds.move(side, pelvisY - 0.45 * ll * s, _thighZ + _thighR * 0.85 - _quadR * 0.85 + 0.06 * s, quad)
        cmds.scale(0.95, 1.3, 0.85, quad)
        cmds.parent(quad, grp)
        assign(quad, MAT["fur"])
        # knee + patella
        knee = cmds.polySphere(r=0.19 * P["thigh"] * bulk * s, sx=14, sy=12, n="bf_knee" + nm)[0]
        cmds.move(side, pelvisY - 0.80 * ll * s, fwd * 0.55 + 0.10 * s, knee)
        cmds.parent(knee, grp)
        assign(knee, MAT["fur"])
        pat = cmds.polySphere(r=0.09 * bulk * s + 0.02, sx=10, sy=8, n="bf_patella" + nm)[0]
        cmds.move(side, pelvisY - 0.80 * ll * s, fwd * 0.55 + 0.10 * s + 0.16 * bulk * s, pat)
        cmds.scale(1.0, 1.15, 0.6, pat)
        cmds.parent(pat, grp)
        assign(pat, MAT["skin"])
        # calf narrows to the ankle the same way
        _shinZ = fwd * 0.60
        _shinR = 0.16 * P["calf"] * bulk * s
        shinU = cmds.polyCylinder(r=_shinR, h=0.45 * ll * s, sx=16, n="bf_shinU" + nm)[0]
        shinY = pelvisY - 1.25 * ll * s
        cmds.move(side, shinY + 0.20 * ll * s, _shinZ, shinU)
        cmds.rotate(-P["kneeBend"] * 22, 0, 0, shinU)
        cmds.parent(shinU, grp)
        assign(shinU, MAT["fur"])
        shin = cmds.polyCylinder(r=_shinR * 0.82, h=0.45 * ll * s, sx=14, n="bf_shin" + nm)[0]
        cmds.move(side, shinY - 0.18 * ll * s, _shinZ, shin)
        cmds.rotate(-P["kneeBend"] * 22, 0, 0, shin)
        cmds.parent(shin, grp)
        assign(shin, MAT["fur"])
        # calf mass swells the upper shin back like the reference figure
        _calfR = (0.13 * P["calf"] * bulk + 0.05) * s
        calf = cmds.polySphere(r=_calfR, sx=14, sy=12, n="bf_calf" + nm)[0]
        cmds.move(side, shinY + 0.20 * ll * s, _shinZ - _shinR + _calfR * 0.9 - 0.06 * s, calf)
        cmds.scale(0.9, 1.3, 0.9, calf)
        cmds.parent(calf, grp)
        assign(calf, MAT["fur"])
        ach = cmds.polyCylinder(r=0.045 * bulk * s + 0.012, h=0.45 * ll * s + 0.08, sx=8, n="bf_achilles" + nm)[0]
        cmds.move(side, shinY - 0.30 * ll * s, fwd * 0.60 - 0.16 * bulk * s, ach)
        cmds.rotate(-6, 0, 0, ach)
        cmds.parent(ach, grp)
        assign(ach, MAT["skin"])
        # ankle bones
        for aside, anm in ((-1, "In"), (1, "Out")):
            mal = cmds.polySphere(r=0.055 * bulk * s + 0.015, sx=8, sy=6, n="bf_ankle%s%s" % (anm, nm))[0]
            cmds.move(side + aside * 0.13 * bulk * s, shinY - 0.48 * ll * s, fwd * 0.60, mal)
            cmds.parent(mal, grp)
            assign(mal, MAT["skin"])
        # ---- BIG FOOT ----
        footY = shinY - 0.52 * ll * s
        if footY < 0.14 * s:
            footY = 0.14 * s
        fL = (0.95 * P["footL"] + 0.20) * s
        fW = (0.40 * P["footW"] * bulk + 0.09) * s
        # (no midfoot box - the instep mass below forms the dorsal foot)
        ball = cmds.polySphere(r=fW * 0.52, sx=16, sy=12, n="bf_forefoot" + nm)[0]
        cmds.move(side, footY + 0.06, fwd + 0.24 * s + fL * 0.32, ball)
        cmds.scale(1.0, 0.62, 1.0, ball)
        cmds.parent(ball, grp)
        assign(ball, MAT["skin"])
        heel = cmds.polySphere(r=0.16 * bulk * s * P["footW"], sx=14, sy=12, n="bf_heel" + nm)[0]
        cmds.move(side, footY + 0.06, fwd - 0.08 * s, heel)
        cmds.scale(1.0, 0.75, 1.0, heel)
        cmds.parent(heel, grp)
        assign(heel, MAT["skin"])
        # instep mass - the dorsal foot: slopes the shin into the forefoot
        instep = cmds.polySphere(r=0.19 * bulk * s, sx=14, sy=12, n="bf_instep" + nm)[0]
        cmds.move(side, footY + 0.16 * s, fwd + 0.20 * s + fL * 0.06, instep)
        cmds.scale(1.25, 0.75, 1.6, instep)
        cmds.rotate(-18, 0, 0, instep)
        cmds.parent(instep, grp)
        assign(instep, MAT["fur"])
        # sole - heel pad + lateral strip + ball pad with an open medial
        # arch (real contact pattern), not a flat slab
        heelPad = cmds.polySphere(r=0.16 * bulk * s * P["footW"] * 0.95, sx=12, sy=8, n="bf_heelPad" + nm)[0]
        cmds.move(side, footY + 0.005 * s, fwd - 0.08 * s, heelPad)
        cmds.scale(0.95, 0.60, 0.95, heelPad)
        cmds.parent(heelPad, grp)
        assign(heelPad, MAT["dark"])
        midStrip = cmds.polyCube(w=fW * 0.45, h=0.12 * s, d=fL * 0.32, n="bf_midStrip" + nm)[0]
        cmds.move(side + sx * 0.05 * s, footY - 0.05 * s, fwd + 0.16 * s + fL * 0.08, midStrip)
        cmds.parent(midStrip, grp)
        assign(midStrip, MAT["dark"])
        ballPad = cmds.polySphere(r=fW * 0.42, sx=14, sy=10, n="bf_ballPad" + nm)[0]
        cmds.move(side, footY + 0.02 * s, fwd + 0.24 * s + fL * 0.32, ballPad)
        cmds.scale(1.0, 0.60, 1.15, ballPad)
        cmds.parent(ballPad, grp)
        assign(ballPad, MAT["dark"])
        # toes - arched row (big toe long, pinky short), gentle outward fan,
        # tips pitched slightly down, nails seated on top of the tips
        _toeK = (1.0, 0.94, 0.96, 0.88, 0.76)
        _toeL = (1.06, 1.0, 1.03, 0.9, 0.74)
        for t in range(5):
            isBig = (t == 0)
            if isBig:
                # big toe on inner edge, angled slightly inward
                tx = side - sx * 0.17 * P["footW"] * s
                yaw = -sx * 6
            else:
                # fan mirrors per foot: inner->outer runs -x on R, +x on L
                # (unmirrored, toes 3-4 cross over the big toe on R)
                tx = side + sx * (t - 2) * 0.10 * P["footW"] * s
                yaw = sx * (t - 1) * 3
            pitch = 3 + t * 1.5
            tl = (0.20 * P["toeL"] + 0.06 + (0.04 if t == 2 else 0) + (0.05 if isBig else 0)) * s * _toeL[t]
            tr = (((0.058 if isBig else 0.048) * P["footW"] + 0.010) * s) * _toeK[t]
            tz = fwd + 0.24 * s + fL * 0.55 + tl * 0.20
            toe = cmds.polySphere(r=tr, sx=14, sy=12, n="bf_toe%s_%d" % (nm, t))[0]
            cmds.move(tx, footY - 0.055 * s, tz, toe)
            cmds.scale(1.0, 0.75, 1.0 + P["toeL"] * 0.45, toe)
            cmds.rotate(pitch, yaw, 0, toe)
            cmds.parent(toe, grp)
            assign(toe, MAT["toes"])
            # toe knuckle
            tkn = cmds.polySphere(r=tr * 0.75, sx=8, sy=6, n="bf_toeKnuckle%s_%d" % (nm, t))[0]
            cmds.move(tx, footY - 0.015 * s, tz - 0.08 * s, tkn)
            cmds.parent(tkn, grp)
            assign(tkn, MAT["toes"])
            tn = cmds.polyCube(w=tr * 1.0, h=tr * 0.4, d=tr, n="bf_toenail%s_%d" % (nm, t))[0]
            cmds.move(tx, footY - 0.04 * s + tr * 0.45, tz + tr * 0.85, tn)
            cmds.rotate(pitch, yaw, 0, tn)
            cmds.parent(tn, grp)
            assign(tn, MAT["nails"])

# ------------------------------------------------------------
# PARAMS
# ------------------------------------------------------------
def collect_params():
    P = {}
    P["presetName"] = _get_opt("preset")
    P["height"] = _get_f("height", 7.6)
    P["bulk"] = _get_f("bulk", 1.25)
    P["belly"] = _get_f("belly", 0.45)
    P["chestW"] = _get_f("chestW", 1.30)
    P["shoulderW"] = _get_f("shoulderW", 1.35)
    P["hunch"] = _get_f("hunch", 0.55)
    P["neck"] = _get_f("neck", 0.20)
    P["headSize"] = _get_f("head", 1.05)
    P["crestH"] = _get_f("crestH", 0.85)
    P["crestW"] = _get_f("crestW", 0.90)
    P["brow"] = _get_f("brow", 0.85)
    P["eyeSize"] = _get_f("eye", 0.65)
    P["eyeDepth"] = _get_f("eyeDepth", 0.70)
    P["noseW"] = _get_f("noseW", 1.10)
    P["muzzle"] = _get_f("muzzle", 0.35)
    P["jawW"] = _get_f("jawW", 1.05)
    P["beard"] = _get_f("beard", 0.60)
    P["armL"] = _get_f("armL", 1.28)
    P["upperArm"] = _get_f("upperArm", 1.15)
    P["forearm"] = _get_f("forearm", 1.25)
    P["handSize"] = _get_f("handSize", 1.20)
    P["fingerL"] = _get_f("fingerL", 1.00)
    P["fingerT"] = _get_f("fingerT", 1.15)
    P["legL"] = _get_f("legL", 1.00)
    P["thigh"] = _get_f("thigh", 1.20)
    P["calf"] = _get_f("calf", 1.05)
    P["footL"] = _get_f("footL", 1.60)
    P["footW"] = _get_f("footW", 1.25)
    P["toeL"] = _get_f("toeL", 1.00)
    P["wrinkles"] = _get_f("wrinkles", 0.75)
    P["furColor"] = _get_col("furCol", (0.16, 0.13, 0.10))
    P["skinColor"] = _get_col("skinCol", (0.30, 0.25, 0.20))
    P["noseColor"] = _get_col("noseCol", (0.10, 0.08, 0.07))
    P["lipsColor"] = _get_col("lipsCol", (0.12, 0.08, 0.07))
    P["nailsColor"] = _get_col("nailsCol", (0.16, 0.14, 0.12))
    P["toesColor"] = _get_col("toesCol", (0.30, 0.25, 0.20))
    P["greyAmt"] = _get_f("grey", 0.15)
    P["glutes"] = _get_f("glutes", 1.0)
    P["chestBald"] = _get_f("chestBald", 0.55)
    P["stance"] = _get_f("stance", 0.55)
    P["kneeBend"] = _get_f("kneeBend", 0.35)
    P["elbowBend"] = _get_f("elbowBend", 0.20)
    P["headPitch"] = _get_f("headPitch", 0.25)
    P["walkPose"] = _get_f("walkPose", 0.65)
    return P

# ------------------------------------------------------------
# MAIN BUILD
# ------------------------------------------------------------
def build_bigfoot(*args):
    if not MAYA:
        print("Run inside Maya Script Editor.")
        return
    import traceback
    try:
        P = collect_params()
        _perf_freeze(False)  # safety reset in case a previous build died frozen
        clear_old(keep_materials=_LIVE_BUILD)
        _perf_freeze(True)
        fc = P["furColor"]
        g = P["greyAmt"]
        furC = (fc[0] + (0.45 - fc[0]) * g, fc[1] + (0.43 - fc[1]) * g, fc[2] + (0.40 - fc[2]) * g)
        # saturation lift so the fur reads rich brown instead of grey
        _sat = 0.5
        _lum = furC[0] * 0.30 + furC[1] * 0.59 + furC[2] * 0.11
        furC = tuple(min(1.0, max(0.0, _lum + (c - _lum) * (1.0 + _sat))) for c in furC)

        make_lambert("bigfoot_fur_MAT", furC)
        make_lambert("bigfoot_skin_MAT", P["skinColor"])
        make_lambert("bigfoot_dark_MAT", (0.07, 0.06, 0.055))
        make_lambert("bigfoot_nose_MAT", P["noseColor"])
        make_lambert("bigfoot_lips_MAT", P["lipsColor"])
        make_lambert("bigfoot_nails_MAT", P["nailsColor"])
        make_lambert("bigfoot_toes_MAT", P["toesColor"])
        MAT["fur"] = "bigfoot_fur_MAT"
        MAT["skin"] = "bigfoot_skin_MAT"
        MAT["dark"] = "bigfoot_dark_MAT"
        MAT["nose"] = "bigfoot_nose_MAT"
        MAT["lips"] = "bigfoot_lips_MAT"
        MAT["nails"] = "bigfoot_nails_MAT"
        MAT["toes"] = "bigfoot_toes_MAT"

        _sg_validated()
        grp = cmds.group(empty=True, n="Bigfoot_GRP")
        info = build_torso(grp, P)
        headPos = build_head(grp, P, info["chestY"], info["s"])
        build_eyes(grp, P, headPos, info["s"])
        build_arms(grp, P, info["chestY"], info["s"])
        build_legs_feet(grp, P, info["pelvisY"], info["s"])

        # NOTE: no edge softening - crisp facets read better at this scale
        # and softening caused visible shading churn during live updates.

        # assignment check: grey model = materials never landed. Catch it here.
        # NOTE: query the SHAPE (see _mesh_sg) - the transform always reports none.
        try:
            probed = cmds.objExists("bf_chest")
            if probed:
                sgHit = _mesh_sg("bf_chest")
                if not sgHit or sgHit[0] in ("initialShadingGroup",):
                    msg = "bf_chest is on %s" % (sgHit[0] if sgHit else "nothing")
                    if _LIVE_BUILD:
                        print("Material WARNING: meshes built but materials did not assign (%s)." % msg)
                    else:
                        try:
                            cmds.confirmDialog(t="Bigfoot Material Warning",
                                               m="Meshes built but materials did not assign\n(%s).\n\nTry: delete Bigfoot_GRP, restart Maya,\nthen Apply Preset again." % msg,
                                               b=["OK"], db="OK")
                        except Exception:
                            pass
                else:
                    print("Material check: bf_chest -> %s OK" % sgHit[0])
        except Exception:
            pass

        if _LIVE_BUILD:
            # live drags: select nothing so no vertices/edges ever display
            try:
                cmds.select(clear=True)
            except Exception:
                pass
        else:
            cmds.select(grp, replace=True)
        _perf_freeze(False)
        if not _LIVE_BUILD:
            try:
                for panel in cmds.getPanel(type="modelPanel") or []:
                    try:
                        cmds.viewFit(panel, fitFactor=0.75)
                    except Exception:
                        pass
            except Exception:
                pass
            try:
                mel.eval("FrameSelectedWithoutChildren;")
            except Exception:
                pass
        n = len(cmds.listRelatives(grp, allDescendents=True) or [])
        if not _LIVE_BUILD:
            print("Built Bigfoot sculpt [%s] %.1fft | nodes=%d" % (P["presetName"], P["height"], n))
        if not _LIVE_BUILD:
            try:
                cmds.inViewMessage(amg="Bigfoot Sculpt: <hl>%s</hl> - %.1fft" % (P["presetName"], P["height"]),
                                   pos="midCenter", fade=True)
            except Exception:
                pass
    except Exception as e:
        _perf_freeze(False)  # never leave the session frozen/undo-less
        traceback.print_exc()
        if not _LIVE_BUILD:
            try:
                cmds.confirmDialog(t="Bigfoot Builder Error", m="Build failed:\n%s" % e, b=["OK"], db="OK")
            except Exception:
                pass

def apply_preset(*args):
    name = _get_opt("preset")
    if name not in PRESETS:
        return
    d = PRESETS[name]
    _set_f("height", d["height"])
    _set_f("bulk", d["bulk"])
    _set_f("belly", d["belly"])
    _set_f("chestW", d["chestW"])
    _set_f("shoulderW", d["shoulderW"])
    _set_f("hunch", d["hunch"])
    _set_f("neck", d["neck"])
    _set_f("head", d["headSize"])
    _set_f("crestH", d["crestH"])
    _set_f("crestW", d["crestW"])
    _set_f("brow", d["brow"])
    _set_f("eye", d["eyeSize"])
    _set_f("eyeDepth", d["eyeDepth"])
    _set_f("noseW", d["noseW"])
    _set_f("muzzle", d["muzzle"])
    _set_f("jawW", d["jawW"])
    _set_f("beard", d["beard"])
    _set_f("armL", d["armL"])
    _set_f("upperArm", d["upperArm"])
    _set_f("forearm", d["forearm"])
    _set_f("handSize", d["handSize"])
    _set_f("fingerL", d["fingerL"])
    _set_f("fingerT", d["fingerT"])
    _set_f("legL", d["legL"])
    _set_f("thigh", d["thigh"])
    _set_f("calf", d["calf"])
    _set_f("footL", d["footL"])
    _set_f("footW", d["footW"])
    _set_f("toeL", d["toeL"])
    _set_f("wrinkles", d["wrinkles"])
    _set_col("furCol", d["furColor"])
    _set_col("skinCol", d["skinColor"])
    _set_col("noseCol", d.get("noseColor", (0.10, 0.08, 0.07)))
    _set_col("lipsCol", d.get("lipsColor", (0.12, 0.08, 0.07)))
    _set_col("nailsCol", d.get("nailsColor", (0.16, 0.14, 0.12)))
    _set_col("toesCol", d.get("toesColor", (0.30, 0.25, 0.20)))
    _set_f("grey", d["greyAmt"])
    _set_f("glutes", d.get("glutes", 1.0))
    _set_f("chestBald", d["chestBald"])
    _set_f("stance", d["stance"])
    _set_f("kneeBend", d["kneeBend"])
    _set_f("elbowBend", d["elbowBend"])
    _set_f("headPitch", d["headPitch"])
    _set_f("walkPose", d["walkPose"])
    print("Preset applied: %s" % name)
    live_update()

def randomize_bigfoot(*args):
    _set_f("height", random.uniform(6.5, 8.6))
    _set_f("bulk", random.uniform(0.9, 1.6))
    _set_f("belly", random.uniform(0.2, 0.8))
    _set_f("chestW", random.uniform(1.0, 1.55))
    _set_f("shoulderW", random.uniform(1.05, 1.6))
    _set_f("hunch", random.uniform(0.35, 0.8))
    _set_f("head", random.uniform(0.92, 1.15))
    _set_f("crestH", random.uniform(0.5, 1.05))
    _set_f("crestW", random.uniform(0.75, 1.05))
    _set_f("brow", random.uniform(0.5, 1.0))
    _set_f("footL", random.uniform(1.35, 1.75))
    _set_f("footW", random.uniform(1.05, 1.4))
    _set_f("armL", random.uniform(1.15, 1.35))
    _set_f("wrinkles", random.uniform(0.3, 1.0))
    _set_f("grey", random.uniform(0.0, 0.7))
    _set_f("glutes", random.uniform(0.85, 1.2))
    _set_f("walkPose", random.uniform(0.3, 0.8))
    print("Randomized - rebuilding")
    live_update()

def delete_bigfoot(*args):
    clear_old()
    print("Bigfoot deleted.")

def snapshot_viewport(*args):
    """Save a PNG of the current viewport next to the project so the
    builder (or chat) can look at the actual model. Frame the model first."""
    if not MAYA:
        print("Run inside Maya Script Editor.")
        return None
    import os
    try:
        try:
            ws = cmds.workspace(q=True, rd=True)
        except Exception:
            ws = None
        outdir = os.path.join(ws, "images") if ws else os.path.expanduser("~")
        try:
            os.makedirs(outdir, exist_ok=True)
        except Exception:
            pass
        path = os.path.join(outdir, "bigfoot_snapshot.png").replace("\\", "/")
        try:
            if os.path.exists(path):
                os.remove(path)
        except Exception:
            pass
        try:
            cmds.select("Bigfoot_GRP", replace=True)
        except Exception:
            pass
        t = cmds.currentTime(q=True)
        try:
            cmds.viewFit(fitFactor=0.9)
        except Exception:
            pass
        cmds.playblast(completeFilename=path, format="image", viewer=False,
                       showOrnaments=False, frameOnly=False,
                       startTime=t, endTime=t, compression="png", quality=100,
                       widthHeight=[1600, 900], percent=100)
        print("Snapshot saved: %s" % path)
        try:
            cmds.inViewMessage(amg="Snapshot saved - tell chat to look", pos="midCenter", fade=True)
        except Exception:
            pass
        return path
    except Exception as e:
        import traceback
        traceback.print_exc()
        try:
            cmds.confirmDialog(t="Snapshot failed", m="%s" % e, b=["OK"], db="OK")
        except Exception:
            pass
        return None

# ------------------------------------------------------------
# LIVE UPDATE - every control rebuilds the model as you drag it.
# Drag ticks are throttled (0.6s) so the viewport stays usable;
# release/typing rebuilds immediately. Camera is left alone while live.
# ------------------------------------------------------------
_LIVE_BUILD = False
_last_live = [0.0]

_CHUNK_OPEN = False

def _perf_freeze(on):
    """Speed + grading habit in one: viewport redraws suspend during the
    ~200 build commands, and the whole build is wrapped in ONE undo chunk
    (openChunk/closeChunk) so one Ctrl+Z removes exactly what the tool made.
    The _CHUNK_OPEN flag keeps open/close balanced on every path."""
    global _CHUNK_OPEN
    if not MAYA:
        return
    try:
        if on:
            if not _CHUNK_OPEN:
                try:
                    cmds.undoInfo(openChunk=True)
                    _CHUNK_OPEN = True
                except Exception:
                    pass
            try:
                cmds.refresh(suspend=True)
            except Exception:
                pass
        else:
            try:
                cmds.refresh(suspend=False)
            except Exception:
                pass
            try:
                cmds.refresh(force=True)
            except Exception:
                pass
            if _CHUNK_OPEN:
                try:
                    cmds.undoInfo(closeChunk=True)
                except Exception:
                    pass
                finally:
                    _CHUNK_OPEN = False
    except Exception:
        pass

def live_update(*args, **kwargs):
    global _LIVE_BUILD, _lastCommitted
    if not MAYA:
        return
    throttle = kwargs.get("throttle", 0.0)
    if throttle > 0:
        now = time.time()
        if now - _last_live[0] < throttle:
            return
        _last_live[0] = now
    _LIVE_BUILD = True
    try:
        before = _lastCommitted
        build_bigfoot()
        after = _snap_params()
        # committed steps only (release/preset): drag ticks just refresh
        if throttle == 0.0 and before is not None and after != before:
            _undoStack.append(before)
            del _undoStack[:-MAXHIST]
            del _redoStack[:]
        _lastCommitted = after
    finally:
        _LIVE_BUILD = False

def _on_drag(*args):
    live_update(throttle=0.3)

def _on_change(*args):
    live_update()

# ------------------------------------------------------------
# UNDO / REDO - 10 steps of builder history (slider states).
# Live rebuilds bypass Maya's native undo queue, so the history
# lives here instead. Committed on release, preset, randomize.
# ------------------------------------------------------------
MAXHIST = 10
_undoStack = []
_redoStack = []
_lastCommitted = None

def _snap_params():
    try:
        P = collect_params()
    except Exception:
        return None
    if not P:
        return None
    clean = {}
    for k, v in P.items():
        if isinstance(v, list):
            v = tuple(v)
        clean[k] = v
    return clean

def _restore_params(P):
    if not P:
        return
    _set_f("height", P.get("height", 7.6))
    _set_f("bulk", P.get("bulk", 1.25))
    _set_f("belly", P.get("belly", 0.45))
    _set_f("glutes", P.get("glutes", 1.0))
    _set_f("chestW", P.get("chestW", 1.30))
    _set_f("shoulderW", P.get("shoulderW", 1.35))
    _set_f("hunch", P.get("hunch", 0.55))
    _set_f("neck", P.get("neck", 0.20))
    _set_f("head", P.get("headSize", 1.05))
    _set_f("crestH", P.get("crestH", 0.85))
    _set_f("crestW", P.get("crestW", 0.90))
    _set_f("brow", P.get("brow", 0.85))
    _set_f("eye", P.get("eyeSize", 0.65))
    _set_f("eyeDepth", P.get("eyeDepth", 0.70))
    _set_f("noseW", P.get("noseW", 1.10))
    _set_f("muzzle", P.get("muzzle", 0.35))
    _set_f("jawW", P.get("jawW", 1.05))
    _set_f("beard", P.get("beard", 0.60))
    _set_f("armL", P.get("armL", 1.28))
    _set_f("upperArm", P.get("upperArm", 1.15))
    _set_f("forearm", P.get("forearm", 1.25))
    _set_f("handSize", P.get("handSize", 1.20))
    _set_f("fingerL", P.get("fingerL", 1.00))
    _set_f("fingerT", P.get("fingerT", 1.15))
    _set_f("legL", P.get("legL", 1.00))
    _set_f("thigh", P.get("thigh", 1.20))
    _set_f("calf", P.get("calf", 1.05))
    _set_f("footL", P.get("footL", 1.60))
    _set_f("footW", P.get("footW", 1.25))
    _set_f("toeL", P.get("toeL", 1.00))
    _set_f("wrinkles", P.get("wrinkles", 0.75))
    _set_col("furCol", P.get("furColor", (0.16, 0.13, 0.10)))
    _set_col("skinCol", P.get("skinColor", (0.30, 0.25, 0.20)))
    _set_col("noseCol", P.get("noseColor", (0.10, 0.08, 0.07)))
    _set_col("lipsCol", P.get("lipsColor", (0.12, 0.08, 0.07)))
    _set_col("nailsCol", P.get("nailsColor", (0.16, 0.14, 0.12)))
    _set_col("toesCol", P.get("toesColor", (0.30, 0.25, 0.20)))
    _set_f("grey", P.get("greyAmt", 0.15))
    _set_f("chestBald", P.get("chestBald", 0.55))
    _set_f("stance", P.get("stance", 0.55))
    _set_f("kneeBend", P.get("kneeBend", 0.35))
    _set_f("elbowBend", P.get("elbowBend", 0.20))
    _set_f("headPitch", P.get("headPitch", 0.25))
    _set_f("walkPose", P.get("walkPose", 0.65))
    _set_opt("preset", P.get("presetName", ""))

def undo_step(*args):
    global _lastCommitted
    if not MAYA:
        return
    if not _undoStack:
        print("Undo: nothing to undo (10-step history).")
        return
    if _lastCommitted is not None:
        _redoStack.append(_lastCommitted)
        del _redoStack[:-MAXHIST]
    _lastCommitted = _undoStack.pop()
    _restore_params(_lastCommitted)
    build_bigfoot()
    print("Undo (%d left)." % len(_undoStack))

def redo_step(*args):
    global _lastCommitted
    if not MAYA:
        return
    if not _redoStack:
        print("Redo: nothing to redo.")
        return
    if _lastCommitted is not None:
        _undoStack.append(_lastCommitted)
        del _undoStack[:-MAXHIST]
    _lastCommitted = _redoStack.pop()
    _restore_params(_lastCommitted)
    build_bigfoot()
    print("Redo (%d left)." % len(_redoStack))

# ------------------------------------------------------------
# UI
# ------------------------------------------------------------
def _slider(parent, key, label, minv, maxv, val):
    UI[key] = cmds.floatSliderGrp(l=label, f=True, min=minv, max=maxv, v=val,
                                  pre=2, cw=[(1, 110), (2, 60)], cal=[(1, "left")],
                                  dc=_on_drag, cc=_on_change, p=parent)

def _color(parent, key, label, val):
    UI[key] = cmds.colorSliderGrp(l=label, rgbValue=val, cw=[(1, 110), (2, 80)],
                                  cal=[(1, "left")], cc=_on_change, p=parent)

def _opt(parent, key, label, items, default):
    UI[key] = cmds.optionMenu(l=label, p=parent, cc=_on_change)
    for it in items:
        cmds.menuItem(l=it)
    try:
        cmds.optionMenu(UI[key], e=True, v=default)
    except Exception:
        pass

def _chk(parent, key, label, val):
    UI[key] = cmds.checkBox(l=label, v=bool(val), p=parent, cc=_on_change)

def show_ui():
    if cmds.window(WIN, exists=True):
        cmds.deleteUI(WIN)
    w = cmds.window(WIN, title="Bigfoot Builder - Sculpt Detail", width=500, height=920,
                    sizeable=True, resizeToFitChildren=False)
    main = cmds.scrollLayout(childResizable=True, p=w)
    cmds.text(l="BIGFOOT BUILDER - sculpt detail, no rig", font="boldLabelFont", h=26, p=main)
    cmds.text(l="Matched to ref: crest / hooded eyes / stern mouth / huge feet / shag", h=20, p=main)

    f0 = cmds.frameLayout(l="1. PRESET", cll=True, cl=False, p=main)
    c0 = cmds.columnLayout(adj=True, p=f0)
    _opt(c0, "preset", "Preset:", list(PRESETS.keys()), "Reference Classic (image)")
    cmds.rowLayout(nc=2, adjustableColumn=2, p=c0)
    cmds.button(l="Apply Preset", c=apply_preset, h=32)
    cmds.button(l="RANDOMIZE", c=randomize_bigfoot, h=32, bgc=(0.5, 0.25, 0.15))
    cmds.setParent("..")
    cmds.text(l="Tip: every slider rebuilds the model live.", h=18, p=c0)

    f1 = cmds.frameLayout(l="2. BODY", cll=True, cl=False, p=main)
    c1 = cmds.columnLayout(adj=True, p=f1)
    _slider(c1, "height", "Height (ft)", 6.0, 9.0, 7.6)
    _slider(c1, "bulk", "Bulk", 0.7, 1.8, 1.25)
    _slider(c1, "belly", "Belly", 0.0, 1.2, 0.45)
    _slider(c1, "glutes", "Glutes", 0.6, 1.4, 1.00)
    _slider(c1, "chestW", "Chest Width", 0.8, 1.7, 1.30)
    _slider(c1, "shoulderW", "Shoulder Width", 0.8, 1.8, 1.35)
    _slider(c1, "hunch", "Hunch", 0.0, 1.0, 0.55)
    _slider(c1, "neck", "Neck Length", 0.0, 1.0, 0.20)

    f2 = cmds.frameLayout(l="3. HEAD / FACE", cll=True, cl=False, p=main)
    c2 = cmds.columnLayout(adj=True, p=f2)
    _slider(c2, "head", "Head Size", 0.7, 1.4, 1.05)
    _slider(c2, "crestH", "Crest Height", 0.0, 1.3, 0.85)
    _slider(c2, "crestW", "Crest Width", 0.5, 1.3, 0.90)
    _slider(c2, "brow", "Brow Ridge", 0.0, 1.2, 0.85)
    _slider(c2, "eye", "Eye Size", 0.3, 1.4, 0.65)
    _slider(c2, "eyeDepth", "Eye Sunken", 0.0, 1.2, 0.70)
    _slider(c2, "noseW", "Nose Width", 0.6, 1.6, 1.10)
    _slider(c2, "muzzle", "Muzzle Out", 0.0, 1.0, 0.35)
    _slider(c2, "jawW", "Jaw Width", 0.6, 1.5, 1.05)
    _slider(c2, "beard", "Beard / Chin", 0.0, 1.2, 0.60)
    _slider(c2, "wrinkles", "Face Wrinkles", 0.0, 1.0, 0.75)

    f3 = cmds.frameLayout(l="4. ARMS / HANDS", cll=True, cl=False, p=main)
    c3 = cmds.columnLayout(adj=True, p=f3)
    _slider(c3, "armL", "Arm Length", 0.9, 1.6, 1.28)
    _slider(c3, "upperArm", "Upper Arm", 0.6, 1.7, 1.15)
    _slider(c3, "forearm", "Forearm", 0.6, 1.7, 1.25)
    _slider(c3, "handSize", "Hand Size", 0.7, 1.6, 1.20)
    _slider(c3, "fingerL", "Finger Length", 0.5, 1.6, 1.00)
    _slider(c3, "fingerT", "Finger Thick", 0.5, 1.7, 1.15)

    f4 = cmds.frameLayout(l="5. LEGS / BIG FEET", cll=True, cl=False, p=main)
    c4 = cmds.columnLayout(adj=True, p=f4)
    _slider(c4, "legL", "Leg Length", 0.7, 1.4, 1.00)
    _slider(c4, "thigh", "Thigh Thick", 0.6, 1.7, 1.20)
    _slider(c4, "calf", "Calf Thick", 0.6, 1.6, 1.05)
    _slider(c4, "footL", "FOOT Length", 1.0, 2.0, 1.60)
    _slider(c4, "footW", "Foot Width", 0.8, 1.7, 1.25)
    _slider(c4, "toeL", "Toe Length", 0.4, 1.6, 1.00)

    f5 = cmds.frameLayout(l="6. COLORS (flat lambert)", cll=True, cl=False, p=main)
    c5 = cmds.columnLayout(adj=True, p=f5)
    _color(c5, "furCol", "Fur Color:", (0.16, 0.13, 0.10))
    _color(c5, "skinCol", "Skin Color:", (0.30, 0.25, 0.20))
    _color(c5, "noseCol", "Nose Color:", (0.10, 0.08, 0.07))
    _color(c5, "lipsCol", "Lips Color:", (0.12, 0.08, 0.07))
    _color(c5, "nailsCol", "Nails Color:", (0.16, 0.14, 0.12))
    _color(c5, "toesCol", "Toes Color:", (0.30, 0.25, 0.20))
    _slider(c5, "grey", "Grey Age", 0.0, 1.0, 0.15)
    _slider(c5, "chestBald", "Chest Baldness", 0.0, 1.0, 0.55)

    f6 = cmds.frameLayout(l="7. POSE / FINISH", cll=True, cl=False, p=main)
    c6 = cmds.columnLayout(adj=True, p=f6)
    _slider(c6, "stance", "Stance Width", 0.2, 1.0, 0.55)
    _slider(c6, "kneeBend", "Knee Bend", 0.0, 1.0, 0.35)
    _slider(c6, "elbowBend", "Elbow Bend", 0.0, 1.0, 0.20)
    _slider(c6, "headPitch", "Head Pitch", 0.0, 1.0, 0.25)
    _slider(c6, "walkPose", "Walk Stride", 0.0, 1.0, 0.65)

    fb = cmds.frameLayout(l="ACTIONS (model updates live - no build step)", cll=False, p=main)
    cb = cmds.columnLayout(adj=True, p=fb)
    cmds.rowLayout(nc=4, adjustableColumn=2, p=cb)
    cmds.button(l="Delete", c=delete_bigfoot)
    cmds.button(l="Apply Preset", c=apply_preset)
    cmds.button(l="Randomize", c=randomize_bigfoot)
    cmds.button(l="Snapshot", c=snapshot_viewport)
    cmds.setParent("..")
    cmds.rowLayout(nc=2, adjustableColumn=2, p=cb)
    cmds.button(l="Undo (10 steps)", c=undo_step)
    cmds.button(l="Redo (10 steps)", c=redo_step)
    cmds.setParent("..")
    cmds.text(l="Result: Bigfoot_GRP with flat lambert colors.", h=22, p=cb)
    cmds.text(l="Snapshot saves a viewport PNG - then tell chat to look at it.", h=20, p=cb)

    cmds.showWindow(w)
    try:
        apply_preset()
    except Exception:
        pass

if MAYA:
    show_ui()
else:
    print("Loaded outside Maya - open in Maya Script Editor to run.")

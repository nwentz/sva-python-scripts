1) This is the preset the user can choose to use and edit in the big foot builder.



PRESETS = {



2) This displays the default height, bulk, belly, and chest width in feet plus inches. Able to be manipulated as by sliders in the GUI.



        "height": 7.6, "bulk": 1.25, "belly": 0.45, "chestW": 1.30,



3) Shows the fur and skin colors rgb settings that the user can adjust for their desired colors.



        "furColor": (0.16, 0.13, 0.10), "skinColor": (0.30, 0.25, 0.20),



4) Is the amount of greyness/age the big foot has, the fur length and fur density is also a leftover from when the agent tried a fur simulator. I don't know why it's still there even after I told the agent to not have a fur texture.



        "greyAmt": 0.15, "furLength": 0.70, "furDensity": 0.80,



5) Refers to adjustable stance width, the bending of the knee and elbow backwards. Scaleable in feet and inches.



        "stance": 0.55, "kneeBend": 0.35, "elbowBend": 0.20,



6) Is the head angle leaning forward and the walk stance backwards as though the big foot were in the middle of walking. Is adjustable via sliders.



        "headPitch": 0.25, "walkPose": 0.65,



7) Define make lambert. I think this labels the name of what is being colored and the color itself which is adjustable.



def make_lambert(name, color):



8) Command for setting the attribute of the object plus colors. I don't know what type=double3 means.



                    cmds.setAttr(name + ".color", color[0], color[1], color[2], type="double3")



9) Define build the big foot builder arguments. This defines how the script builds the big foot.
 


def build_bigfoot(*args):



10) Clears the old model scalable parts so the user can see the new adjustments with the same materials.


    
        clear_old(keep_materials=_LIVE_BUILD)



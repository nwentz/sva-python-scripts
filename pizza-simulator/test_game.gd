extends Node

func _ready() -> void:
	print("=== Pizza Simulator Test ===\n")

	# Check project structure
	var scripts_dir = DirAccess.open("res://scripts")
	if scripts_dir:
		var files = scripts_dir.list_dir_start()
		print("Found scripts directory:")
		var script_count = 0
		while files:
			if files.get_extension() == "gd":
				print("  ✓ %s" % files)
				script_count += 1
			files = scripts_dir.list_dir_next()
		print("\nTotal scripts found: %d" % script_count)
	else:
		print("  ✗ Scripts directory not found")

	# Check scene files
	var scenes_dir = DirAccess.open("res://scenes")
	if scenes_dir:
		print("\nFound scenes directory:")
		var scene_files = ["main.tscn", "character.tscn", "pizza.tscn", "ui_hud.tscn"]
		for scene_file in scene_files:
			var test_path = "res://scenes/%s" % scene_file
			print("  - %s" % scene_file)
	else:
		print("\n  ✗ Scenes directory not found")

	print("\n=== Test Complete ===")
	print("Check console for any syntax errors in Godot Editor")

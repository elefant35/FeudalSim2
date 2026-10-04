extends SceneTree
## Headless test runner: runs every test_*.gd in res://tests. Each test file extends TestCase.
## Run: Godot --headless --path . -s res://tests/run_tests.gd

func _initialize() -> void:
	# Let autoloads finish _ready before testing.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var failed := 0
	var passed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			printerr("FAIL %s  could not be loaded (parse error?)" % file)
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			tc.tree = self
			tc.call(name)
			if tc.failures.is_empty():
				passed += 1
			else:
				failed += 1
				for f in tc.failures:
					printerr("FAIL %s::%s  %s" % [file, name, f])
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

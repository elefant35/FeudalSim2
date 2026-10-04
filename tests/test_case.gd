class_name TestCase
extends RefCounted
## Minimal assertions for headless tests.

var failures: Array[String] = []
var tree: SceneTree


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append(msg if msg != "" else "check failed")


func eq(a: Variant, b: Variant, msg: String = "") -> void:
	if a != b:
		failures.append("%s expected %s, got %s" % [msg, str(b), str(a)])


func rng(seed_value: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

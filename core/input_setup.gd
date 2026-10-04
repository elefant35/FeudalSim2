class_name InputSetup
extends RefCounted
## Registers the game's input actions in code (keeps project.godot short and readable).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "interact": [KEY_E], "eat": [KEY_F],
	"inventory": [KEY_TAB, KEY_I], "speed": [KEY_T], "pause": [KEY_ESCAPE], "guide": [KEY_G],
}
const BUTTONS := {"primary": MOUSE_BUTTON_LEFT, "secondary": MOUSE_BUTTON_RIGHT}


static func ensure() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action: String in BUTTONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = BUTTONS[action]
		InputMap.action_add_event(action, mb)

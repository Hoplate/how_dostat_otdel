extends Node

const PATH = "user://profile.json"
const DEFAULT_KEYS = {
	"move_up":KEY_W, "move_down":KEY_S, "move_left":KEY_A, "move_right":KEY_D,
	"interact":KEY_E, "sneak":KEY_CTRL, "innocent":KEY_Q, "inspect":KEY_TAB, "recenter":KEY_F
}
var data: Dictionary = {"version":2,"unlocked":0,"best":{},"session":{},"difficulty":"normal","volume":0.5,"keys":{}}
var test_mode = false
var last_error = ""

func _ready() -> void:
	test_mode = "--self-test" in OS.get_cmdline_user_args()
	if not test_mode:
		for path in [PATH,PATH+".bak"]:
			if not FileAccess.file_exists(path):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary and int(parsed.get("version",0)) == 2:
				data.merge(parsed,true)
				break
	data.unlocked = clampi(int(data.unlocked),0,9)
	if not data.best is Dictionary:
		data.best = {}
	if not data.session is Dictionary:
		data.session = {}
	if not data.keys is Dictionary:
		data.keys = {}
	if not data.difficulty in ["easy","normal","hard"]:
		data.difficulty = "normal"
	data.volume = clampf(float(data.volume),0,1)
	apply_keys()
	apply_volume()

func apply_keys() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key = InputEventKey.new()
		key.physical_keycode = int(data.keys.get(action,DEFAULT_KEYS[action]))
		InputMap.action_add_event(action,key)
	var arrows = {"move_up":KEY_UP,"move_down":KEY_DOWN,"move_left":KEY_LEFT,"move_right":KEY_RIGHT}
	for action in arrows:
		var key = InputEventKey.new()
		key.physical_keycode = arrows[action]
		InputMap.action_add_event(action,key)

func key_label(action: String) -> String:
	return OS.get_keycode_string(int(data.keys.get(action,DEFAULT_KEYS[action])))

func rebind(action: String, key: int) -> bool:
	if key in [KEY_ESCAPE,KEY_SPACE,KEY_F11,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		return false
	for other in DEFAULT_KEYS:
		if other != action and int(data.keys.get(other,DEFAULT_KEYS[other])) == key:
			return false
	data.keys[action] = key
	apply_keys()
	save()
	return true

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.001,float(data.volume))))
	AudioServer.set_bus_mute(0,float(data.volume) <= 0.001)

func save() -> void:
	if test_mode:
		return
	last_error = ""
	var temp = PATH+".tmp"
	var f = FileAccess.open(temp,FileAccess.WRITE)
	if f == null:
		last_error = "Не удалось сохранить прогресс: нет доступа к папке игры."
		push_warning(last_error)
		return
	f.store_string(JSON.stringify(data))
	f.flush()
	f.close()
	var src = ProjectSettings.globalize_path(temp)
	var dst = ProjectSettings.globalize_path(PATH)
	var backup = dst+".bak"
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(PATH+".bak"):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(dst,backup) != OK:
			last_error = "Не удалось обновить файл сохранения."
			return
	if DirAccess.rename_absolute(src,dst) != OK:
		last_error = "Не удалось записать сохранение; предыдущая копия сохранена."
		if FileAccess.file_exists(PATH+".bak"):
			DirAccess.rename_absolute(backup,dst)

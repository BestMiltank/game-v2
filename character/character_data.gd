extends RefCounted

const WEAPONS := {"bow":"bow", "THW":"greatsword", "spear":"spear"}

static func read(path: String) -> Dictionary:
	var result = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(result is Dictionary, "Missing or invalid character data: " + path)
	return result

static func weapon_path(prefix: String, file: String) -> String:
	return "res://weapons/%s/%s" % [WEAPONS[prefix],file]

static func rig() -> Dictionary:
	var result := read("res://character/data/rig.json")
	result.equipment = {}
	for prefix in WEAPONS:
		result.equipment[WEAPONS[prefix]] = read(weapon_path(prefix,"equipment.json"))
	return result

static func clips() -> Dictionary:
	var result := {}
	for prefix in WEAPONS:
		result.merge(read(weapon_path(prefix,"clips.json")))
	return result

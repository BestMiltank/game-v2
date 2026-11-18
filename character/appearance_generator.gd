extends RefCounted
## HumanAppearance.setupAppearance + HumanAppearanceDataMgr for the source hero flags.
const SourceRandom = preload("appearance_rng.gd")

static func generate(seed_value: int, source: Dictionary) -> Dictionary:
	var config: Dictionary = source.appearance_source
	for flag in config.character_random_flags.values():
		assert(bool(flag), "This verified profile requires the source hero random flags")
	assert(not bool(config.character_isClothesRandom))
	var dna := absi(seed_value % 1000)
	var rng := SourceRandom.new()
	rng.init_state(dna)
	var sex := 0 if rng.range_int(0, 100) < 75 else 1
	var skin_roll := rng.range_int(0, 100)
	var skin := 0 if skin_roll < 40 else (1 if skin_roll < 70 else 2)
	var prefix := "man_" if sex == 0 else "woman_"
	var color: Array = config.hair_color[rng.range_int(0, config.hair_color.size())]
	var eyes: Array = config[prefix + "eyes"]
	var eye_id := str(int(eyes[rng.range_int(0, eyes.size())][1]))
	var hair: Array = config[prefix + "haircuts"]
	var hair_id := str(int(hair[rng.range_int(0, hair.size())][1]))
	var feature_id := ""
	if rng.range_int(0, 100) < int(config[prefix + "FaceFeature_prob"]):
		var features: Array = config[prefix + "faceFeature"]
		feature_id = str(int(features[rng.range_int(0, features.size())][1]))
	var skin_set: Array = []
	for candidate in config[prefix + "skin_sprites"]:
		if int(candidate[0]) == skin:
			skin_set = candidate
	assert(not skin_set.is_empty())
	return {"dna":dna,"sex":sex,"skin":skin,"color":color.duplicate(),"parts":{
		"noumenon/body/head":str(int(skin_set[2])),"noumenon/body":str(int(skin_set[4])),
		"noumenon/Lhand":str(int(skin_set[6])),"noumenon/Rhand":str(int(skin_set[6])),
		"noumenon/body/head/eyes":eye_id,"noumenon/body/head/hair":hair_id,
		"noumenon/body/head/faceFeature":feature_id}}

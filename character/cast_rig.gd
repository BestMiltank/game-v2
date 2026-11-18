extends "pose_sampler.gd"
## New authored textures on the verified source hierarchy; no pose corrections.
var cast_data := Data.read("res://character/data/presets.json")
var cast_index := 0

func _ready() -> void:
	source.assets.merge(cast_data.assets)
	super._ready()

func _render_state() -> void:
	assert(clip_name in cast_data.allowed_clips, "Clip lacks authored cast assets")
	var preset: Dictionary = cast_data.presets[cast_index]
	for path in preset.parts:
		states[path].sprite = preset.parts[path]
		# Authored full-colour preset, not a second application of source DNA hair tint.
		states[path].color = [1.0, 1.0, 1.0, states[path].color[3]]
	# Keep the source PPtr timeline (including null) and renderer visibility.
	# The mouth changes only when the sampled original mouth sprite is present.
	for state in states.values():
		if state.has("sprite") and cast_data.get("sprite_remap", {}).has(state.sprite):
			state.sprite = cast_data.sprite_remap[state.sprite]
	super._render_state()
	# Authored shoe artwork fit, independent of the source skeleton and curves.
	for path in ["noumenon/Lfoot", "noumenon/Rfoot"]:
		var art: Sprite2D = sprites[path]
		var asset: Dictionary = source.assets[states[path].sprite]
		var fit: Dictionary = asset.get("visual_fit", {})
		art.offset.y += float(fit.get("down", 0.0)) / float(asset.scale)
		art.transform = art.transform.scaled_local(Vector2(float(fit.get("width", 1.0)), 1.0))

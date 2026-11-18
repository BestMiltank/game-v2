extends Node2D
## Samples original Unity polynomial channels; no authored keyframes or pose offsets.

const SourceAppearance = preload("appearance_generator.gd")
const Data = preload("res://character/character_data.gd")
var source := Data.rig()
var restored := {"clips":Data.clips()}
var blend_rules := Data.read("res://character/data/native_blend_rules.json")
var states: Dictionary = {}
var worlds: Dictionary = {}
var sprites: Dictionary = {}
var textures: Dictionary = {}
var weapon := "spear"
var appearance_dna := -1
var appearance: Dictionary = {}
var armor := Data.read("res://character/data/light_armor.json")
var armor_enabled := true
var clip_name := "spear_idle"
var clip_time := 0.0
var rows: Array = []

func _ready() -> void:
	set_equipment("spear")
	sample("spear_idle", 0.0)

func set_equipment(id: String) -> void:
	assert(source.equipment.has(id))
	weapon = id
	for art in sprites.values():
		remove_child(art)
		art.queue_free()
	sprites.clear()
	rows = source.nodes.duplicate(true)
	rows.append_array(source.equipment[id].nodes.duplicate(true))
	for row in rows:
		if "SpriteRenderer" in row.components:
			var art := Sprite2D.new()
			art.name = String(row.path).replace("/", "__")
			art.centered = false
			add_child(art)
			sprites[row.path] = art

func set_appearance(seed_value: int) -> void:
	appearance_dna = absi(seed_value % 1000)
	appearance = SourceAppearance.generate(seed_value, source)

func _channel(keys: Array, time: float) -> float:
	var low := 0
	var high := keys.size()
	while low < high:
		var middle := (low + high) / 2
		if float(keys[middle].time) <= time:
			low = middle + 1
		else:
			high = middle
	var key: Dictionary = keys[maxi(0, low - 1)]
	var c: Array = key.coeff
	var dt := maxf(0.0, time - float(key.time))
	return ((float(c[0]) * dt + float(c[1])) * dt + float(c[2])) * dt + float(c[3])

func _reset_state() -> void:
	states.clear()
	for row in rows:
		states[row.path] = row.duplicate(true)
	if appearance_dna >= 0:
		var look: Dictionary = appearance
		for path in look.parts:
			states[path].sprite = look.parts[path]
		states["noumenon/body/head/hair"].color = look.color.duplicate()
		states["noumenon/body/head/faceFeature"].color = look.color.duplicate()
	if armor_enabled:
		# HumanAppearance.changeArmor is applied after ResetAppearent. The
		# existing clothes/shoulder/boots are Light Armor, including its gloves.
		for path in armor.parts:
			states[path].sprite = armor.parts[path]
		if not String(armor.haircut).is_empty():
			states["noumenon/body/head/hair"].sprite = armor.haircut
		# A null haircut restores initialHairSprite, already supplied above.

func sample(id: String, time: float) -> void:
	_evaluate(id, time)
	_render_state()

func _evaluate(id: String, time: float) -> void:
	var clip: Dictionary = restored.clips[id]
	assert(clip.audit.ready_for_playback)
	if weapon != clip.weapon:
		set_equipment(clip.weapon)
	clip_name = id
	clip_time = clampf(time, 0.0, float(clip.duration))
	_reset_state()
	var values: Array = []
	for keys in clip.streamed_channels:
		values.append(_channel(keys, clip_time))
	assert(int(clip.dense.m_CurveCount) == 0, "Dense curves require verified support")
	values.append_array(clip.constants)
	var quaternion_paths: Dictionary = {}
	for binding in clip.bindings:
		if binding.resolved_property == "localRotation" and binding.status == "bound":
			quaternion_paths[binding.resolved_path] = true
	for binding in clip.bindings:
		if binding.status == "unbound_in_original_character":
			# Same target absence observed in the original 2021.3.25f1 player.
			continue
		assert(states.has(binding.resolved_path))
		var row: Dictionary = states[binding.resolved_path]
		var start := int(binding.channel_start)
		var value: float = values[start]
		match binding.resolved_property:
			"localPosition": row.local_position = values.slice(start, start + 3)
			"localRotation": row.local_rotation = values.slice(start, start + 4)
			"localScale": row.local_scale = values.slice(start, start + 3)
			"localEulerAnglesRaw":
				# Source bow clips also retain Euler hints for quaternion-driven sockets.
				# Native sampling confirms quaternion rotation takes precedence.
				if quaternion_paths.has(binding.resolved_path): continue
				var q := Quaternion(Vector3.UP, deg_to_rad(values[start + 1])) * Quaternion(Vector3.RIGHT, deg_to_rad(values[start])) * Quaternion(Vector3.BACK, deg_to_rad(values[start + 2]))
				row.local_rotation = [q.x, q.y, q.z, q.w]
			"m_Sprite":
				var pid := int(clip.pptr_mapping[roundi(value)].m_PathID)
				row.sprite = str(pid) if pid else ""
			"m_Enabled":
				if int(binding.typeID) == 212: row.renderer_enabled = value != 0
				else: row.collider.enabled = value != 0
			"m_IsActive": row.active = value != 0
			"m_Color.a": row.color[3] = value
			"m_Color.r": row.color[0] = value
			"m_Color.g": row.color[1] = value
			"m_Color.b": row.color[2] = value
			"m_Size.x": row.collider.size[0] = value
			"m_Size.y": row.collider.size[1] = value
			"m_Offset.x": row.collider.offset[0] = value
			"m_Offset.y": row.collider.offset[1] = value
			_: assert(false, "Unsupported original binding: " + str(binding))

func _blend_bool(a: bool, b: bool, weight: float) -> bool:
	if a == b: return a
	# Adjacent float32 boundaries measured by the native bidirectional probe;
	# these are engine adaptation data, not guessed animation timing offsets.
	return weight < float(blend_rules.true_to_false_min) if a else weight >= float(blend_rules.false_to_true_min)

func sample_blend(from_id: String, from_time: float, to_id: String, to_time: float, weight: float) -> void:
	# Native Unity oracle: linear vectors, hemisphere-corrected nlerp rotations;
	# bool switches use native measured boundaries. Unbound PPtr curves
	# do not compete with the other clip's sprite during the blend.
	var sprite_bindings: Dictionary = {}
	for id in [from_id, to_id]:
		sprite_bindings[id] = {}
		for binding in restored.clips[id].bindings:
			if binding.resolved_property == "m_Sprite": sprite_bindings[id][binding.resolved_path] = true
	_evaluate(from_id, from_time)
	var from := states.duplicate(true)
	_evaluate(to_id, to_time)
	for path in states:
		var a: Dictionary = from[path]
		var b: Dictionary = states[path]
		for property in ["local_position", "local_scale", "color"]:
			if not b.has(property): continue
			for i in range(b[property].size()): b[property][i] = lerpf(a[property][i], b[property][i], weight)
		var ar: Array = a.local_rotation
		var br: Array = b.local_rotation
		var qa := Quaternion(ar[0], ar[1], ar[2], ar[3]).normalized()
		var qb := Quaternion(br[0], br[1], br[2], br[3]).normalized()
		if qa.dot(qb) < 0.0: qb = -qb
		var q := (qa * (1.0 - weight) + qb * weight).normalized()
		b.local_rotation = [q.x, q.y, q.z, q.w]
		if b.has("sprite"):
			# Native SHW mouth / spear effect probes retain the source at an exact tie.
			if not sprite_bindings[to_id].has(path) or (sprite_bindings[from_id].has(path) and weight <= 0.5): b.sprite = a.sprite
		for property in ["active", "renderer_enabled"]:
			if a.has(property): b[property] = _blend_bool(bool(a[property]), bool(b[property]), weight)
		if b.has("collider"):
			for property in ["size", "offset"]:
				for i in range(2): b.collider[property][i] = lerpf(a.collider[property][i], b.collider[property][i], weight)
			b.collider.enabled = _blend_bool(bool(a.collider.enabled), bool(b.collider.enabled), weight)
	_render_state()

func _render_state() -> void:
	worlds.clear()
	var visible_in_hierarchy: Dictionary = {}
	for row in rows:
		var path: String = row.path
		var state: Dictionary = states[path]
		var parent_path := path.get_base_dir() if path.contains("/") else ""
		var p: Array = state.local_position
		var q: Array = state.local_rotation
		var s: Array = state.local_scale
		var local := Transform3D(Basis(Quaternion(q[0], q[1], q[2], q[3]).normalized()) * Basis.from_scale(Vector3(s[0], s[1], s[2])), Vector3(p[0], p[1], p[2]))
		var world: Transform3D = worlds.get(parent_path, Transform3D.IDENTITY) * local
		worlds[path] = world
		visible_in_hierarchy[path] = bool(state.active) and visible_in_hierarchy.get(parent_path, true)
		if not sprites.has(path): continue
		var art: Sprite2D = sprites[path]
		var sprite_id: String = state.sprite
		art.visible = visible_in_hierarchy[path] and bool(state.renderer_enabled) and not sprite_id.is_empty()
		if sprite_id.is_empty(): continue
		assert(source.assets.has(sprite_id))
		var asset: Dictionary = source.assets[sprite_id]
		if not textures.has(sprite_id):
			textures[sprite_id] = load(asset.path)
		art.texture = textures[sprite_id]
		art.offset = Vector2(asset.offset[0], asset.offset[1])
		var flip := Vector2(-1 if state.flip_x else 1, -1 if state.flip_y else 1)
		art.transform = Transform2D(Vector2(world.basis.x.x, -world.basis.x.y) * float(asset.scale) * flip.x,
			Vector2(-world.basis.y.x, world.basis.y.y) * float(asset.scale) * flip.y, Vector2(world.origin.x, -world.origin.y) * 100.0)
		var c: Array = state.color
		art.modulate = Color(c[0], c[1], c[2], c[3])
		art.z_index = 10 if path == "shadow" else 200 + roundi(-1000.0 * world.origin.z)

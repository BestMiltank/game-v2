extends SceneTree
const Cast = preload("res://character/cast_rig.gd")
const Source = preload("res://character/pose_sampler.gd")
var checks := 0
var visible_mouth := 0
var visible_eyes := 0
var clip_count := 0
var eye_overlap_checks := 0

func quad(sprite: Sprite2D) -> PackedVector2Array:
	var rect := sprite.get_rect()
	return sprite.transform * PackedVector2Array([rect.position, rect.position+Vector2(rect.size.x,0), rect.end, rect.position+Vector2(0,rect.size.y)])

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var original := Source.new()
	root.add_child(original)
	var rigs: Array = []
	for i in range(6):
		var rig := Cast.new()
		rig.cast_index = i
		root.add_child(rig)
		rigs.append(rig)
	for clip in original.restored.clips:
		if clip.begins_with("SHW_"): continue # Archived, no further maintenance.
		clip_count += 1
		for frame in range(61):
			var time: float = original.restored.clips[clip].duration * frame / 60.0
			original.sample(clip, time)
			for rig in rigs:
				rig.sample(clip, time)
				for path in original.states:
					for field in ["local_position", "local_rotation", "local_scale", "active", "renderer_enabled"]:
						checks += 1
						if original.states[path][field] != rig.states[path][field]:
							push_error(str([clip,frame,rig.cast_index,path,field])); quit(1); return
				var mouth: String = original.states["noumenon/body/head/mouth"].sprite
				var expected: String = "cast/shared/mouth" if mouth == "7128" else mouth
				checks += 1
				if rig.states["noumenon/body/head/mouth"].sprite != expected: quit(2); return
				if rig.sprites["noumenon/body/head/mouth"].visible:
					visible_mouth += 1
					var eye_sprite: Sprite2D = rig.sprites["noumenon/body/head/eyes"]
					if eye_sprite.visible:
						eye_overlap_checks += 1
						if not Geometry2D.intersect_polygons(quad(eye_sprite),quad(rig.sprites["noumenon/body/head/mouth"])).is_empty():
							push_error("Mouth overlaps eyes: "+str([clip,frame,rig.cast_index])); quit(3); return
				for eye in ["eyes_stateB", "eyes_stateC", "eyes_stateD"]:
					if rig.sprites["noumenon/body/head/" + eye].visible:
						visible_eyes += 1
						assert(rig.states["noumenon/body/head/" + eye].sprite == "cast/shared/" + eye)
	# Presence of an expression track does not imply it enables that sprite.
	# Preserve source visibility even if a whole state has zero visible samples.
	var out := "user://qa"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var file := FileAccess.open(out + "/cast-parity.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"checks":checks,"clips":clip_count,"presets":6,"samples":61,"visible_mouth_samples":visible_mouth,"visible_state_eye_samples":visible_eyes,"eye_overlap_checks":eye_overlap_checks}, "\t"))
	file.close()
	print("CAST_ATTACK_PARITY: ",checks," checks passed")
	quit()

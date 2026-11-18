extends SceneTree
## Render matching poses for every look and facing in an isolated viewport.
## Source references use the frozen migration rig. Hammer references use the
## authored weapon revision. Normal runs only read the shipped images.
const TILE := Vector2i(220,280)
const POSES := [
	["bow_idle",0.0],["bow_move",0.15],["bow_attackA",0.24],["bow_attackAAAA",0.3],
	["THW_idle",0.0],["THW_move",0.15],["THW_attackA",0.24],["THW_attackAAAA",0.3],
	["spear_idle",0.0],["spear_move",0.15],["spear_attackA",0.24],["spear_attackAAA",0.3],
	["hammer_idle",0.0],["hammer_move",0.15],["hammer_attackA",0.26],["hammer_attackAAAA",0.47365],
	["hammer_attackAAAA",0.74909],["hammer_attackAAAA",0.86910],["hammer_attackAAAA",0.93576],["hammer_attackAA",0.21]]
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var baseline_dir := "res://tests/baseline"
	var record_source := false
	var record_hammer := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--record-baseline="):
			baseline_dir = arg.trim_prefix("--record-baseline=")
			record_source = true
		elif arg.begins_with("--record-hammer-baseline="):
			baseline_dir = arg.trim_prefix("--record-hammer-baseline=")
			record_hammer = true
	var rig_script = load("res://src/authored_hammer_rig.gd" if record_source else "res://weapons/hammer/authored_hammer_rig.gd")
	var view := SubViewport.new()
	view.size = TILE*Vector2i(6,2)
	view.transparent_bg=true
	view.disable_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var rigs := []
	for side in [1,-1]:
		for look in range(6):
			var rig = rig_script.new()
			rig.cast_index=look
			rig.position=Vector2(look*TILE.x+TILE.x/2.0,(0 if side==1 else TILE.y)+TILE.y-24)
			rig.scale=Vector2(side,1)*0.54
			view.add_child(rig)
			rigs.append(rig)
	var failures := 0
	var pose_count := 0
	for index in POSES.size():
		var clip: String = POSES[index][0]
		if record_source and clip.begins_with("hammer_"): continue
		if record_hammer and not clip.begins_with("hammer_"): continue
		pose_count += rigs.size()
		for rig in rigs: rig.sample(clip,POSES[index][1])
		await process_frame
		await RenderingServer.frame_post_draw
		var result := view.get_texture().get_image()
		var file := baseline_dir.path_join("%02d.png"%index)
		if record_source or record_hammer:
			if result.save_png(file)!=OK: failures+=1
		else:
			var expected:=Image.load_from_file(file)
			if expected==null or expected.get_size()!=result.get_size():
				failures+=1
				continue
			expected.convert(result.get_format())
			if expected.get_data()!=result.get_data():
				for row in range(2):
					for col in range(6):
						var rect:=Rect2i(Vector2i(col,row)*TILE,TILE)
						var differences:=result.get_region(rect).compute_image_metrics(expected.get_region(rect),false)
						if differences.mean>0.0001 or differences.root_mean_squared>0.002:
							push_error("Pose %s look %d side %d: %s"%[POSES[index],col,row,differences])
							failures+=1
	print("PIXEL PARITY: ",pose_count," poses, ",failures," failures")
	quit(1 if failures else 0)

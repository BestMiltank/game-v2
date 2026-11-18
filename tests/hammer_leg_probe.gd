extends SceneTree
const Rig = preload("res://weapons/hammer/authored_hammer_rig.gd")
const Contact = preload("hammer_leg_contact.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rig := Rig.new()
	root.add_child(rig)
	var contact := Contact.new()
	var samples: Array = []
	var checks := 0
	var failures: Array = []
	var out := "user://qa"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hammer-output="): out = arg.trim_prefix("--hammer-output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	if "--preview" in OS.get_cmdline_user_args():
		root.size = Vector2i(960,960)
		root.content_scale_size = Vector2i(960,960)
		root.transparent_bg = true
		rig.position = Vector2(460,880)
		rig.scale = Vector2.ONE*1.5
		rig.cast_index = 1
		for stage in range(rig.hammer_data.attacks.size()):
			for key in rig.hammer_data.attacks[stage].keys:
				rig.sample("hammer_attack"+"A".repeat(stage+1),key[0])
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out.path_join("key-%d-%.2f.png" % [stage,key[0]]))
				print(stage," ",key[0]," ",contact.measure(rig))
		quit()
		return
	for look in range(6):
		rig.cast_index = look
		for stage in range(rig.hammer_data.attacks.size()):
			var attack: Dictionary = rig.hammer_data.attacks[stage]
			var minimum := {"L_hip":INF,"L_ankle":INF,"R_hip":INF,"R_ankle":INF}
			var worst := {}
			for step in range(ceili(attack.duration*120)+1):
				var at := minf(step/120.0,attack.duration)
				rig.sample("hammer_attack"+"A".repeat(stage+1),at)
				var measured := contact.measure(rig)
				for key in measured:
					checks += 1
					# Require opaque area, not just touching bounding rectangles.
					if measured[key] <= 0.0:
						failures.append({"look":look,"stage":stage,"at":at,"joint":key})
					if measured[key] < minimum[key]:
						minimum[key] = measured[key]
						worst[key] = at
			samples.append({"look":look,"stage":stage,"minimum":minimum,"worst_time":worst})
	var suffix := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	FileAccess.open(out.path_join("leg-contact-"+suffix+".json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"fps":120,"samples":samples},"\t"))
	print("HAMMER_LEG_CONTACT: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

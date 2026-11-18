extends SceneTree

const Yard = preload("res://scenes/arena.tscn")
var arena
var actor
var errors: Array[String] = []
var events: Array = []
var frame_index := 0
var output := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func key(code: Key,pressed: bool) -> void:
	var input := InputEventKey.new()
	input.keycode=code
	input.pressed=pressed
	root.push_input(input)

func tap(code: Key) -> void:
	key(code,true)
	key(code,false)

func capture(folder: String,n: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	check(image.save_jpg(folder.path_join("%04d.jpg"%n),0.96)==OK,"save preview frame")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-output="): output=arg.trim_prefix("--demo-output=")
	arena=Yard.instantiate()
	root.add_child(arena)
	arena.set_process(false)
	actor=arena.actor
	actor.slam_contact.connect(func(at: Vector2): events.append({"frame":frame_index,"x":at.x,"y":at.y,"audible":actor.impact.sound.playing}))
	check(actor.weapon_index==2 and actor.clip=="spear_idle","start with spear")
	for look in range(6):
		tap(KEY_1+look)
		check(actor.rig.cast_index==look,"appearance shortcut")
	tap(KEY_2)
	key(KEY_D,true)
	var start: Vector2=actor.position
	arena.advance(.1)
	check(is_equal_approx(actor.position.x-start.x,26.0) and is_equal_approx(actor.time,.13),"movement speed and animation clock")
	tap(KEY_J)
	check(not actor.busy(),"standing start required")
	key(KEY_D,false)
	arena.advance(.01)
	for w in [0,1,2,3]:
		while actor.weapon_index!=w: tap(KEY_E)
		tap(KEY_J)
		arena.advance(.18)
		tap(KEY_ESCAPE)
		var before: float=actor.attacks.time
		arena.advance(.3)
		check(actor.paused and actor.attacks.time==before,"pause freezes the action")
		tap(KEY_ESCAPE)
		tap(KEY_Q)
		key(KEY_A,true)
		arena.advance(.02)
		key(KEY_A,false)
		check(actor.weapon_index==w and actor.facing==1.0,"weapon and facing locked")
		var single_states: Array=[]
		for tick in range(160):
			if actor.attacks.state not in single_states: single_states.append(actor.attacks.state)
			arena.advance(1.0/30)
		check(not actor.busy() and "attackAA" not in single_states,"single press returns to idle")
		var stages: Array=[]
		var buffered: Array=[]
		var event_count:=events.size()
		var folder:=output.path_join(actor.PREFIXES[w])
		if not output.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
		var count:=0
		var idle_frames:=0
		for n in range(170):
			frame_index=n
			if n==10: tap(KEY_J)
			var state: String=actor.attacks.state
			if state.begins_with("attack"):
				if state not in stages: stages.append(state)
				if state not in buffered and actor.attacks.time>=.25 and actor.attacks.next=="":
					if w == 3 and state == "attackAAA": key(KEY_J,true)
					else: tap(KEY_J)
					buffered.append(state)
			arena.advance(1.0/30)
			if not output.is_empty(): await capture(folder,n)
			count=n+1
			if n>10 and not actor.busy(): idle_frames+=1
			if idle_frames>=15: break
		key(KEY_J,false)
		check(stages.size()==[3,4,3,4][w] and not actor.busy(),"full combo "+str(w)+": "+str(stages))
		check(events.size()-event_count==(1 if w==3 else 0),"impact emitted once on hammer finisher")
		if not output.is_empty():
			var info={"fps":30,"frames":count,"events":events.slice(event_count)}
			FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(info))
	check(events.size()==1 and events[0].audible,"audio starts on the sampled impact")
	# A held third tap, a fourth tap, and a canceled hold must all end on the sweep.
	for mode in ["carry","tap","pause","focus","late"]:
		tap(KEY_J)
		arena.advance(.20)
		tap(KEY_J)
		arena.advance(actor.rig.hammer_data.attacks[0].chain_at)
		key(KEY_J,true)
		arena.advance(actor.rig.hammer_data.attacks[1].chain_at)
		check(actor.attacks.index==2,"third tap starts the sweep")
		if mode!="carry":
			key(KEY_J,false)
			if mode=="late": arena.advance(.28)
			key(KEY_J,true)
			arena.advance(.08)
			if mode=="pause":
				tap(KEY_ESCAPE)
				arena.advance(.5)
				tap(KEY_ESCAPE)
			elif mode=="focus": arena._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			elif mode=="tap": key(KEY_J,false)
		arena.advance(.8)
		key(KEY_J,false)
		check(not actor.busy() and events.size()==1,"three taps stop on sweep: "+mode)
	# Right boundary must stop the authored hammer travel too.
	key(KEY_D,true)
	arena.advance(10)
	key(KEY_D,false)
	arena.advance(.01)
	var edge: Vector2=actor.position
	tap(KEY_J)
	for i in range(50): arena.advance(.02)
	check(edge.is_equal_approx(arena.BOUNDS.end*Vector2.RIGHT) and actor.position==edge,"ground displacement respects the boundary")
	key(KEY_A,true)
	arena.advance(.05)
	key(KEY_A,false)
	arena.advance(.01)
	tap(KEY_Q)
	check(actor.clip=="spear_idle" and not actor.rig.hammer.visible and actor.facing<0,"return from hammer to left-facing spear")
	tap(KEY_E)
	actor.position=Vector2.ZERO
	var lights: Array[String]=[]
	var light_frames:=0
	var folder:=output.path_join("hammer-light")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	for n in range(80):
		if n in [8,14,24]: tap(KEY_J)
		arena.advance(1.0/30)
		if actor.busy() and actor.attacks.state not in lights: lights.append(actor.attacks.state)
		if not output.is_empty(): await capture(folder,n)
		light_frames+=1
		if n>10 and not actor.busy() and n>=60: break
	check(lights==["attackA","attackAA","attackAAA"] and not actor.busy(),"left-facing three taps recover after sweep")
	check(is_equal_approx(actor.position.x,-28.2*actor.DISPLAY_SCALE) and events.size()==1,"light chain travels left without a slam")
	if not output.is_empty():
		FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"fps":30,"frames":light_frames,"events":[]}))
	print("YARD INPUT: ",errors.size()," failures")
	quit(1 if errors.size() else 0)

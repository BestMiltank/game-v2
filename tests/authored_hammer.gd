extends SceneTree
const Rig = preload("res://weapons/hammer/authored_hammer_rig.gd")
const OriginalCast = preload("res://character/cast_rig.gd")
const Controller = preload("res://weapons/hammer/authored_hammer_controller.gd")
var checks := 0
var failures: Array = []
var support_reports: Array = []
var slam_report: Dictionary = {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rig := Rig.new()
	root.add_child(rig)
	rig.sample("hammer_idle",0)
	for child in rig.get_children():
		check(child==rig.hammer or child in rig.sprites.values(),"no added character limb nodes")
	for row in rig.rows:
		check(row.path in rig.states,"existing character hierarchy retained")
	# Whole-body motion: rear support rolls toward the toe as the heel lifts.
	var motion := Controller.new(rig.hammer_data)
	var slam: Dictionary = rig.hammer_data.attacks[3]
	check(rig.hammer_data.attacks.size()==4,"three light attacks and a hold finisher")
	check(rig.restored.clips.has("hammer_attackAAAA"),"fourth clip available")
	for stage in range(rig.hammer_data.attacks.size()):
		for step in range(61):
			var at: float = rig.hammer_data.attacks[stage].duration*step/60.0
			rig.sample("hammer_attack"+"A".repeat(stage+1),at)
			var shaft_length: float = rig.hammer_data.height*.70-rig.hammer_data.rear_grip_offset+rig.hammer_data.shape.tail_beyond_rear_grip
			check(is_equal_approx(rig.hammer.head_center.distance_to(rig.hammer.tail_world),shaft_length),"wooden shaft keeps its length during regrip")
			if stage!=1: check(is_zero_approx(rig.hammer.jab_streak),"jab accent limited to second strike")
			check(rig.air_height>=0,"jump never crosses floor")
			check(absf(rig.sprites["shadow"].position.y)<0.001,"ground shadow does not jump with body")
			if stage in [0,3]: check(rig.hammer.head_center.x>45,"hammer head stays outside front of torso")
			var left_foot: Sprite2D = rig.sprites["noumenon/Lfoot"]
			var right_foot: Sprite2D = rig.sprites["noumenon/Rfoot"]
			var clothes: Sprite2D = rig.sprites["noumenon/body/clothes"]
			var eyes: Sprite2D = rig.sprites["noumenon/body/head/eyes"]
			var face: Sprite2D = rig.sprites["noumenon/body/head"]
			check(eyes.visible and eyes.z_index >= face.z_index,"eyes stay in front of head art")
			check(left_foot.z_index<clothes.z_index and right_foot.z_index<clothes.z_index,"clothes remain in front of both boots")
			# Bind-stance ankle span is 38.5 source pixels. Compact steps add at
			# most 12, instead of spreading the shoes toward the body sides.
			check(absf(left_foot.position.x-right_foot.position.x)<=50.5,"foot stride stays compact under the body")
			for hand in rig.grip_points:
				check((rig.roll_transform.affine_inverse()*hand).x>0,"separated grips stay ahead of rolling body")
			check(rig.sprites["noumenon/Lhand"].transform.determinant()<0 and rig.sprites["noumenon/Rhand"].transform.determinant()>0,"rolling retains the distinct spear glove handedness")
	rig.sample("hammer_attackAA",rig.hammer_data.attacks[1].impact_at)
	check(rig.hammer.tail_world.x > 137 and rig.hammer.head_center.x < -25,"jab leads with the extended butt")
	check(rig.hammer.tail_world.distance_to(rig.hammer.grip_world[0])>=71.9 and rig.hammer.jab_streak>.99,"extended grip and motion lines at jab contact")
	var tail_at_contact: float = rig.hammer.tail_world.x + motion.motion_at(1,.25)
	rig.sample("hammer_attackAA",.165)
	check(tail_at_contact - rig.hammer.tail_world.x > 60,"jab thrusts the pommel forward after winding")
	rig.sample("hammer_attackAAA",.09)
	var backswing: Vector3 = rig.hammer.head_center
	rig.sample("hammer_attackAAA",rig.hammer_data.attacks[2].impact_at)
	check(rig.hammer.head_center.x-backswing.x>200 and absf(rig.hammer.head_center.y-backswing.y)<25,"sweep crosses the body at waist level")
	var sweep: Dictionary = rig.hammer_data.attacks[2]
	var planted_head := rig.sprites["noumenon/body/head"] as Sprite2D
	var at_contact := planted_head.transform*planted_head.get_rect().get_center()
	rig.sample("hammer_attackAAA",.32)
	var follow := planted_head.transform*planted_head.get_rect().get_center()-at_contact
	check(follow.x>4 and follow.y>2,"shoulder and head follow through after sweep contact")
	# The three silhouettes must read for at least four 30 Hz frames before chaining.
	for beat in [[0,.26,.41],[1,.21,.345],[2,.32,.45]]:
		var held_pose: Array = rig.pose_at(beat[0],beat[1])
		for frame in range(1,9):
			var at := lerpf(beat[1],beat[2],frame/8.0)
			var sampled: Array = rig.pose_at(beat[0],at)
			# The wind lines may fade while the weapon, body and boots hold position.
			for column in range(1,25):
				check(is_equal_approx(sampled[column],held_pose[column]),"grounded follow-through holds its silhouette")
			check(is_equal_approx(motion.motion_at(beat[0],at),motion.motion_at(beat[0],beat[1])),"no sliding during the beat")
	for spec in [[0,.12,.26,"Rfoot"],[2,sweep.plant_at,.375,"Lfoot"]]:
		var positions: Array[float] = []
		var heights: Array[float] = []
		for step in range(21):
			var at := lerpf(spec[1],spec[2],step/20.0)
			rig.sample("hammer_attack"+"A".repeat(spec[0]+1),at)
			var foot: Sprite2D = rig.sprites["noumenon/"+spec[3]]
			# Painted sole after the authored shoe's downward visual registration.
			var point := foot.transform*Vector2(56,48) if spec[3]=="Rfoot" else foot.position
			positions.append(point.x+motion.motion_at(spec[0],at))
			heights.append(point.y)
		var drift_x: float = positions.max()-positions.min()
		var drift_y: float = heights.max()-heights.min()
		support_reports.append({"stage":spec[0],"part":spec[3],"drift_x":drift_x,"drift_y":drift_y})
		# Position/rotation are authored keys, so arc interpolation can vary
		# by less than half a source pixel; no runtime foot-lock solver.
		check(drift_x<0.5 and drift_y<0.5,"support contact remains planted during root travel")
	for spec in [[0,.26],[3,slam.impact_at]]:
		rig.sample("hammer_attack"+"A".repeat(spec[0]+1),spec[1])
		var foot: Sprite2D = rig.sprites["noumenon/Rfoot"]
		var toe: Vector2 = foot.transform*Vector2(56,48)
		var heel: Vector2 = foot.transform*Vector2(-56,48)
		# Judge heel lift relative to sole length as the authored shoe narrows.
		check((toe.y-heel.y)/toe.distance_to(heel)>0.25,"forward push visibly lifts the rear heel")
		var leg: Sprite2D = rig.sprites["noumenon/body/R_leg"]
		check(leg.transform.y.normalized().x < -0.35,"rear trouser tilts from hip toward trailing foot")
	rig.sample("hammer_attackAAAA",slam.inverted_at)
	var head: Sprite2D = rig.sprites["noumenon/body/head"]
	var boot: Sprite2D = rig.sprites["noumenon/Lfoot"]
	check(rig.air_height>150 and head.position.y>boot.position.y,"finisher visibly turns head below feet in midair")
	check(head.position.y<0 and boot.position.y<0,"inverted character remains clear of floor")
	check(rig.sprites["shadow"].modulate.a>0.3,"high jump retains grounded visible shadow")
	var total_rotation := 0.0
	var previous_rotation := 0.0
	var previous_speed := 0.0
	var roll_step: float = (slam.roll_complete_at-slam.roll_start_at)/100.0
	for step in range(101):
		var at := lerpf(slam.roll_start_at,slam.roll_complete_at,step/100.0)
		rig.sample("hammer_attackAAAA",at)
		if step>0:
			var angle_step := wrapf(rig.hammer.rotation-previous_rotation,-PI,PI)
			var speed := angle_step/roll_step
			check(speed>previous_speed,"somersault continues accelerating through the apex")
			previous_speed = speed
			total_rotation += angle_step
		previous_rotation = rig.hammer.rotation
	check(absf(total_rotation-TAU)<0.001,"held hammer and character complete one forward turn before slam")
	rig.sample("hammer_attackAAAA",slam.foot_plant_at)
	for ring in rig.hammer.POMMEL_PROFILE:
		var axis: Vector3 = rig.hammer.shaft_direction
		var ring_y: float = rig.hammer.tail_world.y+ring.x*axis.y
		check(ring_y-ring.y*sqrt(1.0-axis.y*axis.y)>=0.0,"rounded pommel clears ground at foot plant")
	check(is_zero_approx(rig.air_height) and rig.hammer.shaft_direction.y>0.85,"plant with the hammer held high")
	var grounded_boot := boot.transform
	var previous_y := -INF
	var previous_drop := 0.0
	for frame in range(4):
		rig.sample("hammer_attackAAAA",slam.impact_at-(3-frame)/30.0)
		var head_y: float = rig.HammerWeapon.project(rig.hammer.head_center).y
		if frame>0:
			check(head_y-previous_y>previous_drop,"each final frame drops the hammer farther")
			previous_drop=head_y-previous_y
		check(boot.transform.is_equal_approx(grounded_boot),"support foot stays planted for the swing")
		previous_y=head_y
	rig.sample("hammer_attackAAAA",slam.impact_at)
	check(is_zero_approx(rig.air_height),"heavy slam lands on ground")
	# Ground is the weapon projection's world Y=0 plane, not a single screen
	# scanline. Every vertex on the actual striking cap must meet that plane.
	var cap_height_error := 0.0
	for vertex in rig.hammer.cap_world[0]:
		cap_height_error=maxf(cap_height_error,absf(vertex.y))
		check(absf(vertex.y)<0.001,"entire striking face lies flat on the ground")
	var clothes: Sprite2D = rig.sprites["noumenon/body/clothes"]
	var torso_center := clothes.transform*clothes.get_rect().get_center()
	var rear_hand_gap: float = rig.grip_points[0].distance_to(torso_center)
	check(rear_hand_gap<45,"rear hand stays beside torso instead of detached above the head")
	var landed_center: Vector2 = rig.HammerWeapon.project(rig.hammer.head_center)
	var previous_head_y := -INF
	var fall_distance := 0.0
	for step in range(41):
		rig.sample("hammer_attackAAAA",lerpf(slam.roll_complete_at,slam.impact_at,step/40.0))
		var center: Vector2 = rig.hammer.transform*rig.HammerWeapon.project(rig.hammer.head_center)
		check(center.y>=previous_head_y-0.01,"head continuously descends from completed roll into ground contact")
		if step==0: fall_distance=landed_center.y-center.y
		previous_head_y=center.y
	check(fall_distance>200,"finisher has a substantial downward strike rather than a forward push")
	slam_report={"striking_face_max_height_error":cap_height_error,"rear_hand_torso_distance":rear_hand_gap,"head_fall_distance":fall_distance}
	for step in range(101):
		rig.sample("hammer_attackAAAA",lerpf(slam.impact_at,slam.duration,step/100.0))
		var bottom := INF
		for cap in rig.hammer.cap_world:
			for vertex in cap: bottom=minf(bottom,vertex.y)
		check(bottom>-0.001,"grounded hold and lift-off never push the head through the floor")
	rig.sample("hammer_attackAAAA",slam.impact_at)
	var planted_face: PackedVector3Array = rig.hammer.cap_world[0].duplicate()
	var planted_palms := rig.grip_points.duplicate()
	var head_center_at_contact := head.transform * head.get_rect().get_center()
	var planted_foot := boot.transform
	for frame in range(1,9):
		var elapsed := minf(frame/60.0,0.13)
		rig.sample("hammer_attackAAAA",slam.impact_at+elapsed)
		for i in range(planted_face.size()):
			check(planted_face[i].is_equal_approx(rig.hammer.cap_world[0][i]),"entire striking face stays planted through follow-through")
		check(boot.transform.is_equal_approx(planted_foot),"support boot stays planted")
		for i in range(planted_palms.size()):
			check(rig.grip_points[i].is_equal_approx(planted_palms[i]),"hands stay on stationary hammer")
		if frame==4:
			var displacement := head.transform * head.get_rect().get_center() - head_center_at_contact
			check(displacement.x>4 and displacement.y>3,"upper body settles forward and down within two animation frames")
			slam_report["head_follow_through_xy"]=[displacement.x,displacement.y]
	for stage in range(rig.hammer_data.attacks.size()-1):
		var end: Array = rig.pose_at(stage,rig.hammer_data.attacks[stage].chain_at)
		var start: Array = rig.pose_at(stage+1,0)
		for column in range(1,rig.hammer_data.columns.size()): check(is_equal_approx(float(end[column]),float(start[column])),"chained poses join without a jump")
	for fps in [20,30,60,120]:
		var ctrl := Controller.new(rig.hammer_data)
		check(ctrl.attack(),"first press starts")
		check(not ctrl.attack(),"same-frame duplicate rejected")
		var queued: Dictionary = {}
		var visited: Array = []
		var travel := 0.0
		for frame in range(fps*4):
			if ctrl.index in [0,1,2] and ctrl.time >= 0.20 and not queued.has(ctrl.index):
				queued[ctrl.index] = true
				check(ctrl.attack(),"accept next stage input")
				check(not ctrl.attack(),"duplicate buffer rejected")
				if ctrl.index < 2: ctrl.release_attack()
			if ctrl.state not in visited: visited.append(ctrl.state)
			travel += ctrl.advance(1.0/fps)
		check(visited == ["attackA","attackAA","attackAAA","attackAAAA","idle"],"four stages at every frame rate")
		check(ctrl.state == "idle" and not ctrl.queued,"completion clears queue")
		check(absf(travel-104.2)<0.001,"ground travel independent of frame rate")
	# A hold at contact and one near the end of the buffer both launch.
	# Chunking the same elapsed time must not change the launch or airborne pose.
	for press_at in [.22,.41]:
		var reference := Controller.new(rig.hammer_data)
		reference.start(2)
		reference.advance(press_at)
		check(reference.attack(),"finisher hold accepted")
		var threshold := maxf(press_at+sweep.next_hold_seconds,sweep.chain_speed_from)
		var launch_time: float = threshold+(sweep.chain_at-threshold)/sweep.chain_speed
		reference.advance(launch_time-press_at+.09)
		check(reference.index==3 and absf(reference.time-.09)<.00001,"hold leads directly into launch")
		rig.sample("hammer_attackAAAA",reference.time)
		check(rig.air_height>0,"feet lift during the first tenth of a second of the finisher")
		var ticked := Controller.new(rig.hammer_data)
		ticked.start(2)
		ticked.advance(press_at)
		ticked.attack()
		var interval: float = launch_time-press_at+.09
		for tick in range(37): ticked.advance(interval/37)
		check(ticked.index==reference.index and absf(ticked.time-reference.time)<.00001,"hold transition independent of tick size")
	var ctrl := Controller.new(rig.hammer_data)
	ctrl.attack()
	ctrl.advance(0.75)
	check(not ctrl.attack(),"late recovery input does not pop to next pose")
	ctrl.advance(0.3)
	check(ctrl.state == "idle","single attack returns idle")
	# The new subclass must not change any maintained source clip rendering.
	var original := OriginalCast.new()
	root.add_child(original)
	for clip in original.restored.clips:
		if clip.begins_with("SHW_"): continue
		for fraction in [0.0,0.4,0.85]:
			var at: float = original.restored.clips[clip].duration*fraction
			original.sample(clip,at)
			rig.sample("hammer_attackAAAA",.54)
			rig.sample(clip,at)
			check(not rig.hammer.visible,"source switch hides authored weapon")

			for path in original.sprites:
				var a: Sprite2D = original.sprites[path]
				var b: Sprite2D = rig.sprites[path]
				# Empty PPtr slots are hidden and deliberately keep their previous
				# cached sprite transform; compare geometry only when rendered.
				check(a.visible==b.visible and (not a.visible or (a.transform.is_equal_approx(b.transform) and a.z_index==b.z_index)),"source rendering unchanged: "+clip+" "+path)
	var out := "user://qa/controller.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hammer-output="): out = arg.trim_prefix("--hammer-output=").path_join("controller.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"support_contacts":support_reports,"ground_slam":slam_report},"\t"))
	print("HAMMER_TESTS: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

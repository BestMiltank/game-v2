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
	var second: Dictionary = rig.hammer_data.attacks[1]
	check(rig.hammer_data.attacks.size()==2,"redesigned hammer has two strikes")
	check(not rig.restored.clips.has("hammer_attackAAA"),"retired third hammer clip unavailable")
	for stage in range(rig.hammer_data.attacks.size()):
		for step in range(61):
			var at: float = rig.hammer_data.attacks[stage].duration*step/60.0
			rig.sample("hammer_attack"+"A".repeat(stage+1),at)
			check(rig.air_height>=0,"jump never crosses floor")
			check(absf(rig.sprites["shadow"].position.y)<0.001,"ground shadow does not jump with body")
			check(rig.hammer.head_center.x>45,"hammer head stays outside front of torso")
			var left_foot: Sprite2D = rig.sprites["noumenon/Lfoot"]
			var right_foot: Sprite2D = rig.sprites["noumenon/Rfoot"]
			var clothes: Sprite2D = rig.sprites["noumenon/body/clothes"]
			check(left_foot.z_index<clothes.z_index and right_foot.z_index<clothes.z_index,"clothes remain in front of both boots")
			# Bind-stance ankle span is 38.5 source pixels. Compact steps add at
			# most 12, instead of spreading the shoes toward the body sides.
			check(absf(left_foot.position.x-right_foot.position.x)<=50.5,"foot stride stays compact under the body")
			for hand in rig.grip_points:
				check((rig.roll_transform.affine_inverse()*hand).x>0,"separated grips stay ahead of rolling body")
			check(rig.sprites["noumenon/Lhand"].transform.determinant()<0 and rig.sprites["noumenon/Rhand"].transform.determinant()>0,"rolling retains the distinct spear glove handedness")
	for spec in [[0,.12,.26,"Rfoot"]]:
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
	for spec in [[0,.26],[1,second.impact_at]]:
		rig.sample("hammer_attack"+"A".repeat(spec[0]+1),spec[1])
		var foot: Sprite2D = rig.sprites["noumenon/Rfoot"]
		var toe: Vector2 = foot.transform*Vector2(56,48)
		var heel: Vector2 = foot.transform*Vector2(-56,48)
		# Judge heel lift relative to sole length as the authored shoe narrows.
		check((toe.y-heel.y)/toe.distance_to(heel)>0.25,"forward push visibly lifts the rear heel")
		var leg: Sprite2D = rig.sprites["noumenon/body/R_leg"]
		check(leg.transform.y.normalized().x < -0.35,"rear trouser tilts from hip toward trailing foot")
	rig.sample("hammer_attackAA",second.inverted_at)
	var head: Sprite2D = rig.sprites["noumenon/body/head"]
	var boot: Sprite2D = rig.sprites["noumenon/Lfoot"]
	check(rig.air_height>150 and head.position.y>boot.position.y,"second hit visibly turns head below feet in midair")
	check(head.position.y<0 and boot.position.y<0,"inverted character remains clear of floor")
	check(rig.sprites["shadow"].modulate.a>0.3,"high jump retains grounded visible shadow")
	var total_rotation := 0.0
	var previous_rotation := 0.0
	var previous_speed := 0.0
	var roll_step: float = (second.roll_complete_at-second.roll_start_at)/100.0
	for step in range(101):
		rig.sample("hammer_attackAA",lerpf(second.roll_start_at,second.roll_complete_at,step/100.0))
		if step>0:
			var angle_step := wrapf(rig.hammer.rotation-previous_rotation,-PI,PI)
			var speed := angle_step/roll_step
			check(speed>previous_speed,"rendered somersault continuously accelerates")
			previous_speed = speed
			total_rotation += angle_step
		previous_rotation = rig.hammer.rotation
	check(absf(total_rotation-TAU)<0.001,"held hammer and character complete one forward turn before slam")
	rig.sample("hammer_attackAA",second.foot_plant_at)
	check(is_zero_approx(rig.air_height) and rig.hammer.shaft_direction.y>0.85,"plant with the hammer held high")
	var grounded_boot := boot.transform
	var previous_y := -INF
	var previous_drop := 0.0
	for frame in range(4):
		rig.sample("hammer_attackAA",second.impact_at-(3-frame)/30.0)
		var head_y: float = rig.HammerWeapon.project(rig.hammer.head_center).y
		if frame>0:
			check(head_y-previous_y>previous_drop,"each final frame drops the hammer farther")
			previous_drop=head_y-previous_y
		check(boot.transform.is_equal_approx(grounded_boot),"support foot stays planted for the swing")
		previous_y=head_y
	rig.sample("hammer_attackAA",second.impact_at)
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
		rig.sample("hammer_attackAA",lerpf(second.roll_complete_at,second.impact_at,step/40.0))
		var center: Vector2 = rig.hammer.transform*rig.HammerWeapon.project(rig.hammer.head_center)
		check(center.y>=previous_head_y-0.01,"head continuously descends from completed roll into ground contact")
		if step==0: fall_distance=landed_center.y-center.y
		previous_head_y=center.y
	check(fall_distance>200,"finisher has a substantial downward strike rather than a forward push")
	slam_report={"striking_face_max_height_error":cap_height_error,"rear_hand_torso_distance":rear_hand_gap,"head_fall_distance":fall_distance}
	for step in range(101):
		rig.sample("hammer_attackAA",lerpf(second.impact_at,second.duration,step/100.0))
		var bottom := INF
		for cap in rig.hammer.cap_world:
			for vertex in cap: bottom=minf(bottom,vertex.y)
		check(bottom>-0.001,"grounded hold and lift-off never push the head through the floor")
	rig.sample("hammer_attackAA",second.impact_at)
	var planted_face: PackedVector3Array = rig.hammer.cap_world[0].duplicate()
	var planted_palms := rig.grip_points.duplicate()
	var head_center_at_contact := head.transform * head.get_rect().get_center()
	var planted_foot := boot.transform
	for frame in range(1,9):
		var elapsed := minf(frame/60.0,0.13)
		rig.sample("hammer_attackAA",second.impact_at+elapsed)
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
			if ctrl.index == 0 and ctrl.time >= 0.2 and not queued.has(ctrl.index):
				queued[ctrl.index] = true
				check(ctrl.attack(),"one buffered next hit")
				check(not ctrl.attack(),"duplicate buffer rejected")
			if ctrl.index == 1: check(not ctrl.attack(),"second hit cannot buffer a retired third stage")
			if ctrl.state not in visited: visited.append(ctrl.state)
			travel += ctrl.advance(1.0/fps)
		check(visited == ["attackA","attackAA","idle"],"exactly two stages at every frame rate")
		check(ctrl.state == "idle" and not ctrl.queued,"completion clears queue")
		check(absf(travel-83.2)<0.001,"root distance is frame rate independent")
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
			rig.sample("hammer_attackAA",.54)
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

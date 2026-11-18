extends "res://character/cast_rig.gd"
## User-authorized original hammer poses. Source clips and sampler stay intact.
var hammer_data := Data.read("res://weapons/hammer/action.json")
const HammerWeapon = preload("authored_hammer_weapon.gd")
const Timing = preload("authored_hammer_timing.gd")
var hammer: Node2D
var grip_points: Array[Vector2] = []
var spear_grip_bases: Array[Transform2D] = []
var air_height := 0.0
var somersault_degrees := 0.0
var roll_transform := Transform2D.IDENTITY

func _ready() -> void:
	super._ready()
	_cache_spear_grip_bases()
	hammer = HammerWeapon.new()
	hammer.name = "AuthoredRoundLogMallet"
	var textures: Dictionary = {}
	for key in hammer_data.surfaces:
		textures[key] = load(hammer_data.surfaces[key])
	hammer.setup(textures,hammer_data.shape)
	add_child(hammer)
	hammer.hide()
	var hammer_clips: Array[String] = ["hammer_idle", "hammer_move"]
	for stage in range(hammer_data.attacks.size()):
		hammer_clips.append("hammer_attack" + "A".repeat(stage+1))
	for id in hammer_clips:
		cast_data.allowed_clips.append(id)
		var duration := 1.0
		if id == "hammer_move": duration = restored.clips.THW_move.duration
		elif id.contains("attack"): duration = hammer_data.attacks[id.count("A")-1].duration
		# Host duration lookup only; these never enter the source curve evaluator.
		restored.clips[id] = {"duration":duration, "authored":true}

func _cache_spear_grip_bases() -> void:
	# Read both glove bases from the verified source spear pose. Its front
	# hand is reflected; rebuilding both from an angle loses that handedness.
	var previous_clip := clip_name
	var previous_time := clip_time
	super.sample("spear_idle", 0.0)
	var rear: Sprite2D = sprites["noumenon/Rhand"]
	var front: Sprite2D = sprites["noumenon/Lhand"]
	var rear_center := rear.transform * rear.get_rect().get_center()
	var front_center := front.transform * front.get_rect().get_center()
	var grip_angle := (front_center - rear_center).angle()
	for hand in [rear, front]:
		var basis: Transform2D = hand.transform
		basis.origin = Vector2.ZERO
		spear_grip_bases.append(basis.rotated(-grip_angle))
	super.sample(previous_clip, previous_time)

func sample(id: String, at: float) -> void:
	somersault_degrees = 0.0
	roll_transform = Transform2D.IDENTITY
	if is_instance_valid(hammer): hammer.transform = Transform2D.IDENTITY
	if not id.begins_with("hammer_"):
		air_height = 0.0
		if is_instance_valid(hammer): hammer.hide()
		super.sample(id, at)
		return
	var moving := id == "hammer_move"
	super._evaluate("THW_move" if moving else "THW_idle", at if moving else 0.0)
	clip_name = id
	clip_time = at
	var pose: Array = hammer_data.idle.duplicate()
	if id.contains("attack"):
		pose = pose_at(id.count("A")-1, at)
	elif moving:
		pose[2] += sin(at / float(restored.clips.THW_move.duration) * TAU) * 1.5
	else:
		pose[2] += sin(at * TAU) * 0.5
	air_height = float(pose[12])
	states["noumenon"].local_position[1] += air_height/100.0
	for i in range(2):
		var foot: Dictionary = states["noumenon/"+("Lfoot" if i==0 else "Rfoot")]
		foot.local_position[0] += float(pose[13+i*2])/100.0
		foot.local_position[1] += float(pose[14+i*2])/100.0
		rotate_row(foot,float(pose[17+i]))
	# Authored offsets on the source bind stance, in source-resolution pixels.
	var body: Dictionary = states["noumenon/body"]
	body.local_position[0] += float(pose[5]) / 100.0
	body.local_position[1] -= float(pose[6]) / 100.0
	rotate_row(body, float(pose[4]))
	# Authored rear trouser keys keep the existing piece with the stepping boot.
	# Same parent, pivot, texture and scale; no IK, stretching or extra limb.
	var rear_leg: Dictionary = states["noumenon/body/R_leg"]
	rear_leg.local_position[0] += float(pose[19])/100.0
	rear_leg.local_position[1] -= float(pose[20])/100.0
	rotate_row(rear_leg, float(pose[21]))
	rotate_row(states["noumenon/body/head"], float(pose[7]))
	yaw_row(body,float(pose[11]))
	yaw_row(states["noumenon/body/head"],-float(pose[11])*0.7)
	states["noumenon/body/head/mouth"].sprite = "7128" if float(pose[8]) >= 0.5 else ""
	states["noumenon/body/head/mouth"].renderer_enabled = true
	states["noumenon/body/head/mouth"].active = true
	super._render_state()
	# Keep source depth ordering: clothes cover boot uppers, including during steps.
	var shadow: Sprite2D = sprites["shadow"]
	shadow.scale *= maxf(0.55,1.0-air_height*0.0025)
	shadow.modulate.a *= maxf(0.4,1.0-air_height*0.0035)
	# Hide the bound source equipment and its effects, never alter that data.
	for row in source.equipment[weapon].nodes:
		if sprites.has(row.path): sprites[row.path].hide()
	hammer.pose(Vector3(pose[1],-float(pose[2])+air_height,pose[10]),pose[3],pose[9],hammer_data.height,hammer_data.grip_spacing,hammer_data.rear_grip_offset,pose[23])
	grip_points.assign([HammerWeapon.project(hammer.grip_world[0]),HammerWeapon.project(hammer.grip_world[1])])
	var direction := HammerWeapon.project(hammer.shaft_direction)
	# Original hammer adaptation: transport the spear's two distinct glove
	# bases onto the projected shaft, retaining reflection, scale and palm centers.
	for i in range(2):
		var hand: Sprite2D = sprites["noumenon/" + ("Rhand" if i == 0 else "Lhand")]
		var palm := hand.get_rect().get_center()
		var transform := Transform2D(direction.angle(), grip_points[i]) * spear_grip_bases[i]
		transform.origin -= transform.basis_xform(palm)
		hand.transform = transform
		hand.z_index = 320+i
		hand.show()
	# Authorized whole-body somersault: one rigid screen-space rotation for
	# every existing piece and the held weapon. No new limb or reparenting.
	somersault_degrees = float(pose[22])
	var pivot := Vector2(hammer_data.roll_pivot[0],hammer_data.roll_pivot[1]-air_height)
	roll_transform = Transform2D(deg_to_rad(somersault_degrees),Vector2.ZERO)
	roll_transform.origin = pivot-roll_transform.basis_xform(pivot)
	for path in sprites:
		if path != "shadow": sprites[path].transform = roll_transform * sprites[path].transform
	hammer.transform = roll_transform
	for i in range(grip_points.size()): grip_points[i] = roll_transform * grip_points[i]

func rotate_row(row: Dictionary, screen_degrees: float) -> void:
	var r: Array = row.local_rotation
	var q := Quaternion(Vector3.BACK, -deg_to_rad(screen_degrees)) * Quaternion(r[0],r[1],r[2],r[3])
	row.local_rotation = [q.x,q.y,q.z,q.w]

func yaw_row(row: Dictionary, degrees: float) -> void:
	var r: Array = row.local_rotation
	var q := Quaternion(Vector3.UP,deg_to_rad(degrees))*Quaternion(r[0],r[1],r[2],r[3])
	row.local_rotation = [q.x,q.y,q.z,q.w]

func pose_at(index: int, at: float) -> Array:
	at = Timing.source_time(hammer_data.attacks[index],at)
	var keys: Array = hammer_data.attacks[index].keys
	for i in range(1,keys.size()):
		if at <= float(keys[i][0]):
			var a: Array = keys[i-1]
			var b: Array = keys[i]
			var linear_t := clampf((at-float(a[0]))/(float(b[0])-float(a[0])),0,1)
			var t := linear_t*linear_t*(3.0-2.0*linear_t)
			var result: Array = a.duplicate()
			for j in range(1,8): result[j] = lerpf(float(a[j]),float(b[j]),t)
			for j in range(9,a.size()): result[j] = lerpf(float(a[j]),float(b[j]),t)
			if is_equal_approx(a[0],hammer_data.attacks[index].get("swing_start_source",-1.0)):
				# Planted downstroke: carry shaft speed into contact. The next key
				# holds the entire head on the floor while the torso follows.
				var swing := linear_t*linear_t
				for column in [1,2,3,23]:
					result[column] = lerpf(a[column],b[column],swing)
			# Unwrapped roll angles pass each intermediate key without stopping
			# angular velocity at every quarter-turn or taking the shortest arc.
			result[22] = lerpf(float(a[22]),float(b[22]),linear_t)
			result[8] = b[8] if t >= 0.5 else a[8]
			return result
	return keys.back().duplicate()

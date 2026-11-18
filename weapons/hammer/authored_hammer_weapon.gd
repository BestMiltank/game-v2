extends Node2D
## Generated wood/end-grain/handle artwork on the authored weapon's rigid volume.
const CAMERA_TILT := 0.28
const HEAD_SEGMENTS := 32
# Axial distance from butt tip and radius of the turned wooden pommel.
const POMMEL_PROFILE := [Vector2(1.5,4.6), Vector2(4,9), Vector2(8,11),
	Vector2(12,10), Vector2(17,5.4), Vector2(19,5.4), Vector2(20,6), Vector2(23,6), Vector2(24,4.5)]
const POMMEL_SEGMENTS := 12
var surfaces: Dictionary
var shape: Dictionary
var faces: Array[Polygon2D] = []
var shaft: Polygon2D
var pommel_faces: Array[Polygon2D] = []
var pommel_outline := Line2D.new()
var head_center := Vector3.ZERO
var shaft_direction := Vector3.UP
var grip_world: Array[Vector3] = []
var tail_world := Vector3.ZERO
var jab_streak := 0.0
var cap_world: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
var camera := Vector3(0,CAMERA_TILT,1).normalized()

func setup(art: Dictionary, dimensions: Dictionary) -> void:
	surfaces = art
	shape = dimensions
	shaft = Polygon2D.new()
	shaft.texture = surfaces.handle
	add_child(shaft)
	for i in range(HEAD_SEGMENTS+2):
		var face := Polygon2D.new()
		face.texture = surfaces.head_side if i < HEAD_SEGMENTS else surfaces.head_end
		add_child(face)
		faces.append(face)
	var side_count := (POMMEL_PROFILE.size()-1)*POMMEL_SEGMENTS
	pommel_outline.default_color = Color("#3a2118")
	pommel_outline.width = 2.6
	pommel_outline.closed = true
	pommel_outline.antialiased = true
	add_child(pommel_outline)
	for i in range(side_count+1):
		var face := Polygon2D.new()
		face.texture = surfaces.head_end if i==side_count else surfaces.handle
		add_child(face)
		pommel_faces.append(face)

static func project(point: Vector3) -> Vector2:
	return Vector2(point.x,-point.y+point.z*CAMERA_TILT)

func pose(grip: Vector3, elevation: float, azimuth: float, length: float, spacing: float, rear_offset: float, axial_roll: float, grip_slide: float, streak: float) -> void:
	var pitch := deg_to_rad(elevation)
	var yaw := deg_to_rad(azimuth)
	shaft_direction = Vector3(cos(yaw)*cos(pitch),sin(pitch),sin(yaw)*cos(pitch))
	var flat_crossbar := Vector3(-sin(yaw),0,cos(yaw))
	# Rotation about the handle lets the original mallet present its entire
	# circular end face to the floor. The rigid head never bends off the shaft.
	var crossbar := flat_crossbar*cos(deg_to_rad(axial_roll))+flat_crossbar.cross(shaft_direction)*sin(deg_to_rad(axial_roll))
	grip_world.assign([grip+shaft_direction*rear_offset,grip+shaft_direction*(rear_offset+spacing)])
	# Slide the rigid shaft through the grips on the reverse jab.
	var shaft_origin := grip-shaft_direction*grip_slide
	head_center = shaft_origin+shaft_direction*length*0.70
	tail_world = shaft_origin+shaft_direction*(rear_offset-float(shape.tail_beyond_rear_grip))
	if streak > 0.0 or jab_streak > 0.0: queue_redraw()
	jab_streak = streak
	# The complete generated handle remains visible beyond the rear glove.
	# Its top enters the solid log, so the joint stays covered at every angle.
	var transverse := shaft_direction.cross(camera).normalized()*float(shape.shaft_half_width)
	var handle_size: Vector2 = surfaces.handle.get_size()
	var neck := tail_world+shaft_direction*19.0
	shaft.polygon = PackedVector2Array([project(neck-transverse),project(neck+transverse),
		project(head_center+transverse),project(head_center-transverse)])
	shaft.uv = PackedVector2Array([Vector2(0,handle_size.y*.94),Vector2(handle_size.x,handle_size.y*.94),Vector2(handle_size.x,0),Vector2.ZERO])
	shaft.z_index = 270+roundi((tail_world.z+head_center.z)*0.5)
	cylinder(crossbar,shaft_direction,crossbar.cross(shaft_direction).normalized())
	pose_pommel(crossbar,crossbar.cross(shaft_direction).normalized())
	show()

func pose_pommel(radial_a: Vector3, radial_b: Vector3) -> void:
	var cap: Array[Vector3] = []
	var cap_uv := PackedVector2Array()
	var bulb_points := PackedVector2Array()
	var rear_depth := INF
	var wood_size: Vector2 = surfaces.handle.get_size()
	for side in range(POMMEL_SEGMENTS):
		var angle := TAU*side/POMMEL_SEGMENTS
		var next_angle := TAU*(side+1)/POMMEL_SEGMENTS
		var r := radial_a*cos(angle)+radial_b*sin(angle)
		var s := radial_a*cos(next_angle)+radial_b*sin(next_angle)
		var tip_ring: Vector2 = POMMEL_PROFILE[0]
		cap.append(tail_world+shaft_direction*tip_ring.x+r*tip_ring.y)
		cap_uv.append((Vector2(cos(angle),sin(angle))*.5+Vector2(.5,.5))*surfaces.head_end.get_size())
		for band in range(POMMEL_PROFILE.size()-1):
			var a: Vector2 = POMMEL_PROFILE[band]
			var b: Vector2 = POMMEL_PROFILE[band+1]
			var start := tail_world+shaft_direction*a.x
			var end := tail_world+shaft_direction*b.x
			var vertices: Array[Vector3] = [start+r*a.y,start+s*a.y,end+s*b.y,end+r*b.y]
			if band<=4:
				bulb_points.append(project(vertices[0]))
				rear_depth = minf(rear_depth,vertices[0].z)
			var normal := ((r+s).normalized()*(b.x-a.x)-shaft_direction*(b.y-a.y)).normalized()
			# Sample the existing painted wood; the narrow collar uses the leather wrap.
			var v := .45 if band>=5 else .04
			var u := .18+.58*float(side)/POMMEL_SEGMENTS
			var du := .58/POMMEL_SEGMENTS
			var uv := PackedVector2Array([Vector2(u,v+a.x*.008)*wood_size,Vector2(u+du,v+a.x*.008)*wood_size,
				Vector2(u+du,v+b.x*.008)*wood_size,Vector2(u,v+b.x*.008)*wood_size])
			var face := pommel_faces[band*POMMEL_SEGMENTS+side]
			place_face(face,vertices,uv,normal)
			face.modulate *= 0.66+0.34*maxf(0,normal.dot(Vector3(-.35,.8,.6).normalized()))
			face.modulate.a = 1.0
	place_face(pommel_faces[-1],cap,cap_uv,-shaft_direction)
	var hull := Geometry2D.convex_hull(bulb_points)
	hull.resize(hull.size()-1)
	pommel_outline.points = hull
	pommel_outline.z_index = 269+floori(rear_depth)

func contact_outline(use_pommel: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	if use_pommel:
		return global_transform * pommel_outline.points
	for cap in cap_world:
		for vertex in cap:
			points.append(to_global(project(vertex)))
	var hull := Geometry2D.convex_hull(points)
	hull.resize(hull.size()-1)
	return hull

func _draw() -> void:
	if jab_streak <= 0.0: return
	var tip := project(tail_world)
	var back := project(shaft_direction).normalized()
	var across := back.orthogonal()
	var tint := Color(0.98,0.87,0.61,0.78*jab_streak)
	for side in [-1.0,1.0]:
		var start := tip + back*(5.0 if side<0 else 12.0) + across*float(side)*7.0
		var length := (39.0 if side<0 else 25.0)*jab_streak
		draw_colored_polygon(PackedVector2Array([start,start+back*length+across*float(side)*2.0,
			start+back*3.0+across*float(side)*1.8]),tint)

func cylinder(axis: Vector3, radial_y: Vector3, radial_z: Vector3) -> void:
	var radius := float(shape.head_radius)
	var half_length := float(shape.head_half_length)
	var side_size: Vector2 = surfaces.head_side.get_size()
	# Bind the grain to the weapon's axes, keeping the seam on its rear face.
	# A camera-relative basis would make the grain slide during the swing.
	var back := radial_z
	var tangent := -radial_y
	for i in range(HEAD_SEGMENTS):
		var a := TAU*float(i)/HEAD_SEGMENTS
		var b := TAU*float(i+1)/HEAD_SEGMENTS
		var radial_a := back*cos(a)+tangent*sin(a)
		var radial_b := back*cos(b)+tangent*sin(b)
		var normal := (radial_a+radial_b).normalized()
		var world: Array[Vector3] = [head_center-axis*half_length+radial_a*radius,
			head_center+axis*half_length+radial_a*radius,
			head_center+axis*half_length+radial_b*radius,
			head_center-axis*half_length+radial_b*radius]
		var top := 5.0+(side_size.y-10.0)*float(i)/HEAD_SEGMENTS
		var bottom := 5.0+(side_size.y-10.0)*float(i+1)/HEAD_SEGMENTS
		var uv := PackedVector2Array([Vector2(5,top),Vector2(side_size.x-5,top),
			Vector2(side_size.x-5,bottom),Vector2(5,bottom)])
		place_face(faces[i],world,uv,normal)
	var cap_size: Vector2 = surfaces.head_end.get_size()
	for end in range(2):
		var sign_axis := -1.0 if end==0 else 1.0
		var world: Array[Vector3] = []
		var uv := PackedVector2Array()
		for i in range(HEAD_SEGMENTS):
			var angle := TAU*float(i)/HEAD_SEGMENTS
			world.append(head_center+axis*half_length*sign_axis+(radial_y*cos(angle)+radial_z*sin(angle))*radius)
			uv.append((Vector2(cos(angle),sin(angle))*0.5+Vector2.ONE*0.5)*cap_size)
		cap_world[end] = PackedVector3Array(world)
		place_face(faces[HEAD_SEGMENTS+end],world,uv,axis*sign_axis)

func place_face(face: Polygon2D, world: Array[Vector3], uv: PackedVector2Array, normal: Vector3) -> void:
	face.visible = normal.dot(camera)>0.001
	var vertices := PackedVector2Array()
	var average := Vector3.ZERO
	for point in world:
		vertices.append(project(point))
		average += point/float(world.size())
	face.polygon = vertices
	face.uv = uv
	var light := 0.84+0.16*maxf(0,normal.dot(Vector3(-0.4,0.8,0.6).normalized()))
	face.modulate = Color(light,light,light)
	face.z_index = 270+roundi(average.z)

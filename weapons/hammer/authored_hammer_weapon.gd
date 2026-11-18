extends Node2D
## Generated wood/end-grain/handle artwork on the authored weapon's rigid volume.
const CAMERA_TILT := 0.28
const HEAD_SEGMENTS := 32
var surfaces: Dictionary
var shape: Dictionary
var faces: Array[Polygon2D] = []
var shaft: Polygon2D
var head_center := Vector3.ZERO
var shaft_direction := Vector3.UP
var grip_world: Array[Vector3] = []
var tail_world := Vector3.ZERO
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

static func project(point: Vector3) -> Vector2:
	return Vector2(point.x,-point.y+point.z*CAMERA_TILT)

func pose(grip: Vector3, elevation: float, azimuth: float, length: float, spacing: float, rear_offset: float, axial_roll: float = 72.0) -> void:
	var pitch := deg_to_rad(elevation)
	var yaw := deg_to_rad(azimuth)
	shaft_direction = Vector3(cos(yaw)*cos(pitch),sin(pitch),sin(yaw)*cos(pitch))
	var flat_crossbar := Vector3(-sin(yaw),0,cos(yaw))
	# Rotation about the handle lets the original mallet present its entire
	# circular end face to the floor. The rigid head never bends off the shaft.
	var crossbar := flat_crossbar*cos(deg_to_rad(axial_roll))+flat_crossbar.cross(shaft_direction)*sin(deg_to_rad(axial_roll))
	grip_world.assign([grip+shaft_direction*rear_offset,grip+shaft_direction*(rear_offset+spacing)])
	head_center = grip+shaft_direction*length*0.70
	tail_world = grip+shaft_direction*(rear_offset-float(shape.tail_beyond_rear_grip))
	# The complete generated handle remains visible beyond the rear glove.
	# Its top enters the solid log, so the joint stays covered at every angle.
	var transverse := shaft_direction.cross(camera).normalized()*float(shape.shaft_half_width)
	var handle_size: Vector2 = surfaces.handle.get_size()
	shaft.polygon = PackedVector2Array([project(tail_world-transverse),project(tail_world+transverse),
		project(head_center+transverse),project(head_center-transverse)])
	shaft.uv = PackedVector2Array([Vector2(0,handle_size.y),handle_size,Vector2(handle_size.x,0),Vector2.ZERO])
	shaft.z_index = 270+roundi((tail_world.z+head_center.z)*0.5)
	cylinder(crossbar,shaft_direction,crossbar.cross(shaft_direction).normalized())
	show()

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

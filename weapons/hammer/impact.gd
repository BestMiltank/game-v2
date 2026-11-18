extends Node2D
## Trial clock drives the painted dust and sets the start of the wooden thud.
const DUST = preload("res://weapons/hammer/art/dust.png")
const FRAME_ENDS := [.025,.07,.15,.26,.40,.56,.76,1.0]
const CELL := 512.0
const THUD = preload("res://weapons/hammer/audio/wood-earth-thud.wav")
const DURATION := 0.32
var age := -1.0
var sound := AudioStreamPlayer.new()

func _ready() -> void:
	sound.stream = THUD
	sound.volume_db = -6.0
	add_child(sound)

func strike(point: Vector2, elapsed: float) -> void:
	global_position = point
	age = elapsed
	if age < THUD.get_length():
		sound.play(age)
	queue_redraw()

func advance(delta: float) -> void:
	if age < 0: return
	age += delta
	if age >= DURATION: age = -1.0
	queue_redraw()

func _draw() -> void:
	if age < 0 or age >= DURATION: return
	draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,0.45))
	draw_air(self,Vector2.ZERO,age/DURATION,54.0)

static func dust_frame(time: float) -> int:
	if time < 0: return -1
	for i in FRAME_ENDS.size():
		if time < float(FRAME_ENDS[i]): return i
	return -1

static func region(index: int, columns: int) -> Rect2:
	return Rect2(Vector2(index%columns,index/columns)*CELL,Vector2.ONE*CELL)

static func draw_air(canvas: Node2D, point: Vector2, time: float, size: float) -> void:
	var frame := dust_frame(time)
	if frame < 0: return
	var width := size*2.65
	# Fixed cells preserve the drawn expansion and ground anchor; never fit
	# individual frames to their changing occupied bounds.
	var fade := 1-smoothstep(.55,1.0,time)
	var rect := Rect2(point+Vector2(-width*.5,-width*.71+size*.10),Vector2.ONE*width)
	canvas.draw_texture_rect_region(DUST,rect,region(frame,4),Color(.93,.87,.76,fade*.92))

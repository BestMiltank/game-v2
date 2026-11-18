extends Node2D

const FRAMES := preload("animations.tres")
const MAX_HP := 300
const RADIUS := 16.0
const HEIGHT := 56.0
const DAMAGE := [54,40,76,130]
const PUSH := [5.0,7.0,34.0,42.0]
const PUSH_TIME := 0.15

var hp := MAX_HP
var animation: StringName = &"idle"
var elapsed := 0.0
var last_strike := -1
var knock_time := PUSH_TIME
var knock_distance := 0.0
var sprite := Sprite2D.new()
var jab_tilt := 0.0

func _ready() -> void:
	sprite.centered = false
	sprite.offset = Vector2(-128,-233)
	add_child(sprite)
	reset_at(position)

func reset_at(at: Vector2) -> void:
	position = at
	hp = MAX_HP
	elapsed = 0
	animation = &"idle"
	last_strike = -1
	knock_time = PUSH_TIME
	jab_tilt = 0
	sprite.scale = Vector2(-1,1)*HEIGHT/104.0
	update_art()

func try_hit(id: int, stage: int, shape: PackedVector2Array, attacker: Vector2, facing: float) -> bool:
	if hp==0 or last_strike==id or (position.x-attacker.x)*facing < 0 or absf(position.y-attacker.y)>RADIUS:
		return false
	var local_shape := global_transform.affine_inverse()*shape
	var body := PackedVector2Array([Vector2(-RADIUS,-HEIGHT),Vector2(RADIUS,-HEIGHT),Vector2(RADIUS,0),Vector2(-RADIUS,0)])
	if Geometry2D.intersect_polygons(local_shape,body).is_empty(): return false
	last_strike = id
	jab_tilt = facing*deg_to_rad(15.0) if stage==1 else 0.0
	hp = maxi(0,hp-DAMAGE[stage])
	if hp==0 or animation!=&"hurt":
		animation = &"death" if hp==0 else &"hurt"
		elapsed = 0
	sprite.scale.x = -facing*HEIGHT/104.0
	knock_time = 0
	knock_distance = facing*PUSH[stage]
	update_art()
	return true

func advance(delta: float, player: Vector2, bounds: Rect2) -> void:
	var previous := 1.0-knock_time/PUSH_TIME
	knock_time = minf(PUSH_TIME,knock_time+delta)
	var remaining := 1.0-knock_time/PUSH_TIME
	position.x = clampf(position.x+knock_distance*(previous*previous-remaining*remaining),bounds.position.x,bounds.end.x)
	elapsed += delta
	if animation==&"idle" and absf(player.x-position.x)>1:
		sprite.scale.x = signf(player.x-position.x)*HEIGHT/104.0
	update_art()

func update_art() -> void:
	sprite.rotation = jab_tilt*pow(1.0-knock_time/PUSH_TIME,2)
	var t := elapsed
	var count := FRAMES.get_frame_count(animation)
	for frame in range(count):
		var duration := FRAMES.get_frame_duration(animation,frame)/FRAMES.get_animation_speed(animation)
		if t<duration or frame==count-1:
			sprite.texture = FRAMES.get_frame_texture(animation,frame)
			if frame==count-1 and t>=duration and animation!=&"death":
				elapsed = t-duration
				animation = &"idle"
				sprite.texture = FRAMES.get_frame_texture(animation,0)
			break
		t -= duration
	sprite.modulate = Color(1.35,1.18,1.04) if knock_time<.055 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.30))
	draw_circle(Vector2.ZERO,17,Color(0.15,0.12,0.08,.50))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if hp>0:
		draw_rect(Rect2(-21,-HEIGHT-11,42,5),Color("#332c27"))
		draw_rect(Rect2(-20,-HEIGHT-10,40.0*hp/MAX_HP,3),Color("#bf6a4d"))

extends Node2D

const BOUNDS := Rect2(-344,-45,688,196)
const NAMES := ["长弓","大剑","长枪","圆木重锤"]
@onready var actor = $Ground/Character
var held := {}
var status: Label

func _ready() -> void:
	actor.displacement_requested.connect(_move_actor)
	label("动作试炼场",Vector2(55,24),34,Color("#f3dfb1"))
	status=label("",Vector2(760,33),22,Color("#e1c798"))
	label("WASD  移动      J  攻击 / 续段      Q  E  换武器      1–6  换形象      Esc  暂停",Vector2(55,657),20,Color("#e9debd"))
	refresh()

func label(value: String, at: Vector2, size: int, tint: Color) -> Label:
	var item := Label.new()
	item.text=value
	item.position=at
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",tint)
	$HUD.add_child(item)
	return item

func _draw() -> void:
	var floor_rect := Rect2(40,96,1200,535)
	draw_rect(floor_rect,Color("#665742"))
	draw_rect(floor_rect.grow(-5),Color("#75644b"))
	var rng := RandomNumberGenerator.new()
	rng.seed=8037
	for i in range(950):
		var spot:=Vector2(rng.randf_range(48,1232),rng.randf_range(104,623))
		draw_line(spot,spot+Vector2(rng.randf_range(1,5),1),Color(0.25,0.19,0.13,0.23))
	var border:=Rect2(Vector2(640,390)+BOUNDS.position*1.5,BOUNDS.size*1.5)
	draw_rect(border,Color("#8d7959"),false,1)
	for corner in [border.position,border.end,Vector2(border.position.x,border.end.y),Vector2(border.end.x,border.position.y)]:
		draw_circle(corner,3,Color("#baa17a"))

func _move_actor(delta: Vector2) -> void:
	actor.position=(actor.position+delta).clamp(BOUNDS.position,BOUNDS.end)

func direction() -> Vector2:
	return Vector2(int(held.has(KEY_D))-int(held.has(KEY_A)),int(held.has(KEY_S))-int(held.has(KEY_W))).normalized()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	var key: int=event.keycode
	if key in [KEY_W,KEY_A,KEY_S,KEY_D]:
		if event.pressed: held[key]=true
		else: held.erase(key)
	elif event.pressed:
		match key:
			KEY_ESCAPE: actor.set_paused(not actor.paused)
			KEY_J: actor.attack(direction())
			KEY_Q: actor.select_weapon(actor.weapon_index-1)
			KEY_E: actor.select_weapon(actor.weapon_index+1)
			KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6: actor.select_cast(key-KEY_1)
	refresh()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: held.clear()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	actor.advance(delta,direction())
	refresh()

func refresh() -> void:
	if not is_instance_valid(status): return
	var action: String = "暂停" if actor.paused else ("第 %d 击" % actor.attacks.state.count("A") if actor.busy() and actor.attacks.state!="idle" else ("移动" if actor.moving else "就绪"))
	status.text="%s    /    %s    ·    %s" % [actor.rig.cast_data.presets[actor.rig.cast_index].name,NAMES[actor.weapon_index],action]

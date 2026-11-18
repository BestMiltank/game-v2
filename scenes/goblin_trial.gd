extends "arena.gd"

const SPAWN := Vector2(100,0)
@onready var raider = $Ground/Raider
var contact_pause := 0.0

func _ready() -> void:
	super._ready()
	actor.hammer_contact.connect(_on_contact)
	reset_trial()

func reset_trial() -> void:
	contact_pause = 0
	if actor.weapon_index==3: actor.attacks.reset()
	actor.position = Vector2.ZERO
	actor.facing = 1
	actor.moving = false
	actor.select_weapon(3)
	actor.advance(0,Vector2.ZERO)
	actor.impact.sound.stop()
	actor.impact.age = -1
	actor.impact.queue_redraw()
	raider.reset_at(SPAWN)
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode in [KEY_Q,KEY_E]: return
		if event.keycode==KEY_R:
			if event.pressed and not event.echo and not actor.paused: reset_trial()
			return
	super._input(event)

func _on_contact(id: int, stage: int, shape: PackedVector2Array) -> void:
	if raider.try_hit(id,stage,shape,actor.position,actor.facing) and stage==1:
		contact_pause = 1.0/30

func advance(delta: float) -> void:
	if actor.paused: return
	var left := delta
	while left>0.000001:
		if contact_pause>0:
			var held_time := minf(left,contact_pause)
			contact_pause -= held_time
			left -= held_time
			continue
		var step := minf(left,1.0/60)
		raider.advance(step,actor.position,BOUNDS)
		actor.advance(step,direction())
		left -= step
	raider.z_index = 390 if raider.position.y>actor.position.y else 1
	if raider.hp==0 and raider.elapsed>=1.5 and not actor.busy(): reset_trial()
	refresh()

func refresh() -> void:
	super.refresh()
	if is_instance_valid(controls):
		controls.text = "WASD  移动      J  三连击 · 第三击中再长按 J  接重砸      R  复位      1–6  换形象      Esc  暂停"

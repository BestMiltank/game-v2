extends Node2D
## Host resolves displacement synchronously, before a contact cue is positioned.
signal displacement_requested(delta: Vector2)
signal slam_contact(at: Vector2)

const SourceController = preload("res://weapons/standing_combo_controller.gd")
const HammerController = preload("res://weapons/hammer/authored_hammer_controller.gd")
const PREFIXES := ["bow","THW","spear","hammer"]
const DISPLAY_SCALE := 0.65
const MOVE_RATE := 1.3
const BASE_SPEED := 200.0
@onready var rig = $Rig
@onready var impact = $Impact
var attacks: RefCounted
var weapon_index := 2
var facing := 1.0
var clip := "spear_idle"
var time := 0.0
var moving := false
var paused := false

func _ready() -> void:
	rig.scale = Vector2.ONE * DISPLAY_SCALE
	select_weapon(2)

func busy() -> bool:
	return attacks != null and (attacks.state != "idle" or not attacks.next.is_empty() or not attacks.pending_play.is_empty())

func select_cast(index: int) -> void:
	rig.cast_index = clampi(index,0,rig.cast_data.presets.size()-1)
	if busy(): attacks.render(rig)
	else: rig.sample(clip,time)

func select_weapon(index: int) -> void:
	if busy(): return
	weapon_index = posmod(index,PREFIXES.size())
	var prefix: String = PREFIXES[weapon_index]
	attacks = HammerController.new(rig.hammer_data) if prefix=="hammer" else SourceController.new(rig.restored.clips,prefix)
	clip = prefix + ("_move" if moving else "_idle")
	time = 0.0
	rig.sample(clip,time)

func attack(direction: Vector2) -> bool:
	if paused: return false
	if not busy():
		if moving or not direction.is_zero_approx(): return false
		if weapon_index!=3:
			attacks.time = SourceController.f32(time / float(rig.restored.clips[clip].duration))
	return attacks.attack()

func set_paused(value: bool) -> void:
	paused = value
	impact.sound.stream_paused = value

func advance(delta: float,direction: Vector2) -> void:
	if paused: return
	impact.advance(delta)
	if busy():
		if weapon_index==3:
			var travel: float = attacks.advance(delta)
			displacement_requested.emit(Vector2(facing*travel*DISPLAY_SCALE,0))
			if attacks.impact_age>=0:
				rig.sample("hammer_attackAA",rig.hammer_data.attacks[1].impact_at)
				var center := Vector3.ZERO
				var cap: PackedVector3Array = rig.hammer.cap_world[0]
				for vertex in cap: center += vertex
				var at: Vector2 = rig.hammer.to_global(rig.HammerWeapon.project(center/cap.size()))
				impact.global_scale = global_scale
				impact.strike(at,attacks.impact_age)
				slam_contact.emit(at)
		else: attacks.advance(delta)
		attacks.render(rig)
		clip = rig.clip_name
		time = rig.clip_time
		moving = false
		return
	var before := position
	displacement_requested.emit(direction.limit_length()*BASE_SPEED*MOVE_RATE*delta)
	var moved := position-before
	moving = moved.length_squared()>0.000001
	if absf(moved.x)>0.001: facing=signf(moved.x)
	var next_clip: String = PREFIXES[weapon_index]+("_move" if moving else "_idle")
	if next_clip!=clip:
		clip=next_clip
		time=0.0
	rig.scale.x=DISPLAY_SCALE*facing
	time=fmod(time+delta*(MOVE_RATE if moving else 1.0),rig.restored.clips[clip].duration)
	rig.sample(clip,time)

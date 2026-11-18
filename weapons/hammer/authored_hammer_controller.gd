extends RefCounted
## Original configured chain; timings are authored, not Lost Castle parameters.
const Timing = preload("authored_hammer_timing.gd")
var data: Dictionary
var state := "idle"
var next := ""
var pending_play := ""
var time := 0.0 # Seconds, unlike the separate native controller.
var queued := false
var index := -1
var impact_age := -1.0

func _init(config: Dictionary) -> void:
	data = config

func attack() -> bool:
	if state == "idle":
		start(0)
		return true
	if index >= data.attacks.size()-1 or queued or time < float(data.attacks[index].input_from) or time > float(data.attacks[index].chain_at): return false
	# One buffered press per stage; recovery is committed after the chain window.
	queued = true
	return true

func start(stage: int) -> void:
	index = stage
	state = "attack" + "A".repeat(stage+1)
	time = 0.0
	queued = false

func advance(delta: float) -> float:
	# Return only this tick's authored ground travel. Carry remaining time
	# across a chain boundary, without replaying or reversing the last step.
	var travel := 0.0
	var remaining := maxf(0,delta)
	impact_age = -1.0
	while index >= 0 and remaining > 0:
		var config: Dictionary = data.attacks[index]
		var end: float = config.chain_at if queued else config.duration
		var step := minf(remaining,maxf(0,end-time))
		if config.has("foot_plant_at") and time < config.impact_at and time+step >= config.impact_at:
			impact_age = remaining-(float(config.impact_at)-time)
		travel += motion_at(index,time+step)-motion_at(index,time)
		time += step
		remaining -= step
		if time >= end-0.000001:
			if queued: start(index+1)
			else: reset()
		else: break
	return travel

func motion_at(stage: int, at: float) -> float:
	at = Timing.source_time(data.attacks[stage],at)
	var keys: Array = data.attacks[stage].motion
	for i in range(1,keys.size()):
		if at <= float(keys[i][0]):
			var t := clampf((at-float(keys[i-1][0]))/(float(keys[i][0])-float(keys[i-1][0])),0,1)
			return lerpf(keys[i-1][1],keys[i][1],t*t*(3.0-2.0*t))
	return keys.back()[1]

func reset() -> void:
	state = "idle"
	index = -1
	time = 0.0
	queued = false

func render(rig: Node2D) -> void:
	rig.sample("hammer_"+state, time)

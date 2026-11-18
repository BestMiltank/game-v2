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
var hold_started_at := -1.0
var strike_id := 0
var contacts: Array[Dictionary] = []

func _init(config: Dictionary) -> void:
	data = config

func attack() -> bool:
	if state == "idle":
		start(0)
		return true
	var stage: Dictionary = data.attacks[index]
	if index >= data.attacks.size()-1 or queued or time < float(stage.input_from) or time > float(stage.chain_at): return false
	if stage.has("next_hold_seconds"):
		if hold_started_at >= 0.0 or time + float(stage.next_hold_seconds) > float(stage.chain_at) + 0.000001:
			return false
		hold_started_at = time
		return true
	# One buffered press per stage; recovery is committed after the chain window.
	queued = true
	return true

func release_attack() -> void:
	hold_started_at = -1.0

func start(stage: int) -> void:
	strike_id += 1
	index = stage
	state = "attack" + "A".repeat(stage+1)
	time = 0.0
	queued = false
	release_attack()

func advance(delta: float, sample_contacts: bool = false) -> float:
	# Return only this tick's authored ground travel. Carry remaining time
	# across a chain boundary, without replaying or reversing the last step.
	var travel := 0.0
	var remaining := maxf(0,delta)
	impact_age = -1.0
	contacts.clear()
	while index >= 0 and remaining > 0:
		var config: Dictionary = data.attacks[index]
		var end: float = config.chain_at if queued else config.duration
		var rate := 1.0
		if hold_started_at >= 0.0:
			# Measure the hold in real seconds, even when a long tick crosses it.
			end = hold_started_at + float(config.next_hold_seconds)
		elif queued and config.has("chain_speed_from"):
			if time < float(config.chain_speed_from):
				end = config.chain_speed_from
			else:
				rate = config.chain_speed
		var step := minf(remaining*rate,maxf(0,end-time))
		if sample_contacts:
			for tick in range(int(config.contact_lead_ticks_120hz),-1,-1):
				var at := float(config.impact_at)-tick/120.0
				if time < at and at <= time+step:
					contacts.append({"id":strike_id,"stage":index,"time":at,
						"travel":travel+motion_at(index,at)-motion_at(index,time)})
		if config.has("foot_plant_at") and time < config.impact_at and time+step >= config.impact_at:
			impact_age = remaining-(float(config.impact_at)-time)
		travel += motion_at(index,time+step)-motion_at(index,time)
		time += step
		remaining -= step/rate
		if time >= end-0.000001:
			time = end
			if hold_started_at >= 0.0:
				queued = true
				release_attack()
			elif not queued: reset()
			elif time >= float(config.chain_at)-0.000001: start(index+1)
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
	release_attack()

func render(rig: Node2D) -> void:
	rig.sample("hammer_"+state, time)

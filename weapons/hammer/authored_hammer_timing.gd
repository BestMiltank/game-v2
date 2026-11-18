extends RefCounted
## Shared original-weapon clock: the same ramp drives pose and ground travel.

static func source_time(attack: Dictionary, elapsed: float) -> float:
	if not attack.has("speed_ramp"): return elapsed
	var ramp: Dictionary = attack.speed_ramp
	var duration := 2.0*float(ramp.source_end)/(float(ramp.start_speed)+float(ramp.end_speed))
	if elapsed >= duration:
		# Restore normal time at contact, retaining authored impact hold/recovery.
		return float(ramp.source_end)+elapsed-duration
	var acceleration := (float(ramp.end_speed)-float(ramp.start_speed))/duration
	return float(ramp.start_speed)*elapsed+0.5*acceleration*elapsed*elapsed

static func playback_time(attack: Dictionary, source_at: float) -> float:
	if not attack.has("speed_ramp"): return source_at
	var ramp: Dictionary = attack.speed_ramp
	var duration := 2.0*float(ramp.source_end)/(float(ramp.start_speed)+float(ramp.end_speed))
	if source_at >= float(ramp.source_end):
		return duration+source_at-float(ramp.source_end)
	var acceleration := (float(ramp.end_speed)-float(ramp.start_speed))/duration
	var start := float(ramp.start_speed)
	return 2.0*source_at/(start+sqrt(start*start+2.0*acceleration*source_at))

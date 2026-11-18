extends RefCounted
## Standing subset of HeroAnim.attackA + shared HeroBase controller. No combat events.
var source: Dictionary
var clips: Dictionary
var state := "idle"
var next := ""
var time := 0.0 # normalized, matching AnimatorStateInfo
var next_time := 0.0
var blend := 0.0
var blend_duration := 0.0
var parameters: Dictionary = {}
var pending_play := ""

func _init(clip_data: Dictionary, prefix: String = "THW") -> void:
	clips = clip_data
	const Data = preload("res://character/character_data.gd")
	source = Data.read(Data.weapon_path(prefix,"controller.json"))
	# isExistClip in HeroAnim checks actual override availability, not a fixed
	# four-hit count. All four weapons use the same serialized HeroBase controller.
	for row in source.states.values(): assert(clips.has(row.clip))

static func f32(value: float) -> float:
	return PackedFloat32Array([value])[0]

func duration(id: String) -> float:
	return clips[source.states[id].clip].duration

func reset() -> void:
	state = "idle"
	next = ""
	time = 0.0
	next_time = 0.0
	blend = 0.0
	parameters.clear()
	pending_play = ""

func attack() -> bool:
	# HeroAnim.attackA: inputs during forward blends are rejected. A return
	# blend may be interrupted by a direct Play of the next normal attack.
	var chain := {"attackA":"attackAA", "attackAA":"attackAAA", "attackAAA":"attackAAAA"}
	for id in chain.keys():
		if not source.states.has(chain[id]): chain.erase(id)
	if not next.is_empty():
		if next == "idle" and chain.has(state):
			pending_play = chain[state]
			return true
		return false
	parameters.to_sp = false
	if state == "idle":
		_begin("attackA", f32(0.1 * duration(state)), 0.0)
		parameters.a_aa = false
		parameters.attack_2_skill = false
		parameters.a_ab = false
		return true
	if not chain.has(state): return false
	if time < f32(0.7):
		var flags := {"attackA":"a_aa", "attackAA":"aa_aaa", "attackAAA":"aaa_aaaa"}
		parameters[flags[state]] = true
		if flags.has(chain[state]): parameters[flags[chain[state]]] = false
		parameters.attack_2_skill = false
		parameters[{"attackA":"aa_aab", "attackAA":"aaa_aaab", "attackAAA":"aaaa_aaaab"}[state]] = false
	else:
		pending_play = chain[state]
	return true

func _begin(destination: String, seconds: float, elapsed: float) -> void:
	next = destination
	next_time = f32(elapsed / duration(next))
	blend_duration = seconds
	blend = f32(elapsed / seconds)

func advance(delta: float) -> void:
	delta = f32(delta)
	if not pending_play.is_empty():
		state = pending_play
		time = 0.0
		next = ""
		pending_play = ""
		blend = 0.0
		next_time = 0.0
		# Native Animator.Play evaluates its first pose at zero on this update.
		return
	var previous := time
	time = f32(time + f32(delta / duration(state)))
	if not next.is_empty():
		next_time = f32(next_time + f32(delta / duration(next)))
		blend = f32(blend + f32(delta / blend_duration))
	else:
		for transition in source.states[state].transitions:
			if previous >= transition.exit or time < transition.exit: continue
			var matches := true
			for condition in transition.conditions:
				if parameters.get(condition.parameter, false) != condition.value: matches = false
			if matches:
				_begin(transition.destination, f32(transition.duration * duration(state)), f32((time - transition.exit) * duration(state)))
				break
	if not next.is_empty() and blend >= 1.0:
		state = next
		time = next_time
		next = ""
		next_time = 0.0
		blend = 0.0

func render(rig: Node2D) -> void:
	var seconds := f32(fmod(time, 1.0) * duration(state) if state == "idle" else time * duration(state))
	if next.is_empty():
		rig.sample(source.states[state].clip, seconds)
	else:
		var next_seconds := f32(fmod(next_time, 1.0) * duration(next) if next == "idle" else next_time * duration(next))
		rig.sample_blend(source.states[state].clip, seconds, source.states[next].clip, next_seconds, blend)

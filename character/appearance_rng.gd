extends RefCounted
## Unity 2021.3.25f1 integer RNG semantics, recovered from native state probes.
## Verified initial state + 8 outputs + final state for every DNA 0..999.
## Only the nonnegative integer ranges used by HumanAppearance are supported.

const MASK := 0xffffffff
var state: Array[int] = []

func init_state(seed_value: int) -> void:
	state = [seed_value & MASK]
	for i in range(3):
		state.append((1812433253 * state[-1] + 1) & MASK)

func range_int(minimum: int, maximum_exclusive: int) -> int:
	assert(minimum >= 0 and maximum_exclusive > minimum)
	var t := state[0] ^ ((state[0] << 11) & MASK)
	var w := (state[3] ^ (state[3] >> 19) ^ t ^ (t >> 8)) & MASK
	state = [state[1], state[2], state[3], w]
	return minimum + w % (maximum_exclusive - minimum)

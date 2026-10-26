extends RefCounted


# Keep the global utility samplers' precision, endpoints and PCG draw counts
# while sourcing every word from the explicitly owned gameplay RNG.
# Compatibility reference: Godot core/math/math_funcs.h (Math::randf) and
# core/math/random_pcg.h (RandomPCG::randd), on the supported GCC/MSVC builds.
static func sample_unit(rng: RandomNumberGenerator) -> float:
	# Math::randf divides two float32 values; uint32 max rounds to 2^32.
	var word: float = PackedFloat32Array([float(rng.randi())])[0]
	return word / 4294967296.0


static func sample_range(rng: RandomNumberGenerator, from: float, to: float) -> float:
	# Global randf_range uses the double sampler, not RNG.randf_range's
	# real_t sampler. Preserve its three-word consumption and arithmetic.
	var exponent_word: int = rng.randi()
	if exponent_word == 0:
		return from
	var high_word: int = rng.randi() | 0x80000000
	var low_word: int = rng.randi() | 1
	var significand: float = float(high_word) * 4294967296.0 + float(low_word)
	var leading_zeros: int = 0
	var mask: int = 1 << 31
	while (exponent_word & mask) == 0:
		leading_zeros += 1
		mask >>= 1
	var unit: float = significand * pow(2.0, -64 - leading_zeros)
	return unit * (to - from) + from

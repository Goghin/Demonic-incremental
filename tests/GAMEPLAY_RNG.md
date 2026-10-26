# Deterministic gameplay RNG isolation

Based on branch `feature/cycle-auto-run`, HEAD `991fd0209a582e47e23b258c996b1471309cf39e`.

## Ownership and draw ordering

`GameState.gameplay_rng` owns one `RandomNumberGenerator`. Simulation uses it for cycle critical and downlevel events. GameState injects the same object into RelicManager, which passes it explicitly through relic generation, weighted selection, stat ranges, target selection and names. Loading mutates the existing RNG object rather than replacing the reference. Standalone RelicManager instances allocate their own private stream.

All seven former gameplay global RNG call sites are routed to this stream. Cosmetic, animation, audio and editor randomness remains untouched. No changes to timestep, automation, formulas, tier configuration, weights, ranges or cycle rules.

Godot global `randf()` and `randf_range()` are not interchangeable with the similarly named RandomNumberGenerator methods: their precision and word consumption differ. `Game/gameplay_random.gd` reproduces the existing global unit and double-range samplers using words from the owned RNG. Integer ranges use the native bounded RNG method. The existing conditional draw behavior at chances zero and one, and the ordering of all selections, are preserved.

Compatibility references: Godot 4.6 `core/math/math_funcs.h` (`Math::randf`), `core/math/random_pcg.h` (`RandomPCG::randd`) and `core/variant/variant_utility.cpp` (global range helpers). The helper targets the existing GCC/MSVC sampler algorithm; engine/platform changes should rerun sampler parity tests.

## Save format and migration

Save version is now 9. `gameplay_rng.seed` and `gameplay_rng.state` are canonical signed 64-bit decimal strings, avoiding JSON integer rounding. Load validates bounds and restores seed before state, before any existing starter-relic backfill. Missing/malformed RNG fields in version 9 are rejected instead of silently reseeding. Version 8 and older saves without the fields keep the RNG initialized once when GameState is constructed; subsequent version-9 saves persist it. Their historical random sequence was never recorded and cannot be recovered.

Active generators persist `cycle_critical_chance_snapshot` as `f64:` plus eight bytes of hexadecimal double data. This avoids JSON decimal-parser roundoff in the activation probability. Load accepts this encoding and finite numeric legacy values, allowing the existing -1 sentinel or a chance in [0, 1]. Inactive snapshots reset to -1. Older active crafts without a snapshot retain the existing -1 fallback; their unknown activation chance cannot be reconstructed.

Generated relic load also retains the already-saved `requested_tier` metadata. Existing inventory is not rerolled. Existing starter backfill remains a real reward action consuming the restored gameplay stream; its draw count is tested against performing the same reward action directly.

## Validation

Godot 4.6.1 stable Linux, isolated imported project:

- Entire regression runner: **52 passed, 0 failed**, no parser warnings or runtime errors (45 existing cases plus seven focused RNG cases).
- Same seed and 32 mixed forge/crafting completion actions: exact critical flags, generator levels, resources, inventory, statistics and final RNG state. Same results with varying global random calls, global reseeding and array shuffles, and with normal versus offline cycle processing.
- Actual JSON save/load at signed-int64 seed extremes: exact seed/state and next 128 random words. Overflow and missing modern RNG data rejected.
- Save after 16 mixed actions, reload, then 24 further actions: exact subsequent critical flags, new relics and RNG state. Existing JSON float fields use a 1e-12 relative tolerance for pre-existing serialization roundoff; the serialization of ordinary resources and existing rolled values was deliberately left unchanged.
- Active craft activated at level 2 then raised to level 20: exact activation snapshot survives JSON load, with identical completion relic and RNG state.
- Version-8 missing-field migration, resave/reload and restored-stream starter backfill pass.
- Durable sampler test compares 500 interleaved unit/double-range/integer samples exactly against Godot global utility results, including singleton integer ranges. Zero/one event probabilities retain their no-draw behavior.
- 200 generated relics replay exactly across all three requested tiers and stay inside configured primary stat ranges.
- Independent temporary reference harness compares the original relic generator from `991fd02` against this implementation: **500 relics byte-for-byte identical**, across all tiers and critical chances 0%, 5%, 50% and 100%, seeded 123456. This reference harness does not ship a duplicate production implementation.

The corrected offline benchmark also completed its one-hour 0.1-second baseline, profiling run and existing larger-step comparisons without warnings/errors (baseline wall time 11.60 seconds on this shared host; no performance claim for RNG isolation). Two 600-second critical-cycle replays at 0.1 seconds (6,000 updates each) produced identical binary snapshot hash `155bf06aac9acc71bc0f52901e820f22c575dce2f211756c36f899b4ec4e9600`, including events, resources, inventory, statistics and RNG tail. Measured compute times were 1.295408 and 1.276577 seconds. Larger timesteps were only exercised by the existing benchmark, not introduced into gameplay.

All benchmark entry points now seed the owned gameplay RNG explicitly. The performance benchmark fingerprints the gameplay stream instead of the unrelated global stream and labels its RNG kind. Historical benchmark artifacts predate this isolation and are unchanged.

## Limits

Determinism requires the same seed, gameplay action order and engine RNG algorithm. Engine-version/platform-independent replay is not promised. Save version 9 is forward-only for old builds. This batch does not repair existing save/resume cooldown or scheduling differences, ordinary JSON float roundoff, or other simulation timing differences; full uninterrupted-vs-resumed trajectory equivalence is only asserted for the controlled tested actions. No full application/editor import success is claimed: this checkout has pre-existing font import and `game.gd:771` indentation errors outside the standalone regression/benchmark dependency graph.

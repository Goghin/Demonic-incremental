# Event-aware autobuyer simulation

Base: `3d5c5f707fd45363de60c76337a55403f202344e`, branch `feature/cycle-auto-run`.

**A restricted waiting-automation prototype is validated. It is not a production solution for a realistic 24-hour catch-up.** The final four-hour waiting fixture achieved a median paired **3.18×** speedup (2.93–3.99×), with unchanged discrete outcomes and small sampled numerical errors. A realistic mixed fixture still uses exact simulation throughout. No six-minute or 5× mixed-gameplay claim is supported.

Production Simulation, TimeManager, GameState, generator/upgrade definitions, purchasing rules, resource formulas, save format and gameplay RNG are unchanged. All changes are under `tests/`. No player setting is added or enabled.

## 1. Existing automation behavior

Inspection findings were recorded here before implementation. The authoritative tick order is:

1. Automatic upgrades in registry order.
2. Generators in state dictionary order, including inputs, outputs and cycles.
3. Matter decay (which also produces Heat), then Heat leak.
4. Generator automation.
5. Upgrade automation.

Generator automation order is Atomic Friction, Molecular Agitation, Infernal Condensation, Arcane Compressor, Lava Mite Colony, Matter Furnace. Upgrade tree order is Atomic Friction, Molecular Agitation, Infernal Condensation, Lava Mite Colony, Matter Furnace, Arcane Compressor, then general. Offline enabled-ID indices preserve these orders.

Generator cooldown is `max(0.5, 5 * 0.8^permanent_cooldown_upgrade_level)` seconds. Cooldowns carry overshoot; several purchases can occur within one update if its delta is large. A failed purchase enters resource waiting with cooldown zero and a cached cost. Waiting entries check resources once per simulation update; success starts a fresh cooldown without carrying an old waiting interval into it. The cost cache refreshes for level, mode, modifier-count and realm-cost changes; upgrade purchases invalidate waiting costs. It is not a general resource-dependent-cost proof.

Upgrade automation uses a 10-second cooldown. On each expiry it scans registry order, honoring tree membership, max levels, exclusivity preferences, requirements and affordability, and buys the first eligible upgrade. A failed scan still starts the normal cooldown; a large delta uses remainder arithmetic. Floating subtraction on 0.1-second ticks matters: resetting a timer from an idealized modulo formula can change state and purchase tick.

Generator cost uses base cost, mode activation multiplier, realm cost multiplier, modified exponential level scaling, cost modifiers and their sensitivities. Upgrade cost is its existing definition cost times its multiplier to the current level. Purchases deduct resources immediately. Earlier purchases compete with later managers; upgrades can change production, consumption, costs, sensitivity, unlocks and future eligibility. Crafting recipes and cycle activity add purchase conditions. Technology and generator unlocks are checked before timers progress.

An absence of recent purchases does not establish inactivity: output can make a waiting item affordable, an earlier consumer can remove affordability, and an automatic upgrade can unlock another buyer on the next tick.

## 2. Measured activity

Each row covers 600 simulated seconds using optional probes around the **actual production managers**. Timings below surround the original manager body, excluding the probe's additional affordability classification. They are instrumented wall time, not isolated CPU cycles, and are not used for throughput speedups. Waiting durations are summed **automation-entry seconds**, so six enabled buyers have 3,600 possible entry-seconds.

| Fixture | Purchases | Generator entry evaluations / failed-or-successful purchase attempts | Generator resource-blocked / unlock-wait entry-seconds | Upgrade entry evaluations / scans | Original manager bodies, generator / upgrade ms |
| Early | 25 | 6000 / 36 | 532.6 / 0.0 | 0 / 0 | 42.32 / 4.81 |
| Middle | 0 | 36000 / 6 | 3592.4 / 0.0 | 0 / 0 | 250.57 / 5.85 |
| Late Matter-cost + upgrade wait | 0 | 6000 / 1 | 600.0 / 0.0 | 6000 / 59 | 49.24 / 24.85 |
| Late Heat-cost wait | 0 | 12000 / 2 | 1200.0 / 0.0 | 6000 / 59 | 102.04 / 29.34 |
| Mixed | 1 | 36000 / 6 | 3592.6 / 0.0 | 36000 / 354 | 267.01 / 127.71 |
| Technology locked | 0 | 6000 / 0 | 0.0 / 600.0 | 0 / 0 | 19.73 / 4.65 |

Early purchase gaps: median 5.00 seconds, range 5.00–33.10; first purchase at tick 61. The funded middle fixture makes zero purchases: environmental/resource flows remove affordability before the initial cooldown expires. Its six real purchase attempts and 35,694 waiting checks still exercise the existing manager. The mixed fixture records a real upgrade purchase. These are controlled states, not captures from a player save; “middle” is an activity stress fixture, not a claim about typical player purchase frequency. A separate well-funded validation realm buys Thermal Conversion, exercising changes to both input draw and output.

## 3. Conservative boundary design

`autobuyer_boundary.gd` returns a classification and resource upper bounds. It has no cached rate or guessed purchase time:

- Disabled: retains the existing adaptive eligibility path.
- Provably waiting: all enabled buyers are unable to purchase over the interval.
- Possible purchase boundary: a cost resource can grow; use exact ticks.
- Currently affordable: use exact ticks, including the original cooldown and priority rules.
- Unsupported dependency/transition: dynamic costs, dynamic sensitivities, stale waiting cache, cooldown-to-wait transition, or an unknown bound; use exact ticks.

For a resource with **no possible producer**, its amount at interval start is a conservative upper bound while all remaining operations are nonnegative losses. An eligible static-cost purchase is impossible if that bound is strictly below its cost. For upgrades, a permanently unmet non-resource requirement, a resource requirement above its proven bound, or static exclusivity can also prove impossibility. Future upgrade candidates are considered rather than relying only on current `can_buy_upgrade` failures.

The proof is conditional on the inherited guard excluding **all** cycle/auto-run transitions, resource consumers, discrete outputs, discoveries, unsafe automatic upgrades, stateful dormancy effects and prestige-currency exposure. No purchase means no level change or new producer; the simultaneous “all buyers blocked” proof closes that dependency. Locked managers do not progress timers, and potentially changing unlocks still force exact simulation through the inherited automatic-upgrade guard.

Environmental sources must be included: Matter decay adds Heat. Heat is therefore not classified source-free when Matter can be produced or is above its decay threshold, even if no generator currently outputs Heat. The first mostly-inactive candidate omitted this edge; its observed comparisons passed, but its proof was incomplete. That eligibility/speedup is **rejected**. The corrected version falls back exactly in that case. No constant-current-rate estimate is accepted as a bound.

Dynamic generator cost modifiers and matching dynamic sensitivities are unsupported, even when a particular formula might be boundable. Existing live cost getters and waiting-cache checks are reused. Costs, formulas and generator identities are not copied into the scheduler. Definitions are never modified by the new fixtures.

The bound is valid under the frozen eligibility contract, rather than reporting a finite future purchase time. Existing adaptive step limits still apply. Predictions are rebuilt before every prospective trial; any intervening exact purchase or upgrade therefore gets fresh state, costs and dependencies. No stale prediction is used during exact fallback ticks.

## 4. Experimental integration

The base experimental runner gains three small extension hooks: automation eligibility, trial entry/exit, and accepted-interval commit. Existing runners retain their previous default behavior.

`autobuyer_offline.gd` temporarily suppresses manager enable flags during numerical probes, then restores every flag and invalidates structural indices. Trials cannot consume cooldowns, refresh caches or buy anything, including when a fine trial is only 0.1 seconds. The existing restricted checkpoint remains valid; it is not expanded into a general GameState clone.

On acceptance, stabilized generator waiting entries are unchanged and their checks can be skipped. Upgrade timers are different: the **existing manager** is replayed on each original 0.1-second tick, using the final resource values inside the proven box. Every relevant upgrade remains blocked at all values in that box, so each scan still fails for a proven reason. This preserves exact subtraction/overshoot and dictionary state without duplicating cooldown arithmetic. An independent reference-grid elapsed accumulator preserves the final fractional tick. A post-commit event/RNG check fails closed if the assumption is violated.

This deliberately leaves O(ticks) clock work and upgrade cooldown processing. It does not optimize all automation scans. The gain comes primarily from permitting fewer full resource/generator/reference-map evaluations while waiting, plus skipping constant generator waiting checks. No adaptive interval can contain a purchase in this first prototype.

## 5. Throughput

Linux Godot 4.6.1 headless on the same host, serial runs, explicit timeouts, seed 123456. This is **not** Windows Godot 4.7.2. Timers include guards, trials, checkpointing and retained endpoint snapshots. There is no rendered UI or production TimeManager integration. Optional activity instrumentation is excluded from these timings. Precise uses the authoritative 0.1-second simulator through the experimental runner; Previous uses the existing Horizon runner with its blanket automation guard.

Primary fixture: existing Atomic Friction Heat production, Matter-held feedback, Heat leak and Matter decay; enabled Matter Furnace autobuyer in its existing input-free mode at level zero, waiting on Matter it cannot receive; enabled Matter Furnace upgrade tree blocked by level requirements. This is a deliberately restricted continuous/waiting state, not a general late-game save. Its unlock state is set explicitly to isolate the mechanism; reachability with all preceding unlocked consumers retained was not established. The inherited consumer guard can therefore restrict real-save coverage more severely than this fixture suggests.

Times are medians [min–max] in seconds across three serial runs. Speedups are medians of **paired ratios**, not ratios of independently chosen median times.

| Duration | Precise s | Previous s | Event-aware s | Paired speedup |
| 10 min | 0.553 [0.488–0.560] | 0.537 [0.482–0.538] | 0.575 [0.496–0.623] | 0.96 [0.90–0.98]× |
| 1 h | 3.201 [2.848–3.239] | 3.197 [3.107–3.449] | 1.639 [1.559–1.732] | 1.85 [1.74–2.08]× |
| 4 h | 12.554 [11.992–14.422] | 12.945 [12.818–13.636] | 3.772 [3.613–4.289] | 3.18 [2.93–3.99]× |

The final one-hour repetitions were less favorable than the earlier 2.07× screen; both are preserved. No favorable run was substituted for the final median. Up to 600 seconds the existing short-duration policy uses exact simulation. Its overlapping timing ranges do not establish a short-run throughput improvement; the policy avoids paying adaptive startup/trial cost. A separate ten-minute forced-adaptive experiment is retained as a negative short-horizon observation, not the default policy.

| Duration | Evaluations: reference / candidate | Accepted / rejected | Exact ticks | Adaptive / exact coverage | Skipped generator waiting checks | Boundary calls / time ms | Upgrade replay time ms |
| 1 h | 36000 / 3100 | 423 / 50 | 370 | 98.972% / 1.028% | 35630 | 484 / 53.49 | 145.25 |
| 4 h | 144000 / 6842 | 962 / 98 | 600 | 99.583% / 0.417% | 143400 | 1072 / 113.65 | 557.54 |

Rejection/fallback reasons and times are recorded per run in `autobuyer_results.json`. Numerical cooldown retry remains bounded by the existing controller. Nested map, signature, trial and numerical timers overlap and must not be added as independent CPU costs. Upgrade evaluations are retained: four-hour accepted intervals replay 143,400 ticks, plus the exact fallback ticks. Boundary scanning is a small measured part of this fixture; reference-map/checkpoint/signature work and timer replay still limit throughput.

Additional checks: generator-only waiting achieves a measured one-hour median paired 1.98× gain (three runs). Upgrade-only waiting passes a dense one-hour comparison. A one-hour late Heat-cost fixture has **zero adaptive coverage**: a Heat producer invalidates the source-free bound even though it never makes a purchase. Its approximately 1.00× result is not an optimization gain. The realistic mixed fixture at 660 seconds also has **zero adaptive coverage**; consumers, an active Forge cycle and prestige-currency exposure remain independent blockers. Its small runtime difference is measurement noise, not evidence that automation solved those systems. A ten-minute mixed run likewise stays exact.

No 12-/24-hour runs were attempted: shorter mixed tests already establish no eligibility benefit, while four-hour waiting comparisons establish the restricted result. There is no measured realistic long-duration speedup or extrapolated six-minute result.

## 6. Accuracy and discrete events

Balanced retains rtol 1e-4 (0.01%) and atol 1e-8 with the existing distributed error estimator. Tolerances were not relaxed. Default ten-minute cases are binary exact. Separate dense oracle runs evaluate **every accepted candidate endpoint**, plus regular audits, on authoritative 0.1-second ticks.

| Dense check | Maximum resource abs / relative fraction | Maximum statistics abs / relative fraction | Final resource abs / relative fraction | Final statistics abs / relative fraction |
| 1 h | 6.956553e-05 / 4.848289e-07 | 0.002145252 / 1.372877e-06 | 1.529218e-05 / 1.518231e-07 | 0.0004063519 / 4.158151e-07 |
| 4 h | 2.276979e-05 / 1.805374e-07 | 0.001128367 / 5.039405e-07 | 1.220879e-06 / 1.217378e-08 | 0.000876714 / 3.280787e-08 |

The four-hour sampled resource maximum is about **0.0000181%** relative; the sampled statistics maximum is about **0.0000504%**. These maxima can occur in different fields and at different times. They are sampled errors, not certified continuous-time bounds. All resources, production/consumption/loss, peaks, lifetime/current-run/offline totals, Heat overflow, Matter decay and prestige inputs are included by the existing Metrics infrastructure.

All retained final-stage comparisons pass strict generator/upgrade levels, operating modes, unlocks, automation dictionaries, inventory, progression-log ordering, purchase tick/cost records, RNG and integer reward comparisons. Eligible waiting fixtures currently earn zero integer prestige reward; this is not proof about a later transition into nonzero prestige. Existing reward-exposure guards and reward-boundary regressions stay exact. Approximate historical statistics affecting future rewards remain a production-readiness concern.

Purchases are checked on exact fallback: early resource-triggered purchases, competing generator buyers, generator-versus-upgrade priority, production upgrades, Thermal Conversion changing consumption/output, the level-25 unlock enabling another autobuyer, consumer-driven resource fluctuations, and active mixed cycles. Tests rerun immediately before/at/after the first purchase tick, as well as cooldown boundaries 4.9/5.0/5.1 and 9.9/10.0/10.1 seconds. A separate alternating-availability unit test checks read-only proof inspection and immediate invalidation, rather than pretending an exogenous resource change can be skipped. Realm-cost, level, dynamic modifier and dynamic-sensitivity changes invalidate proofs. Zero, fractional and short intervals remain exact.

## 7. Validation and failed experiments

**80 regression tests passed, zero failures, no parser warnings or runtime errors.** All 76 previous tests are retained; four new groups cover waiting eligibility/cooldowns, purchasing boundaries, dependency invalidation/oscillation, and zero/short intervals. Existing save/load, critical crafting, cosmetic/global RNG interference and offline scheduling regressions also pass. Save format and RNG implementation are unchanged.

The existing corrected offline benchmark entry point also completed cleanly, including its one-hour reference/profile and 0.5/1.0-second comparison experiments. Those coarse-step accuracy differences are pre-existing benchmark observations and are not enabled by this change. The new default path retains the authoritative grid at purchases.

Invalid development runs are explicitly preserved: an initial per-manager flag restoration indentation bug caused single-manager parity failures; focused tests caught it and it was corrected before final validation. A retained strong test distinguishes generator-only, upgrade-only and jointly enabled managers. A conditional typed-array assignment in the new dense harness was rejected and corrected. A callable reference cycle that leaked runner objects was replaced with a weak reference. No passing command is accepted solely from Godot's exit code; the launcher also scans warning/error output. The source-free Heat proof omission described above is a rejected eligibility case, even though its observed values happened to pass.

Initial test-environment preparation lacked imported graphical dependencies and is invalid. Unrestricted parallel asset import crashed locally; import with one CPU completed. Its unrelated existing `game.gd` indentation defect remains outside scope, as documented in the previous report. The final standalone regression and benchmark logs are clean; no clean full-editor/rendered launch or Windows 4.7.2 validation is claimed.

`autobuyer_results.json` retains commands, timeout bounds, observations, stage-specific source snapshots/hashes, failures and the final regression log. Earlier/negative observations are not pooled into the primary final medians. All processes were bounded; no benchmark needs to remain running after completion.

## 8. Extension and recommendation

Continue targeted research; do not enable this in production. The primary milestone is met narrowly: enabled, provably resource-blocked automation can coexist with adaptive continuous simulation. The realistic automation-heavy speed goal is not met.

This interface can accept additional resource-bound providers, but a production-rate estimate is not such a provider. A next batch should first measure real-save coverage, then investigate a conservative Heat availability envelope using the existing live formulas and explicit environmental dependency metadata. Preserve exact fallback for unboundable modifiers and affordability. The late Heat-wait negative case is the useful target, rather than making another favorable Matter-only fixture.

Finite purchase boundaries require more than switching to exact ticks near an estimated crossing. Earlier accumulated numerical error can still shift the first affordable tick, priority, unlock timing and later RNG. A validated interval/error enclosure or a justified authoritative replay/correction strategy is needed before those transitions can be allowed. Step-doubling estimates alone do not certify them.

Consumers add input allocation priority, resource exhaustion, throttling and dormancy; cycles add activation/completion order and RNG. They are not safe extensions merely because a next completion time is known. Keep them exact until their event and integration contracts are independently demonstrated. Do not add a large queue or widen tolerances to work around this obstruction.

**Practical answer:** no, these results do not yet reliably reduce a realistic roughly 36-minute catch-up to six minutes. They demonstrate a removable 1.8–3.2× experimental gain in one bounded waiting regime, with strict discrete checks, while identifying the important remaining growing-resource, consumer, cycle and future-reward problems.

## Reproduce

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output hour.log --timeout 60 -- --scenario=late_both --duration=3600 --repeats=3
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output four-hours.log --timeout 110 -- --scenario=late_both --duration=14400 --repeats=3
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output dense.log --timeout 60 -- --scenario=late_both --duration=3600 --dense=true
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output activity.log --timeout 45 -- --scenario=early --duration=600 --profile=true
```

Use explicit timeouts appropriate to the machine. `--short_exact=0` disables the short-duration mitigation for experiments only; it is not the default. Internal mode configurations and production TimeManager settings are unchanged.

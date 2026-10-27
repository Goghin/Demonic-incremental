# Adaptive offline simulation: feasibility study

Base: `cc096181308347758ec8492a5257b015469a22f7`, `feature/cycle-auto-run`.

**Recommendation B — continue targeted experimentation. Do not enable this prototype in production.** It accelerates restricted input-free workloads, but common resource-consuming, automated and crafting workloads fall back completely. Nonlinear Heat/Matter controls can become slower than the reference. No production file, balance constant, save schema, RNG implementation, TimeManager path or real-time path is modified.

## 1. The numerical target is an ordered map

Let `F_h` be one existing `Simulation.update(h, true)`. The authoritative target is repeated `F_0.1`, including its rounding, mutation order and statistics. It is not necessarily the solution of an ideal continuous differential equation. The current order is:

1. Capture starting Heat; reset interval logging state if needed.
2. Scan pending automatic upgrades in registry order; test live requirements, apply effects immediately, log applications. Earlier applications can enable later ones in the same scan.
3. Compute the per-tick Eternal Furnace multiplier.
4. Iterate generators in registry order: update throttle state; process cycles, or test startup, bound operating time, consume inputs, then produce outputs. Earlier generators and earlier IO entries mutate resources seen by later calculations.
5. Apply Matter decay, including its Heat production, then Heat leak.
6. Run generator automation, then upgrade automation, in their existing independent registry orders.
7. Maintain offline logging state. TimeManager separately updates real/game/prestige clocks, stabilization and dormancy before each simulation tick and yields according to its work budget.

This order makes a long tick different from many short ticks even when all formulas are reused. In particular, a consumer can take resources before a later generator or buyer sees them. Computing a rate once and multiplying by a duration loses these interactions.

### Governing formulas and dependency map

Here `S` is the product of applicable sensitivity multipliers, `l` the generator level when the definition scales rates with level, `h` a requested duration, and `T`, `c`, `p`, `m`, `b` parameters read from the existing definitions/state. Symbols do not introduce new balance constants.

| System | Existing formula / update | Type and dependencies | Interval/event implications |
|---|---|---|---|
| Continuous output | Base IO rate × level (or 1) × mode multiplier × realm/resource-specific multiplier, followed by ordered `Modifier.apply` operations. Output is rate × available operating duration. | Continuous, but rates read the current resource amounts after input consumption and previous outputs. Heat also uses the Eternal Furnace multiplier; Matter uses realm production. | Variable stepping is approximate unless rates are invariant. Preserve generator/IO ordering, balances, discovery and all flow/peak statistics. |
| Input consumption | Available duration is `min(h, available_i / rate_i)` over positive-rate inputs. Consumption then recalculates each rate and subtracts `min(rate_i * duration, available_i)`. | Continuous with exhaustion boundaries and allocation priority. Later input rates can see earlier deductions. Transfer modes have a special conserving path. | Do not infer a safe future exhaustion time from one current rate. This prototype rejects all unlocked input-bearing continuous generators, including paused/level-zero ones whose throttle flags may be stateful. |
| Heat leak | `L(H)=0` for `H<=T`; otherwise `c*((H-T)/max(T,1))^p`. Coefficient is `max(20, configured_scaling-2*coefficient_upgrade)` and exponent `max(2, configured_exponent-0.02*exponent_upgrade)`. | Nonlinear continuous loss, evaluated after generators and Matter decay. Thresholds depend on realm and upgrades. | Normal steps subtract `min(L(H_after)*h,H_after)`. If requested loss reaches 5% of excess (or the threshold is crossed downward), use the existing 16-substep implicit balance solver, with safeguarded Newton/bisection. Changing `h` can switch numerical branches. |
| Matter decay | Same configured power-law shape above its threshold. `d=min(D(M_after)*h,M_after)`; subtract `d` Matter and add `d` Heat. | Nonlinear, coupled to Matter-held Heat bonuses and Heat leak. | Record Matter loss, Heat production, lifetime/run/offline decay and the current-realm reward counter. Decay cannot be modeled as an isolated inventory deletion. |
| Ash | Sum generator outputs minus input consumption. Contamination uses a configured inverse-square-root multiplier above the resource threshold. | Continuous quantity, threshold-dependent production penalty and cycle-speed penalty; also a Lava Mite input. | Ash affects subsequent rates and cycle progress. High-Ash fixture unlocks a consumer and therefore falls back; no generator-name shortcut bypasses it. |
| Essence | Ordinary production plus held-amount penalty. The inverse-square-root modifier is `1/(1+m*(sqrt(E)-sqrt(T)))` above threshold, otherwise 1, followed by sensitivity adjustment. | Continuous self-limiting production. Essence also changes Crystallization sensitivity and Lava Mite Ash input. | Isolated Essence production is supported experimentally; Essence coupled to consumers is not. Spending or another system changing Essence would require a boundary. |
| Crystallized Flame | Raw compounding penalty `b^CF` (configured base 0.8). Effective multiplier is `max(raw,0)^clamp(S,0,1)`, unlike ordinary linear sensitivity. | Discrete craft output in current data, with continuous consequences for rates; Essence changes `S`. | Completion can reset all Heat as resource loss. This loss is not automatically environmental overflow. Preserve activation-time crafting chance and completion order. Cycles always fall back. |
| Other dynamic modifiers | Log: `1+m*realm_scale*log10(x)` above 1; sqrt: `1+m*sqrt(x)`; inverse sqrt above threshold; inverse reservoir boost: `1+max(m,0)/(1+max(x,0)/max(T,1))^max(p,0)`; power threshold: `1+m*((x/T)^p-1)` above T; exponent `b^x`; level `1+m*l`; dormancy uses the live dormancy multiplier. | Continuous/piecewise dependencies on resources, levels, mode and realm. Ordinary effective multiplier is `1+(raw-1)*S`. Dynamic sensitivity is configured inverse sqrt, mode-filtered, multiplied with other sensitivities. | Reuse the existing evaluation code. Do not regroup multiplications or assume all rates are positive/invariant for arbitrary untested relic configurations. The supported subset and observed fixtures are not a proof for future custom definitions. |
| Throttle/hysteresis | Existing Lava Mite fallback suppresses configured input escalation when normal inputs cannot be sustained; recovery requires a full one-second normal-rate reserve. | Stateful, reads current resources and can update flags even when paused. | Endpoint-only resource checks can miss a transition. Consumers are excluded rather than reproducing this mechanism in a second model. |
| Generator automation | Enabled/unlocked gate, cooldown subtraction with overshoot. Unaffordable purchases enter resource-wait mode, checked once each update. Cost is base × mode × realm × modified scaling^level × cost modifiers. | Discrete, priority-sensitive; affordability depends on the post-environment state and previous purchases. | Current cooldown expiration is not a sufficient event boundary. Affordability and waiting can change first. All enabled automation falls back; existing cache invalidation and order are untouched. |
| Upgrade automation / automatic upgrades | Upgrade buyers choose the first affordable eligible upgrade in tree/registry order; failed checks restart the configured cooldown. Automatic upgrades scan live requirements every tick. | Discrete; requirements currently reference resources, generator levels, purchased upgrades or upgrade levels. | Every potentially changing automatic resource gate stays on exact ticks. The guard requires each pending automatic upgrade to have an unmet requirement that cannot be the first event in the proposed event-free interval. |
| Cycles | Progress increases by `duration*max(product(cycle_speed_modifiers),0)`. Offline cycles bound time to completion and input availability; auto-run spends remainder on subsequent activations. | Continuous progress plus discrete completion, recipe consumption, output, critical and downlevel events. | Speed/input bounds depend on resource changes. Order is event rolls → completion resources/signals (including CF Heat reset) → inventory/relic generation → completion consequences/downlevel rolls → clear/restart. Never reorder these operations. |
| RNG | GameState-owned PCG stream; compatibility samplers preserve old global helper precision/draw counts. Chance 0/1 can avoid draws. Relic critical, weighted effect, stat, target, name and secondary rolls share this stream. | Discrete/order-sensitive. | No speculative interval may consume a gameplay draw. Guarded trials check RNG state before accepting; cycles/automation use original exact ticks. All production RNG code is unchanged. |
| Peaks, overflow and prestige | Every setter records resource peaks, including pre-leak/pre-consumption transients. Leak records raw Heat loss; environmental overflow reward counter adds loss × `1.25^CF`. Matter reward counter records actual decay. Each environmental reward multiplier is `max(1,1+0.1*log10(total))`; multiply both. Smash gain is `floor(CF*sqrt(forge_level)*environmental_multiplier)` when eligible. | Continuous statistics, discrete rounded reward, stateful history. | Match flows and peaks, not just ending resources. The discrete audit also compares projected rounded Smash gain. No actual Smash/reset or reward formula is changed. |

### Why solving a nicer ODE is insufficient

Consider constant Heat production `P` while the reference stays on its explicit leak branch. Its map is `H_next=H+P*epsilon-epsilon*L(H+P*epsilon)`. At equilibrium, the **pre-leak** Heat solves `L(H_pre)=P`, so the recorded post-tick balance is `H_pre-P*epsilon`. A larger explicit step instead has an offset proportional to that larger step. A larger implicit step may converge toward the ideal ODE equilibrium instead. Those are different numerical balances. Higher order alone does not recover the `epsilon=0.1` map.

Peaks are another obstacle: a larger tick records production before leak as one larger transient. Even if ending balances agree, the peak statistic can differ. Likewise, a small endpoint resource error can have a larger relative effect on accumulated early overflow and therefore rewards. These are measured below, not repaired by dropping a statistic.

## 2. Isolated prototype and guard contract

All implementation is under `tests/experimental/`. The only existing code changed is the regression runner to register seven additional cases. There is no production preload, setting, save flag or call to the prototype.

The prototype uses one coarse `F_h` trial, restores a restricted continuous checkpoint, and evaluates two ordered substeps on the 0.1-second grid. It keeps the two-substep state if the estimated error meets its budget, otherwise restores the checkpoint and shrinks. It never introduces intermediate sub-reference steps; a final fractional remainder is permitted just as in the reference. A coarse minimum trial can therefore cost more than simply using the reference, as the nonlinear results demonstrate.

A checkpoint restores resource amounts, lifetime/run/offline flows and peaks, overflow/decay reward counters, discoveries, operating/throttle flags, dormancy, interval logging and Simulation logging state. It is **not** a general rollback/save system. It is only legal after the event/input guards pass. Unexpected discrete mutation/RNG consumption aborts the experiment; that replica must be discarded, not resumed with a partial rollback.

Default error budget is `atol + rtol*max(abs(coarse),abs(fine))`, distributed by `h/total_duration` for accumulated quantities. Peaks use the undivided budget because they are maxima, not sums. This is conservative bookkeeping, **not a certificate** that the global reference-map error meets the target. An optional local-only budget is an explicitly experimental comparison; its failures are retained.

Configuration: maximum step (default 60 s), minimum step (default 0.1 s; accepted doubled intervals require at least two reference ticks), absolute tolerance (1e-8), relative tolerance (1e-4), environmental event margin (0.1 resource units), fallback window (10 exact ticks), audit interval (60 s), distributed/local budget, force-exact mode and an environmental-feedback guard. A configured maximum of 0.1 s forces exact stepping. Invalid nonfinite or sub-reference settings are rejected before state mutation.

The isolated interval owns a fresh scale-one TimeManager context. Accepted elapsed time is committed to game/offline/prestige/current-duration clocks; these clocks and dormancy are audited against repeated reference additions. Trials do not advance accepted clocks. Existing accumulated clocks, scaling, stabilization/recovery and UI scheduling are not integrated; unsupported contexts are rejected.

The event-aware component is deliberately narrow:

- Any enabled automation, active/auto-run cycle, unlocked continuous consumer, discrete output, time-dependent dormancy modifier, unsettled operating flag or potentially changing automatic-upgrade gate requests exact simulation.
- Resource discovery and startup transitions occur on exact ticks. The guard scans definitions and live state; it has no hardcoded generator IDs.
- A pending automatic upgrade is blocked only when it has an unmet non-resource requirement, or an unmet requirement on a resource that cannot change in the supported interval. With no level/purchase/cycle changes, there can be no first automatic event if all pending upgrades are blocked this way. Otherwise fall back, including through chains of applications.
- Environmental threshold crossings/near-threshold endpoints reject the approximate interval. Remaining difficult cases shrink or fall back. No event queue or affordability extrapolation is implemented.

Guard checks cost time even when they reject; repeated numerical rejection adds trial/snapshot overhead. Increasing the exact fallback window reduces that retry overhead but does not accelerate continuous integration itself.

## 3. Correctness and measurement definitions

**A — strict:** binary SHA-256 discrete snapshots compare generator levels, unlocks, operating/throttle flags, modes/IO unlocks, discrete production fractions, active cycles, critical snapshots, upgrades, discoveries, inventory/equipment, automation cooldown/waiting state, prestige state and projected rounded reward, plus gameplay-log order. RNG state is compared separately. Focused regression tests additionally wire craft/normal/critical/downlevel/unlock signals into the strict event log and assert exact fallback binary state.

**B — measured numerical targets:** rtol 0.001 / 0.0001 / 0.00001 represent 0.1% / 0.01% / 0.001%. They are experiment settings, not approved tolerances. Default absolute tolerance near zero is 1e-8 in each field's units. Compare every resource, lifetime/run/offline flow and peak, environmental reward input/multiplier, dormancy and cycle progress. Each field passes only if `abs(error)<=atol+rtol*abs(reference)`. Report independent maximum absolute/relative errors and the worst normalized field.

Audits run at every accepted macro endpoint and fixed checkpoints (default 60 s). Thus “maximum” means **maximum observed at common audited times**, not a proven bound between audits or at every 0.1-second point. Reference peak statistics include its internal transients. Error targets are checked against the authoritative fixed-step run, independently of estimator acceptance. Longer unsupported cases are not expanded merely to fill a matrix.

**C — timing:** Godot 4.6.1 stable Linux headless, same engine/host, serial runs. The user's Windows/Godot 4.7.2 rate is background information, not remeasured here. Startup/setup/final serialization are excluded. Reference compute time subtracts benchmark audit/comparison time from its elapsed loop; raw elapsed time and audit time are also recorded. Adaptive wall time conservatively includes its audit capture plus event checks, rollback, estimation and all numerical evaluations. Reported speedup is reference compute time divided by that adaptive wall time. No rendered loading screen is included.

Counters include accepted/rejected intervals, **all** numerical calls (including discarded trials), exact fallback ticks, prefilter/signature time, numerical `Simulation.update` time, trial-path time, fallback time and checkpoint capture. These scopes overlap: trial/fallback time includes numerical work, and trial time includes event checks; do not sum all counters. Memory includes initial checkpoint serialization size, retained audit trace bytes, before/after Godot static allocations and absolute process engine-static peak. These are not a platform-independent RSS peak or a prediction for the Windows build.

Fixtures use existing definitions/formulas. The `stable` fixture raises realm Stability to 1e20 solely to isolate a linear no-leak control; it is not a representative player realm or a proposed balance change. `matter` tests stored Matter decay feeding Heat and the Matter-held Heat bonus. Actual Matter production plus decay and shared input allocation are in the unsupported `coupled` fixture. `ash` is high contamination; its automatically unlocked consumer makes it unsupported. `essence` is isolated existing Essence mode with level 1000 and 10000 held Essence. Both automation managers, repeated critical crafting, starved generators, and combined resource effects have dedicated fixtures. Critical fixture costs/reserves are synthetic controls, as in Batch C.

## 4. Results

The companion `adaptive_results.json` retains final and exploratory observations, including unfavorable timings, numerical failures, timing breakdowns, memory data and source fingerprints. Tables are generated from final observations; exploratory screens used earlier diagnostic instrumentation and are not pooled into these medians.

<!-- generated -->
### Primary throughput: default conservative policy

Times are median [range] seconds. Two repeats for ten-minute/hour/four-hour cells; full-day cells have one bounded sample and do not establish a statistical speed guarantee. Ratios are medians of paired per-run ratios. Every row passes strict discrete and RNG comparisons. “Fallback %” is the percentage of simulated reference ticks executed exactly, not the percentage of attempted macro steps.

| Fixture | Duration | N | Reference compute s | Adaptive wall s | Speedup | Reference / adaptive evaluations | Accepted / rejected | Fallback % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| fresh | 0.166667 h | 2 | 0.272 [0.266–0.278] | 0.458 [0.449–0.467] | 0.59× | 6000 / 3573 | 20 / 278 | 44.6500 |
| stable | 0.166667 h | 2 | 0.260 [0.260–0.261] | 0.024 [0.024–0.024] | 10.93× | 6000 / 73 | 21 / 0 | 0.1667 |
| heat | 0.166667 h | 2 | 0.319 [0.296–0.343] | 1.093 [1.055–1.131] | 0.29× | 6000 / 7797 | 0 / 599 | 100.0000 |
| matter | 0.166667 h | 2 | 0.361 [0.356–0.366] | 1.060 [1.058–1.062] | 0.34× | 6000 / 7797 | 0 / 599 | 100.0000 |
| ash | 0.166667 h | 2 | 0.315 [0.295–0.334] | 0.306 [0.291–0.321] | 1.03× | 6000 / 6000 | 0 / 0 | 100.0000 |
| essence | 0.166667 h | 2 | 0.239 [0.233–0.244] | 0.026 [0.026–0.026] | 9.25× | 6000 / 73 | 21 / 0 | 0.1667 |
| starved | 0.166667 h | 2 | 0.417 [0.405–0.428] | 0.443 [0.440–0.445] | 0.94× | 6000 / 6000 | 0 / 0 | 100.0000 |
| automation | 0.166667 h | 2 | 0.911 [0.900–0.922] | 0.957 [0.928–0.986] | 0.95× | 6000 / 6000 | 0 / 0 | 100.0000 |
| upgrade_automation | 0.166667 h | 2 | 0.836 [0.824–0.849] | 0.835 [0.820–0.850] | 1.00× | 6000 / 6000 | 0 / 0 | 100.0000 |
| cycles | 0.166667 h | 2 | 0.520 [0.515–0.525] | 0.507 [0.487–0.527] | 1.03× | 6000 / 6000 | 0 / 0 | 100.0000 |
| coupled | 0.166667 h | 2 | 0.684 [0.678–0.690] | 0.707 [0.697–0.718] | 0.97× | 6000 / 6000 | 0 / 0 | 100.0000 |
| idle | 0.166667 h | 2 | 0.197 [0.196–0.198] | 0.028 [0.027–0.029] | 7.11× | 6000 / 72 | 24 / 0 | 0.0000 |
| stable | 1 h | 2 | 1.562 [1.548–1.575] | 0.086 [0.085–0.087] | 18.10× | 36000 / 223 | 71 / 0 | 0.0278 |
| essence | 1 h | 2 | 1.612 [1.503–1.720] | 0.270 [0.264–0.276] | 5.96× | 36000 / 607 | 199 / 0 | 0.0278 |
| idle | 1 h | 2 | 1.209 [1.181–1.236] | 0.082 [0.078–0.087] | 14.67× | 36000 / 222 | 74 / 0 | 0.0000 |
| stable | 4 h | 2 | 6.207 [6.105–6.310] | 0.292 [0.287–0.297] | 21.26× | 144000 / 763 | 251 / 0 | 0.0069 |
| essence | 4 h | 2 | 5.849 [5.843–5.854] | 1.381 [1.357–1.405] | 4.24× | 144000 / 3514 | 1155 / 3 | 0.0278 |
| idle | 4 h | 2 | 4.625 [4.536–4.714] | 0.276 [0.253–0.300] | 16.83× | 144000 / 762 | 254 / 0 | 0.0000 |
| stable | 24 h | 1 | 41.659 [41.659–41.659] | 1.798 [1.798–1.798] | 23.17× | 864000 / 4363 | 1451 / 0 | 0.0012 |
| essence | 24 h | 1 | 36.397 [36.397–36.397] | 6.068 [6.068–6.068] | 6.00× | 864000 / 14555 | 4766 / 19 | 0.0231 |
| idle | 24 h | 1 | 28.328 [28.328–28.328] | 1.652 [1.652–1.652] | 17.15× | 864000 / 4362 | 1454 / 0 | 0.0000 |

The linear control's speedup comes from fewer existing Simulation calls, not a cheaper resource formula. A large interval still executes every statistics-recording operation in its reused ordered update map. Inactive simulation also reduces calls, but updates dormancy and commits interval clocks. Enabled buyers and auto-run cycles remain permanently guarded, even after starvation: their fallback-only result cannot be extrapolated into a general speedup. A 24-hour matrix of those unsupported cases would repeat exact simulation with guard overhead, so it was not run.

### Measured accuracy, 600 seconds

Each entry shows maximum across all repeats. Resource and non-resource numeric errors are independent maxima and may occur in different fields/times. Relative figures use `max(abs(reference), atol)` near zero. The non-resource group includes all statistics/reward inputs, cycle progress, dormancy and interval clocks. Complete final/max values for every long run remain in JSON.

| Fixture | Target % | Max resource abs / relative % | Final resource abs / relative % | Max other abs / relative % | Final other abs / relative % | Worst normalized error | Target pass |
|---|---:|---:|---:|---:|---:|---:|---|
| stable | 0.1 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 2.139e-10 | pass |
| stable | 0.01 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 2.139e-09 | pass |
| stable | 0.001 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 3.85e-10 / 2.14e-11 | 2.139e-08 | pass |
| essence | 0.1 | 3.3e-05 / 3.29e-07 | 3.3e-05 / 3.29e-07 | 3.3e-05 / 0.000549 | 3.3e-05 / 0.000549 | 0.005493 | pass |
| essence | 0.01 | 3.5e-05 / 3.5e-07 | 3.5e-05 / 3.5e-07 | 3.5e-05 / 0.000583 | 3.5e-05 / 0.000583 | 0.05829 | pass |
| essence | 0.001 | 8.91e-06 / 8.9e-08 | 8.91e-06 / 8.9e-08 | 8.91e-06 / 0.000149 | 8.91e-06 / 0.000148 | 0.1492 | pass |
| heat | 0.1 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | pass |
| heat | 0.01 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | pass |
| heat | 0.001 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | pass |
| matter | 0.1 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | pass |
| matter | 0.01 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | pass |
| matter | 0.001 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | pass |

The tightened 0.001% Essence target reduces speed substantially; a tolerance label alone does not guarantee a useful acceleration. Heat/Matter accuracy in the conservative controls is primarily the result of exact fallback, not successful adaptive integration.

### Rejected numerical policy and fallback overhead control

The local-only, relaxed-absolute controls use rtol 0.1%, atol 1e-6. Their ending errors pass, but their maximum observed statistics errors fail. They are failed experiments, not approved configurations.

| Control | Ref / adaptive s | Final normalized | Maximum normalized | Worst field | Discrete / RNG |
|---|---:|---:|---:|---|---|
| heat | 0.335 / 1.010 | 0.644 | 8.958 | lifetime/overflow | pass / pass |
| matter | 0.410 / 1.966 | 0.360 | 2.988 | lifetime/overflow | pass / pass |

The same local policy at the original 0.01% target happened to pass the isolated full-day Essence fixture: 20.00×, maximum normalized deviation 0.06593. This is a useful restricted result, not a general error guarantee; the failed feedback controls prohibit enabling local-only acceptance broadly.

Increasing the exact fallback window from 10 to 100 ticks on Heat reduced rejection retries to 59 and numerical calls to 6177, at 0.80× reference speed. This mitigates bookkeeping cost but still gives no integration speedup. The default was not retuned to conceal the original rejection cost.

### TimeManager control and memory

These are headless catch-up measurements, including the existing yield/progress mechanism, without the rendered game scene. The adaptive prototype is not installed in TimeManager. Its fresh interval clocks are compared as numerical fields. Non-unit time scale, stabilization/recovery contexts, accumulated save clocks and repeated use of the same interval object are unsupported and rejected rather than silently approximated.

| Fixture / duration | Direct reference s | TimeManager catch-up s | Adaptive wall s | Manager steps / yields | Manager discrete / RNG |
|---|---:|---:|---:|---:|---|
| cycles / 600s | 0.471 | 0.488 | 0.568 | 6000 / 40 | True / True |
| stable / 3600s | 1.533 | 1.719 | 0.100 | 36001 / 138 | True / True |
| stable / 600s | 0.298 | 0.294 | 0.028 | 6000 / 24 | True / True |

| Full-day fixture | Initial checkpoint bytes | Audit trace bytes | Static allocation delta bytes | Absolute engine-static peak bytes | Numerical / guard+signature / fallback time s |
|---|---:|---:|---:|---:|---:|
| essence | 1432 | 8289292 | 45023388 | 138904842 | 0.792 / 3.366 / 0.010 |
| idle | 940 | 1675016 | 9124732 | 106218219 | 0.192 / 0.971 / 0.000 |
| stable | 1392 | 2397288 | 13498236 | 107332226 | 0.253 / 0.998 / 0.001 |

## 5. Validation, failures and unsupported scope

The baseline had 57 passing cases. The final runner passed **64 cases, zero failures**, with no parser warnings or runtime errors: checkpoint/statistics rollback, restricted accuracy/parity, binary-exact fallbacks, automatic-resource threshold order, rejected-step restoration, save/load continuation, and configuration/short-duration coverage were added. All four existing benchmark entry points and the adaptive benchmark completed cleanly; all 62 primary observations passed discrete/RNG checks and two intentionally loose numerical controls failed their measured accuracy targets. No measurement timed out. Critical tests explicitly observe unlock, normal/critical completion, downlevel and craft signals, including a guaranteed critical relic fixture. Coupled fallback tests include Crystallized Flame, Essence resistance, environmental rewards and 900 seconds of dormancy evolution. The test-only critical fixture first failed an observability assertion because automatic contamination prevented a short Forge completion; settling automatic effects before isolating the fast-cycle fixture corrected the test without changing any production mechanics.

Existing regression, original offline benchmark, component benchmark, performance entry point and Batch-C entry point are checked for nonzero exits and `SCRIPT ERROR`, `ERROR:` or `WARNING:`. Parser/runtime errors are failures. Initial editor import still exposes the starting checkout's existing font/theme and `game.gd:771` indentation failures; they are not fixed here, and no clean full-scene launch is claimed.

Unsupported for adaptive advancement: input-bearing continuous generators, shared resource exhaustion/allocation, throttling/hysteresis consumers, enabled automation (including waiting/cooldown states), active or auto-run cycles, discrete production, unsafe automatic/discovery/startup transitions, time-dependent modifiers, planning states, arbitrary unvalidated/custom relic configurations, non-unit TimeManager scaling, existing stabilization/recovery state and accumulated save/resume clock contexts. Some supported feedback intervals nevertheless fail the numerical estimator and use exact fallback. No approximations are enabled in production.

There is no proof of dense-time global error, arbitrary threshold/event safety, or equivalence across every save. The checkpoint is only a restricted benchmark transaction; unexpected discrete mutation aborts and requires discarding the replica. Synthetic fixtures are not the user's actual 22-hour save. All final measurements are serial, with N=2 where practical and explicit N=1 full-day controls. No unfavorable numerical failures or timing samples are excluded from JSON.

## 6. Realistic acceleration and next phase

**B — continue targeted experimentation**, with a production no-go at this stage. Restricted gains demonstrate feasibility for event-free islands, not for the current coupled automated game. This prototype's guard gives those common workloads no adaptive coverage; the current version cannot be expected to shorten the user's 12–13-minute catch-up materially.

For a fraction `q` of baseline execution time still requiring exact work, even an infinitely fast adaptive remainder cannot exceed `1/q`. Overall 10× requires less than 10% exact work; 25× less than 4%; 50× less than 2%, before dispatch/validation overhead. These are theoretical bounds, not measured forecasts. The measured full-day restricted speedups above do not establish 25× or 50× for real saves. Increasing step caps or removing audit overhead could improve controls, but no such general acceleration is validated, and the conservative Essence target is substantially more expensive than the linear control.

Recommended next experiment, separately authorized before any production integration:

1. Profile a representative real save on the target engine and measure how much work could actually be event-free. Keep resource/statistics traces and the 0.1-second oracle.
2. Calibrate a coarse operator against the **reference map**, including its explicit/implicit Heat branch, pre-leak peaks and reward flows. Investigate reference-map correction rather than assuming a higher-order ODE solver preserves balance.
3. Only then derive conservative resource bounds and exact-grid event localization for one automation/consumer combination. An explicit dependency description is needed before taking long steps across affordability, exhaustion or variable cycle speed. Preserve original priority and RNG order; replay exact ticks near uncertain boundaries.
4. Reassess whether dependency/event infrastructure is worth its maintenance cost. If coverage remains poor, propose bounded offline duration, explicit approximation policies or an underlying update-architecture change as separate design decisions; none is implemented here.

## Reproduce

Use an imported project and the same Godot build for both paths. The prototype has no production setting. Run from the repository root:

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=stable --duration=600 --tolerance=0.0001 --repeats=2
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=essence --duration=14400 --maximum=60 --minimum=0.1 --absolute=1e-8 --tolerance=0.0001 --margin=0.1 --fallback_window=10 --audit=60 --repeats=2
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=cycles --duration=600 --mode=manager
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=heat --duration=600 --distributed=false --absolute=1e-6 --tolerance=0.001
```

Supported fixture names: `fresh`, `stable`, `heat`, `matter`, `ash`, `essence`, `starved`, `automation`, `upgrade_automation`, `cycles`, `coupled`, `idle`. Some are intentionally fallback-only. Other controls: `--force_exact=true`, `--environment=false`; use a new experimental interval object for each call. Start with 60–600 seconds. The study bounded short commands at 20–35 seconds and individual full-day runs at 50–60 seconds; do not launch an unrestricted target-machine matrix. Deleting this directory and its seven registrations in the regression runner removes the experiment.

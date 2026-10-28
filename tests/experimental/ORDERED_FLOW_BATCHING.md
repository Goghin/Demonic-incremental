# Ordered resource-flow batching: guarded macro-pass experiment

## Result and implementation boundary

This is a **negative result for ordered generator-major macro aggregation**, not a successful Heat/Matter batching implementation and not an impossibility proof for every future method. The candidate computes multiple ticks with one ordered flow pass and substantially fewer rate evaluations, but cannot preserve the required output phases and feedback history. No nonzero gameplay interval is certified or committed. Rejected candidates roll back through the existing optimized transaction and then execute authoritative ticks. The existing experiment and production simulator remain unchanged.

Base: `e6657d0c4296b3550eb2c6207984ec258866a130`, branch `feature/cycle-auto-run`. No branch creation/switching. Six pre-existing untracked asset/UID files are preserved. The sole change outside tests/experimental is registration of one regression group. The known game.gd:771 editor issue is unchanged.

New files provide a data-driven flow/dependency inspector, a single-pass candidate, reproducible reached/diagnostic fixtures, raw candidate and drift validation, serial three-way benchmarks and this report. Only an idle/no-flow invariant is accepted, to test commit lifecycle; paused idle controls are excluded from gameplay benchmark/coverage claims. Nonzero flows have no admission certificate. No Forge, Mite, autobuyer or relic batching is introduced.

## 1. Authoritative execution order verified from source

Inspected sources: simulation/simulation.gd:update, consume_inputs, produce_outputs, apply_environmental_effects, apply_matter_decay, apply_heat_leak and _integrate_heat_balance; Generators/generator.gd rate, mode, start/availability and phase methods; actual generator definitions; Game/modifier.gd, modifiersensitivity.gd, game_state.gd and upgrade registry effects. Existing RESOURCE_FLOWS.md, HEAT_MATTER_FEEDBACK.md, CORE_GAMEPLAY.md, TRANSACTIONS.md and CHECKPOINT_PROFILING.md inform the strategy comparison.

For each authoritative 0.1-second offline tick:

1. Read tick-start Heat; reconcile realm-index/interval tracking and offline-entry bookkeeping.
2. Evaluate automatic upgrades in registry order against the current resources/levels. Apply ordinary modifier/sensitivity/unlock/threshold effects immediately.
3. Calculate the Eternal Furnace multiplier once. Traverse registered generators in order: Atomic Friction, Molecular Agitation, Lava Mites, Condensation, Matter Furnace, Arcane Compressor, Forge, Relic Crucible. Unlocked level-zero controllers can still update flags.
4. Run throttle selection before operation eligibility. For an operating continuous generator, compute available duration from the current inputs. In offline mode a positive but insufficient stock allows partial operation; zero stock with a positive required rate cannot start. Available duration is capped by each current input amount/rate and requested duration.
5. Consume input IO entries in order, clamping requested consumption to the current stock. Record consumption and setters' peak/discovery effects.
6. Compute each unlocked output rate **after consumption**, in output-array order, using then-current resources. Multiply by actual available duration. For discrete output: add to the stored phase, `whole = floor(progress)`, add positive whole units to the resource and produced statistics, subtract those units, and store the remainder. This is repeated rounded accumulation and floor, not rounding the total or a timer.
7. Continuous output is added and recorded immediately. Later outputs/generators observe preceding writes. Partial operation clears operating when duration is shorter than requested by more than the existing 1e-6 flag tolerance.
8. Apply Matter decay from the post-generator Matter balance. Cap loss at stock, record lost Matter and all decay/prestige counters, and add exactly that actual loss to Heat and Heat production.
9. Apply Heat leak using post-decay Heat, the original tick-start Heat and current parameters. Record actual Heat loss and weighted overflow/prestige statistics. Setters record intermediate lifetime/run peaks, so matching final stocks is insufficient.
10. Run generator then upgrade autobuyers; finish offline/interval bookkeeping. These buyers/cycles are exact-only in the new experiment.

In the early fixture, both Heat producers precede the discrete Matter producer. Matter emitted by Condensation cannot retroactively change that tick's earlier Heat outputs, but it changes next tick's Matter-held Heat multiplier. Molecular Agitation emits Heat before Ash; Condensation consumes Heat, emits integer Matter, then emits Ash. Ash writes therefore also change future suppression, and may affect later rate evaluations within a tick. Flows are not simultaneous.

### Actual formula and numerical contracts

| Component | Source formula/behavior |
|---|---|
| Base definitions | Atomic Friction: Heat 3/s/level. Molecular Agitation: Heat 45/s/level, Ash 0.1/s/level. Condensation: Heat input 1000/s/level, discrete Matter 0.25/s/level, Ash 0.3/s/level. These are source definitions, not constants duplicated in the candidate. |
| Production | Output base × level (when configured) × mode multiplier × applicable realm/EF multiplier × modifier products, in existing floating-point order. Matter uses realm Matter production; Heat uses realm Heat and Eternal Furnace. Transfer modes are special and not admitted here. |
| Thermic Mass | Actual automatic upgrade: log10 held Matter, raw `1 + 0.4 * realm_scaling * log10(M)` for M>1, otherwise 1; ordinary sensitivity makes the applied multiplier `1 + (raw-1)*sensitivity`. The implementation reads current held stock, not lifetime Matter production. |
| Ash suppression | Resource sqrt-inverse modifier uses configured resource threshold T: raw 1 below T, otherwise `1/(1 + scaled_strength*(sqrt(A)-sqrt(T)))`; sensitivity transforms it. Threshold/strength/realm/sensitivity come from actual definitions and upgrades. |
| Inputs | Base input × configured level/mode/input modifiers. Offline duration is `min(requested, stocks/rates)` over positive required inputs. Rates are not a simultaneous net-flow balance. |
| Matter decay | Zero at/below effective threshold T; otherwise `c*((M-T)/max(T,1))^p`, with existing upgrade-adjusted `c=max(20, scaling-2*coefficient_level)`, `p=max(2, exponent-0.02*exponent_level)`. Loss is capped by Matter. |
| Heat leak | Same thresholded power-law shape using Heat-specific parameters. Ordinary branch subtracts capped `rate*delta`. Stiff branch is selected when requested loss reaches 5% of max(excess,1), or start-above/end-below threshold; it uses 16 implicit substeps, safeguarded Newton (8 iterations) then bounded bisection (24) if needed. A large delta can select a different branch/substep map than repeated 0.1 updates. |
| Statistics | Produced/consumed/lost/peaks, offline statistics, overflow and Matter-decay/prestige counters are independent observable state. Heat overflow is weighted by `1.25^held_CF`. No counters are inferred solely from endpoint balances. |
| Floating point | GDScript float is binary64 here. Algebraically identical sums/multiplications need not preserve rounded phases/floors. The fixture's real resource formulas and helpers are reused; no replacement loss/suppression curves are fitted. |

Rates are physical continuous approximations evaluated at discrete ordered positions. Floors, resource discovery, upgrade/unlock actions, operation flags and cycle/purchase outcomes are discrete transitions. Environmental thresholds join continuous zero/nonzero rate branches but can change the numerical algorithm; they are not automatically safe macro boundaries.

## 2. Resource dependency map and classification

| Dependency | Class over a supported probe | Implication |
|---|---|---|
| Levels, selected modes, static upgrades, static sensitivities, realm configuration | A: constant only when purchases/unlocks/modes cannot change | Hoistable metadata/rate factors; still stored by the existing complete checkpoint |
| Heat from source outputs → available Condensation duration → Matter phase and Ash | B: evolving with C: partial-operation/floor transitions | Upstream production must be allocated in each correct prefix, not as a lump funded stock |
| Matter phase → floor → held Matter → log Heat modifier → next Heat output | B/C | Requires output timing or an equivalent prefix-sum representation; total integer count alone is insufficient |
| MA/Condensation Ash → sqrt suppression → Heat/input rates → subsequent Ash | B: nonlinear evolving | Even between integer Matter outputs, coefficients need not be constant |
| Matter decay → held Matter and added Heat → leak and next source production | B with threshold/cap regimes | The actual discrete reference map and recorded counters must be matched |
| Tick-start and post-generator/post-decay Heat → explicit/implicit leak choice | B/C | Endpoint ODE accuracy does not certify parity with the discrete map |
| Upgrade resource requirements, threshold/sensitivity upgrades, output/mode unlocks | C: discrete | Must prove absent, process at the correct tick, or reject; evaluating automatic upgrades only at macro start is insufficient |
| Previous fractional phase | B/C | Exact next output depends on it; tiny errors can change future floors |
| Elapsed-time dormancy, Mite hysteresis, active cycles, buyers, Essence and relic feedback | D: unsupported here | Existing exact fallback; no extra TimeManager/external-event adapter is introduced |

The inspector derives active IO and dynamic modifier resource references from definitions, levels and modes. It names no generator IDs. Only Heat-consuming and Heat/Matter/Ash-producing continuous flows are investigated; other active inputs/outputs, enabled automation, active/auto-run cycles, populated inventory/equipment/machine slots and instrumented simulation reject before speculative advancement. The aggregate kernel delegates controller updates and formulas to production helpers rather than duplicating generator-specific code. The idle certificate is the only acceptance proof, so incomplete analytic enclosures cannot admit a new active flow or hidden controller.

## 3. Three strategies evaluated before selection

| Strategy | Potential benefit | Why the current early system defeats its simple form | Decision |
|---|---|---|---|
| A: analytical accumulator advance | For constant real per-tick increment q, total whole outputs are floor(p0+n*q) and the remainder follows directly; O(1) phase work | q changes with allocated Heat, Ash and resource modifiers. Even constant-q real arithmetic does not reproduce repeated binary64 additions near floors without an additional representability/error proof. The binary64 witness demonstrates different integer counts. | Keep as a possible certified sub-operator, not a general early-game solution. No constant-rate assumption is imposed on reached fixtures. |
| B: ordered aggregate flows | Perform each generator's full-interval input/output once, then environmental flows once; O(generators+IO), not O(ticks*generators) | Generator-major grouping reorders cross-tick dependencies: later-produced Matter/Ash no longer feeds intermediate source production. Partial consumption, phase history, thresholds, peaks and decay/leak maps differ. | Implement and measure this minimal falsifiable candidate. Reject whenever the ordered recurrence lacks a proof. |
| C: controlled numerical/reference-map integration | A few probes or an integrator may approximate nonlinear stocks and cumulative rates with less work | Existing HEAT_MATTER_FEEDBACK research shows coarse ODE/reference-map estimates can disagree with the 0.1 map and peaks. With floors, matching coarse/fine endpoints can conceal output timing or phase errors. A resource/phase enclosure and prefix-event proof are needed in addition to an error estimator. | Do not implement another unproved integrator or relax the old guards. Existing simulator is benchmarked unchanged. |

Writing one tick's map as `F = E ∘ G_last ∘ ... ∘ G_first`, the candidate replaces `F^n` with full-interval generator maps followed by one E. These operations do not commute. The real tick-69 witness exhibits the missing cross-tick Matter→Heat feedback. This rejects the tested aggregation; it does not prove that interval arithmetic, specialized invariants or future piecewise composition cannot work.

## 4. Selected algorithm, transaction integration and admission

`ordered_flow_batch.gd` evaluates one generator-major aggregate pass of length n×0.1 for n=2,5,10. It uses actual start checks, available-duration calculation, consume_inputs, produce_outputs and environmental effects. Automatic upgrades run once at macro start, disabled managers retain their normal index initialization, and Simulation's offline/realm bookkeeping is reproduced. There is no loop over the skipped authoritative ticks in this candidate kernel. It preserves ordering within the macro pass, **not the required cross-tick equivalence**; that is precisely the tested failure.

Safe API:

1. Inspect scope without evaluating mutable production caches. Unsupported states use exact fallback without a speculative checkpoint.
2. `evaluate(n)` begins the existing optimized transaction, runs the aggregate and leaves it active for read-only research inspection.
3. `resolve()` commits only the proven idle/no-flow invariant. Every nonzero gameplay candidate has `ordered_recurrence_not_certified`, rolls back and verifies the complete graph through the existing transaction.
4. `advance(n)` resolves and then runs exact authoritative fallback when required. Failed restoration never falls through into exact simulation. Invalid/nested lifecycle requests fail.

No exact replay is used by runtime admission. Oracle replay/fingerprints are confined to validation and are outside measured runtime. Capture, candidate calculation, commit, rollback/verification, guard and exact fallback times are recorded separately. There is no second checkpoint. The public raw `apply_aggregate` kernel is for disposable research copies only; calling it directly is not an eligibility/admission API.

The runner deliberately measures failed speculation to answer the transaction-cost question; it is not enabled in the existing simulator. A deployed controller should refuse a known-unproved map before capture instead of repeatedly paying for doomed attempts. That would save failed-probe work but still provide **0% actual batching**, not a batching speedup.

## 5. Fixtures, correctness and drift methodology

Performance uses untouched reached early, mid and primary Forge fixtures from core_progression.json. `early_event` replays 68 authoritative ticks from the early save, reaching the tick immediately before its first real integer Matter output (tick 69). It grants no resources/levels/upgrades and disables no feedback. Both earlier Heat producers and their Ash/Matter modifiers remain enabled. Preparation is outside timed regions for all three methods.

Diagnostic unit fixtures additionally place Heat and Matter below/at/above actual effective loss thresholds, use zero Heat and stiff Heat, place Matter near the Thermic Mass join, set legitimate fractional phases below/at/above a wrapping boundary, and purchase an affordable upgrade through the actual API in a funded diagnostic realm. Those edited states are not reachability or performance evidence. Definitions/formulas are unchanged. Multiple source outputs are present in every active early case.

Each 2/5/10-tick trial captures the original complete fingerprint, evaluates raw macro results, advances an independent exact control, records numerical/statistical/phase/discrete/RNG errors, resolves rejection, compares immediately after rollback, runs exact fallback, then compares the complete supported state/event history again after 20 further exact ticks. Mid/Forge cases remain exact-only. Existing transaction, real Forge completion and RNG regression groups remain registered.

The existing balanced comparison is `1e-8 + 1e-4*abs(reference)` for numerical fields; this report's normalized errors use that denominator. No new tolerance is used for phases/discrete state/RNG. Full binary fingerprints remain required after safe fallback. A trial can be numerically close in final stocks and still fail phases, statistics or future output timing.

A separate disposable **unvalidated** trajectory applies 1,000 ten-tick macro passes without exact resets, sampling drift at 1/10/100/1000 batches. It is not counted as accepted coverage. Both trajectories then resume authoritative exact ticks to find the first differing Matter-output tick. An all-paused diagnostic control exercises 60 consecutive legitimately accepted idle transactions and verifies full parity after each; it is excluded from gameplay speedup/coverage tables.

## 6. Benchmark method and reproducibility

`ordered_flow_benchmark.gd` compares authoritative exact core ticks, the unchanged existing core_investigation_runner (balanced, short-exact bypass set to zero as in prior core benchmarks), and the guarded aggregate/fallback runner. It measures isolated 2/5/10-tick intervals and 600-tick/60-second runs for early, early_event, mid and Forge. Four repetitions alternate method order; the first is warmup and three comparable runs contribute medians/ranges. No other active validation/benchmark workload runs during final measurements.

The existing runner includes its normal TimeManager/guard/audit overhead; exact/new measurements use the synchronous core boundary. This distinction is reported rather than treated as a new algorithmic advantage. Setup and oracle comparisons are outside each timed run. All candidate, transaction, restoration/verification, guard and fallback work is inside it. Safe batched coverage is accepted ticks/total ticks. A raw fast computation that fails correctness is not a speedup.

Reproduce with `python tests/experimental/run_ordered_flow.py --godot /path/to/godot`. The driver fails on nonzero exit, ERROR or WARNING and applies an explicit process timeout. Run the full suite separately with `godot --headless --path . --script tests/run_regression_tests.gd`. Raw interval/drift data is in ordered_flow_validation.json; raw repeated timings/counters are in ordered_flow_benchmark_results.json. The final summary and source/log/environment hashes accompany this report.

## 7. Scalability and next direction

| Extension | Additional obligation |
|---|---|
| More resource consumers | Certify every ordered prefix's availability, allocation and partial-operation flags; endpoint net flows cannot prove them |
| Mite Colony | Multi-input Heat/Ash reserve, throttle hysteresis, suppressed input escalation, operating flags and dormancy context |
| Ash contamination | Already present in the reached early fixture and a cause of failure; changing sqrt suppression needs a coupled recurrence/enclosure, not a constant multiplier |
| Essence | Dynamic penalties/sensitivities/input modifiers and possible discrete Essence output; extend dependency/enclosure model |
| Forge | Resource-dependent speed, mode duration, completion/restart timing, resource resets/rewards/RNG and signals; no cycle support is implemented |
| Buyers | First affordability tick, cooldown/waiting caches, purchase ordering, cost deduction and modifier/threshold changes |
| Relics | Arbitrary rolled resource feedback, machine inventory/equipment effects and shared RNG; reviewed adapters plus event ordering |

The metadata/dependency approach and reuse of production helpers are general; the tested aggregate schedule is inadequate. No Atomic Friction/Molecular Agitation formula special case is introduced. A fresh per-generator closed form would not solve the shared resource-order problem.

Recommended next experiment: compile the authoritative ordered flow map into a small typed resource/phase packet with a reviewed write-set and shared immutable rate metadata. Hoist genuinely constant work while retaining the exact recurrence initially, and measure that as **tick-kernel optimization, not batching**. Use the current full transaction as the correctness oracle; do not silently omit mutation owners. Only then investigate accelerated piecewise composition/prefix enclosures that certify integer outputs, allocation, cumulative statistics and peaks. A local candidate packet could avoid live mutation on every failed probe, but integrating it requires an explicit contract rather than a second ad-hoc checkpoint.

For ten ticks, current complete transaction overhead alone is much larger than exact work. Even a cheap correct numerical kernel would need amortization over larger certified intervals or a cheaper reviewed speculative write boundary. Do not integrate this failed macro operator or relax adaptive guards. TimeManager/UI adapters are not needed for core-only packet research, but would be needed when actually advancing those external owners or publishing effects.

This validation uses official Linux x86_64 Godot 4.6.1 and the recorded host environment. It does not establish Windows Godot 4.7.2 compatibility. No clean editor parse is claimed, and game.gd:771 is left untouched.

## 8. Measured results and validation record

**91 regression groups passed, 0 failed**; all 90 pre-existing groups remain passing. Final standalone validation and benchmark runs contain no ERROR/WARNING messages. Existing transaction tests, both checkpoint implementations, real Forge completion and gameplay RNG outcomes remain covered. There are 45 active early/diagnostic candidate intervals, two mid/Forge exact-fallback cases, and one binary64 witness in the dedicated raw interval data. All safe rollback/fallback/resumed-state comparisons passed complete binary parity.

### Actual integer-output witness

| Ticks from reached prefix 68 | Exact integer Matter | Candidate integer Matter | Max phase error | Max statistics absolute error | Balanced normalized error |
|---|---:|---:|---:|---:|---:|
| 2 | 1 | 1 | 0.000292148525 | 2.68979792 | 2.9044 |
| 5 | 1 | 1 | 0.00116721452 | 10.7184884 | 11.09 |
| 10 | 1 | 1 | 0.00262106728 | 23.9640607 | 23.179 |

The exact output occurs on the first tick inside each interval. Both final Heat and Matter stocks match in these trials, and the whole output count is one in both methods. Nevertheless the phases and cumulative Heat production differ. For ten ticks the phase error is about 0.002621 and the largest statistical error about 23.964 Heat; normalized error 23.18 exceeds the existing target. No acceptance is inferred from matching stocks/counts.

The runtime binary64 witness uses q=2^-55 and p0=1-4q: two rounded additions retain a value below one (floor 0), whereas p0+2q rounds to one (floor 1). Godot JSON prints both decimal values as 1 in this case; the raw record therefore also retains floors and exact var_to_bytes encodings. Those bits, not the JSON decimal appearance, establish the distinction.

### Drift of the explicitly unvalidated trajectory

| Ten-tick macro passes | Max phase error | Heat error | Matter error | Largest normalized error |
|---|---:|---:|---:|---:|
| 1 | 9.04190852e-06 | 0 | 0 | 2.289355 |
| 10 | 0.000203421291 | 0 | 0 | 1.761153 |
| 100 | 0.0091904056 | 0 | 0 | 4.591289 |
| 1000 | 0.0240752993 | 0.112593317 | -0.0796642846 | 90015.6 |

After 1,000 unvalidated macro passes, resuming exact ticks first produces different Matter-output increments after **82 additional ticks**. Thus phase/resource deviations can alter later discrete output behavior even when earlier endpoint integer totals matched. This trajectory is never counted as an accepted simulation.

### Sixty-second end-to-end timings

Values are median milliseconds [min–max] of three post-warmup repetitions. Slowdown is candidate median divided by exact median. Coverage is accepted active-flow ticks / simulated ticks.

| Reached fixture | Batch ticks | Exact ms | Existing prototype ms | Guarded candidate ms | Slowdown | Batched coverage |
|---|---:|---:|---:|---:|---:|---:|
| early | 2 | 64.36 [63.48–70.72] | 78.03 [72.29–82.90] | 8902.41 [8485.62–9394.10] | 138.33× | 0% |
| early | 5 | 68.21 [59.60–71.55] | 70.00 [66.79–72.82] | 3350.85 [3268.23–3478.91] | 49.12× | 0% |
| early | 10 | 63.73 [62.13–69.57] | 70.52 [66.55–75.66] | 1759.81 [1755.18–1760.23] | 27.62× | 0% |
| early_event | 2 | 69.48 [69.46–70.17] | 81.93 [81.19–111.90] | 8392.93 [8120.22–9302.46] | 120.80× | 0% |
| early_event | 5 | 65.26 [63.99–66.35] | 70.29 [68.41–71.26] | 3871.24 [3513.81–3879.53] | 59.32× | 0% |
| early_event | 10 | 72.58 [62.28–73.60] | 71.09 [68.18–80.53] | 1977.69 [1883.12–2109.64] | 27.25× | 0% |
| mid | 2 | 61.47 [60.52–64.05] | 78.25 [67.40–81.02] | 62.86 [60.75–69.99] | 1.02× | 0% |
| mid | 5 | 56.05 [56.01–61.41] | 66.93 [61.90–77.25] | 63.94 [60.15–64.11] | 1.14× | 0% |
| mid | 10 | 60.15 [59.18–62.72] | 70.57 [62.00–70.57] | 65.56 [57.67–70.16] | 1.09× | 0% |
| forge_competing | 2 | 204.84 [200.60–210.07] | 210.39 [207.93–217.09] | 217.39 [204.38–225.11] | 1.06× | 0% |
| forge_competing | 5 | 216.28 [205.66–265.25] | 218.87 [200.77–249.44] | 206.24 [191.54–253.23] | 0.95× | 0% |
| forge_competing | 10 | 213.77 [206.31–216.44] | 234.29 [206.14–258.47] | 223.23 [222.83–234.24] | 1.04× | 0% |

The apparent small variations around 1× in mid/Forge are exact fallback plus guard overhead and measurement noise, not batching gains. All active-flow acceptance/commit counts are zero. Isolated interval costs (microseconds, three-sample medians) follow.

| Fixture | Ticks | Exact µs | Existing µs | Full candidate µs | Invalid raw kernel µs | Capture µs | Rollback + verification µs |
|---|---:|---:|---:|---:|---:|---:|---:|
| early | 2 | 475 | 857 | 28509 | 289 | 17238 | 10306 |
| early | 5 | 1067 | 1553 | 31235 | 390 | 17712 | 11777 |
| early | 10 | 1420 | 1984 | 28967 | 330 | 16177 | 10410 |
| early_event | 2 | 373 | 893 | 29106 | 327 | 17704 | 10414 |
| early_event | 5 | 690 | 1410 | 33751 | 403 | 18710 | 11611 |
| early_event | 10 | 1172 | 1953 | 32060 | 319 | 18500 | 10594 |
| mid | 2 | 347 | 969 | 532 | 0 | 0 | 0 |
| mid | 5 | 835 | 1062 | 807 | 0 | 0 | 0 |
| mid | 10 | 1365 | 2128 | 1379 | 0 | 0 | 0 |
| forge_competing | 2 | 1375 | 1693 | 1299 | 0 | 0 | 0 |
| forge_competing | 5 | 2491 | 3103 | 2247 | 0 | 0 | 0 |
| forge_competing | 10 | 3789 | 4542 | 3812 | 0 | 0 | 0 |

The invalid kernel performs one ordered flow pass rather than 2/5/10 exact updates, but this cheap computation does not satisfy correctness. Its time is already included in the full candidate column, as are guard, checkpoint, rollback verification and exact fallback. No oracle replay is required at runtime. The raw counters preserve all components, rejected/ineligible counts and exact ticks. Commit costs in these active runs are zero because nothing is committed.

The all-paused diagnostic control accepted 60 idle intervals with exact parity after every commit. Median commit release was 497 µs (capture 17198 µs). These are lifecycle/identity observations, not real gameplay batching gains.

### Existing-prototype tick-schedule caveat

The untouched pre-existing runner clips its last fallback delta to duration minus its accumulated reference elapsed. For non-dyadic 0.1, this can differ slightly from a loop of constant 0.1 calls. All 96 existing-runner measurements matched a separately replayed authoritative **schedule-matched full binary control**. Relative to constant-tick controls, 48 measurements had exact phase/discrete-fingerprint differences; their numerical errors remain visible in the raw records (typically roundoff scale). They are not relabeled as discrete parity. The new guarded path matched the constant-tick full binary control in every case. No baseline algorithm or tolerance was changed. The schedule replay is validation-only and excluded from runtime/admission for all methods.

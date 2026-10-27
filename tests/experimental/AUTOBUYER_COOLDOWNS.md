# Success-triggered autobuyer cooldowns

Base: `6fadba6607ade3a788e41aa8dc289bbe19ba094f`, branch `feature/cycle-auto-run`.

**Upgrade autobuyers now remain ready after failure and buy on the first eligible update.** The only production file changed is `Game/UpgradeAutomationManager.gd`. Generator behavior, base cooldown durations, purchasing priority, formulas, definitions, RNG, save format and TimeManager are unchanged. Experimental adaptive simulation remains isolated.

## Behavior and implementation

Previously `_attempt_purchase()` reset a failed upgrade scan to ten seconds, and `update()` additionally applied `fmod()` as if failures started periodic cooldowns. A player could regain resources just afterward and wait nearly another ten seconds. Generator buyers instead entered waiting at zero.

Both types now follow the same fundamental rules:

- Enabling starts the existing initial cooldown: generator base five seconds with its existing permanent reductions; upgrade ten seconds.
- Successful purchases start a new cooldown.
- Failure leaves cooldown exactly zero. A ready upgrade tree makes one live ordered scan on each subsequent simulation update.
- A successful waiting purchase starts a full fresh cooldown. Time spent waiting is not retrospectively spent on more purchases.
- A positive timer still carries overshoot through multiple successful purchases within a large update. The first failed scan ends that tree's work for the update, even with a huge remaining delta.
- Disabled/technology-locked/generator-locked trees do not purchase; locked timers retain their existing freeze behavior.

Zero cooldown represents waiting, so no extra runtime flag or save field is required. Tree ordering, registry ordering, exclusivity preferences, requirements, deductions and the generator-before-upgrade Simulation call order are unchanged. Generator cooldown upgrades and its resource-waiting cache are untouched.

No eligibility/affordability cache was introduced. A single cost is insufficient to describe an upgrade tree: resources, prior purchases, requirements and preferences can expose different candidates. A safe structural index would require a clear registry/definition invalidation contract. This small correction prioritizes live correctness; repeated registry scanning is a remaining performance cost, measured below.

Save/load still stores enabled/preferences only and starts a fresh initial cooldown for enabled unlocked buyers. Prestige reset still starts the existing initial cooldown. Waiting-at-save does **not** resume at zero after load; that was not the existing save contract and was not changed. Missing technology still prevents loading enabled automation.

Large deltas do not reproduce all intervening production, loss or first-affordable ticks. The manager preserves its positive-timer overshoot rules, but a ready waiting buyer retries once and cannot consume the whole waiting interval as cooldown time. Authoritative offline simulation remains on the original 0.1-second grid.

## Experimental waiting optimization

The previous prototype replayed the upgrade manager on every reference tick because failed attempts cycled the timer. The boundary now refuses to skip any relevant enabled/unlocked upgrade tree whose cooldown is not exactly zero. Initial and post-purchase countdowns therefore advance exactly until ready.

Under the existing conservative proof that no upgrade can become affordable or eligible, a ready buyer's zero timer and all other state stay unchanged. The default accepted-interval commit therefore skips the upgrade manager entirely. Disabled/locked positive timers also remain unchanged. Existing resource bounds, environmental Heat-from-Matter dependencies, unsupported modifiers, consumer/cycle and reward guards are retained.

A benchmark-only `--replay_waiting=true` control replays the actual corrected manager on the same accepted intervals. A focused regression requires identical binary state and every retained sample versus skipping. No event boundary is guessed, and no artificial retry delay is introduced.

Reference-grid scalar clock accumulation remains O(ticks). The existing `cooldown_replay_usec` counter measures that inclusive clock/optional-replay loop; a small nonzero value with zero replay ticks does not mean manager calls remain. This batch does not alter the clock arithmetic to remove that loop.

## Regression results

**86 tests passed, zero failures, no warnings or parser/runtime errors in the passing run.** All previous 80 tests are retained. Six new groups verify:

1. Initial cooldown, repeated failed scans at zero, first restored-affordability purchase, success cooldown, disable/re-enable, normal and offline manager paths.
2. Live generator/upgrade requirements, exclusive choices, frozen locked-tree timers and general-tree exclusions.
3. Registry priority, cross-tree priority despite reversed registration, same-resource competition, and generator-before-upgrade purchases/deductions on consecutive actual simulation ticks.
4. Million-second deltas: one failed scan, one ready waiting retry, multiple positive-timer successes, resource exhaustion and maxed termination; unchanged generator cooldown reductions/waiting behavior.
5. JSON save/load and prestige reset, enabled-state restoration, initial timers, actual post-load/reset purchases, technology gates and unchanged save keys.
6. Exact/adaptive timing/state parity, positive-timer fallback, zero manager replay and binary skip-versus-replay equivalence, including locked positive timers.

These use real `Simulation.buy_upgrade`/`buy_generator` calls and recorded purchase events, not mocked success flags or only timer assertions. Before/at/after purchase-boundary tests from the previous prototype also pass. The focused new behavior tests produce **23 expected assertion failures against the old manager**, without parser/runtime errors, demonstrating that they detect the original problem.

A benchmark harness conditional typed-array assignment failed during development and was corrected before accepted runs. The raw failure is retained. The unchanged upstream `game.gd:771` indentation defect still prevents claiming a clean full-editor launch; standalone regression/benchmark logs are clean. No unrelated production repair was attempted.

## Performance method

Same host, Linux Godot 4.6.1 headless, seed 123456, controlled `late_both` fixture, unchanged formulas/tolerances. This is not Windows 4.7.2 or a real player save. The fixture isolates Heat/Matter feedback plus enabled but resource/level-blocked automation; reachability with all prior unlocked consumers retained is not established.

Primary results use three interleaved **serial** old/new pairs per duration with 65-second per-process bounds. Timers include trial checks and audit capture. Profiling is off. Dense accuracy runs are separate. Old harness runs also include its previous blanket-fallback control; the new harness can omit that redundant control with `--previous=false`. Only the event and reference phase timers below are compared. No process overlapped these primary runs.

Times are medians [min–max] in seconds. “Old/new gain” is the median of paired old-adaptive/new-adaptive ratios.

| Duration | Old exact | Corrected exact | Old adaptive | Corrected adaptive, skip | Old/new adaptive gain |
| 1 h | 2.856 [2.790–2.939] | 4.644 [4.237–4.733] | 1.507 [1.350–1.593] | 1.279 [1.274–1.308] | 1.18 [1.03–1.25]× |
| 4 h | 11.197 [10.942–11.984] | 18.602 [17.355–18.881] | 3.435 [3.284–3.867] | 3.183 [3.152–3.339] | 1.09 [0.98–1.22]× |

The measured improvement over the previous adaptive implementation is modest, with overlapping ranges and one four-hour pair slightly unfavorable. **Do not treat the larger ratio against corrected exact simulation as a larger optimization win:** the corrected exact manager now performs live failed scans every tick, whereas the old behavior throttled them for ten seconds. This intentional query increase explains the measured exact-waiting overhead; production exact simulation may therefore be slower in upgrade-heavy waiting states. No artificial polling interval was added to conceal that cost.

| Fixture/duration | Evaluations | Accepted / rejected | Exact fallback ticks | Adaptive coverage | Upgrade manager replay ticks | Skipped upgrade entry checks |
| Old 1 h | 3100 | 423 / 50 | 370 | 98.972% | 35630 | 0 |
| Corrected 1 h | 3050 | 398 / 50 | 420 | 98.833% | 0 | 35580 |
| Old 4 h | 6842 | 962 / 98 | 600 | 99.583% | 143400 | 0 |
| Corrected 4 h | 6842 | 962 / 98 | 600 | 99.583% | 0 | 143400 |

Under the **same corrected rules**, forcing ready-wait manager replay takes **3.230 [3.194–3.384] seconds** for one hour (three runs), versus 1.279 [1.274–1.308] with skipping. This isolates why retaining the old replay architecture would be expensive after the behavior correction. The four-hour replay control took **10.304 seconds** in one run; this single observation is not a repeated speedup estimate. Accepted/rejected/fallback counts match the corresponding skip configuration, and all comparisons pass.

The four-hour default eliminates 143,400 upgrade manager invocations during adaptive intervals. Remaining exact fallbacks still evaluate automation normally. This restricted result is not a full-game acceleration: consumers, active cycles, growing-resource affordability, dynamic cost dependencies and prestige exposure retain exact fallback. No 12-/24-hour benchmarks or six-minute catch-up claim are made.

## Numerical and progression validation

Comparisons use the **corrected authoritative simulator**. Earlier purchases after resource restoration are the intentional behavior change, so old and new active-play histories are not expected to match one another. In the restricted waiting benchmark both versions make zero purchases; old cycling cooldowns versus new zero timers are also an intentional cross-version state difference.

Dense oracle runs audit every accepted adaptive endpoint on the reference grid, including production/consumption/loss, resource peaks, current-run/lifetime/offline totals, overflow, decay and reward inputs. No tolerances were relaxed: relative target 1e-4, absolute 1e-8, with the existing distributed estimator.

| Dense check | Max resource abs / relative fraction | Max statistics abs / relative fraction | Final resource abs / relative fraction | Final statistics abs / relative fraction |
| 1 h | 6.956553e-05 / 4.848289e-07 | 0.002145252 / 1.372877e-06 | 1.529218e-05 / 1.518231e-07 | 0.0004063519 / 4.158151e-07 |
| 4 h | 2.276979e-05 / 1.805374e-07 | 0.001128367 / 5.039405e-07 | 1.220879e-06 / 1.217378e-08 | 0.000876714 / 3.280787e-08 |

All completed accepted comparisons preserve discrete state, purchase order/ticks/costs under corrected rules, unlocks, RNG and integer prestige reward parity. Waiting fixtures currently earn zero integer reward; future nonzero rewards from approximate historical statistics remain outside this restricted validation. Existing reward-boundary and critical-crafting regressions remain exact. Reported numerical maxima are sampled, not certified continuous-time error bounds.

## Files and remaining limitations

- `Game/UpgradeAutomationManager.gd`: success-triggered cooldown and one ready retry per update.
- `tests/autobuyer_cooldown_tests.gd` and `.gd.uid`: focused event-based behavior tests.
- `tests/run_regression_tests.gd`: six registrations.
- `tests/experimental/autobuyer_boundary.gd`, `autobuyer_offline.gd`: zero-timer guard, skipped calls and optional replay control.
- `tests/experimental/autobuyer_tests.gd`, `autobuyer_benchmark.gd`: replay equivalence, control/previous-harness options.
- `tests/experimental/AUTOBUYER_EVENTS.md`: mark prior semantics/results historical and link this follow-up.
- This report and `autobuyer_cooldown_results.json`: commands, all observed outcomes, source identity and final test log.

The next performance opportunity is a generalized structural upgrade-tree index with an explicit invalidation contract, while still evaluating all live eligibility on each ready update. This was not added speculatively. Growing-resource purchase boundaries, consumers and cycles remain separate experiments. No production adaptive integration or player setting is enabled.

## Reproduce

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output hour.log --timeout 65 -- --scenario=late_both --duration=3600 --previous=false --repeats=3
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output four.log --timeout 65 -- --scenario=late_both --duration=14400 --previous=false
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output control.log --timeout 65 -- --scenario=late_both --duration=3600 --previous=false --replay_waiting=true
python tests/experimental/run_autobuyer.py --godot GODOT --project . --output dense.log --timeout 65 -- --scenario=late_both --duration=3600 --previous=false --dense=true
```

Use a longer explicit timeout on slower machines. The baseline measurements used immutable copies of `6fadba6` rather than switching or creating branches. The existing raw historical results are preserved unchanged.

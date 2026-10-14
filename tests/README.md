# Regression tests

These are lightweight, headless tests for core gameplay rules. They create fresh
in-memory game states and replace the gameplay logger with an in-memory fake,
so test purchases do not write into the normal player gameplay log.

## Run

From the repository root with Godot 4.7 available on your PATH:

```bash
godot --headless --path . --script res://tests/run_regression_tests.gd
```

On Windows, use `godot.exe` if that is the executable name on your system.

The process exits with code 0 when every test passes and code 1 if one or more
tests fail. Each test prints a `[PASS]` or `[FAIL]` line; failed expectations
also appear as errors in the Godot output.

## Current coverage

- Core resources and generators register during GameState initialization.
- Heat leakage and Matter decay are zero at their thresholds and positive above.
- Generator purchases reject insufficient resources without changing state.
- Successful generator purchases deduct the expected cost, add one level, and
  emit the expected gameplay-log event.
- Atomic Friction production increases Heat and updates interval statistics.
- Interval production/consumption/loss counters are returned and cleared.
- Realm reset clears current resource balances, clears interval counters, and
  advances the realm-run index.

These tests focus on stable rules rather than exact balance numbers. They are a
starting point, not a complete test suite; add tests when a bug is fixed or a
new mechanic becomes important.

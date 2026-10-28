# Recovery checkpoint

Branch: `feature/cycle-auto-run`, starting HEAD `7959d56c83472b4a1dbc3950463f0b6ed5998044`.

Recovered on 2026-10-28: ignored, uncommitted `core_*.gd`, `run_core.py`, fixtures, replay results and diagnostic measurements. No previous core-gameplay commit was pushed. Original unrelated untracked Ogg/UID files are preserved.

Completed and retained:
- Real reference-tick progression from a fresh GameState: 1,217,001 ticks, 5,646 legal actions, eight earned prestiges.
- Independent ledger replay verified early, mid and Forge snapshots, all recorded transactions and RNG; first completion witness retained.
- 25 successful diagnostic/ablation cases. Recovered source hashes match current fixture, runner, benchmark and blocker code.
- Four-fixture 600-second activity survey; no throughput claim is made from diagnostic timings.
- Conditional cycle speed-envelope analysis, never enabled as an adaptive execution certificate.

Unfinished at recovery (subsequently completed):
- Run and correct unfinished dense endpoint/real-event boundary tests; register with the full regression suite.
- Add the missing activity measurement for `forge_competing` without repeating the recovered four cases.
- Run clean serial runtime comparisons and supported-scenario regression controls.
- Finish the technical report, full validation, commit and publish on the existing branch.

Completion update, 2026-10-28:
- Focused tests passed at 6,000 dense endpoints and three real completion windows.
- Full suite: 88 groups passed, no passing-run warnings/errors.
- Missing Forge competition activity measurement and clean serial comparisons completed.
- Core coverage remains zero; delivered the measured architectural alternative without relaxing guards.
- Detailed results, limitations and next engineering action: `CORE_GAMEPLAY.md`.
- All source/data/report work is complete; the delivery commit is recorded in branch history and the user-facing completion response.

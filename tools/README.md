# Gameplay log analysis

This offline developer tool analyzes \`user://gameplay_log.jsonl\`. It is not imported by Godot and adds no runtime dependency.

## 1. Copy the log out of Godot

In Godot, use **Project → Open User Data Folder** (wording may vary by editor version) and copy \`gameplay_log.jsonl\` to a convenient location. The game stores it in its \`user://\` data directory, not in the repository by default.

## 2. Generate a report

Requires Python 3.10 or newer. No third-party packages are required.

From the repository root:

\`\`\`bash
python tools/analyze_gameplay_log.py "C:/path/to/gameplay_log.jsonl"
\`\`\`

Choose a different output folder if desired:

\`\`\`bash
python tools/analyze_gameplay_log.py "C:/path/to/gameplay_log.jsonl" --output "C:/temp/gameplay-report"
\`\`\`

Open \`gameplay-log-report/report.html\` in a browser (or the folder passed to \`--output\`). The report is self-contained HTML with inline SVG charts.

## Report contents

- Resource balances over time from economy snapshots.
- Interval production, consumption, and losses, with separate charts per resource.
- Heat leak and Matter decay rates.
- Event timeline, event counts, and generator purchase history.
- Unusually large changes between successive logged purchase costs for the same generator.
- CSV exports: \`snapshots.csv\`, \`events.csv\`, \`generator_purchases.csv\`, and \`cost_anomalies.csv\`.

A cost anomaly means a logged cost changed by more than 2× or dropped below half the previous cost. This is a review prompt, not a diagnosis: upgrades, prestige resets, cost-resource changes, or incomplete logs can explain it.

The script only reads the supplied log and writes to the selected output directory. It does not change saves or upload log data.

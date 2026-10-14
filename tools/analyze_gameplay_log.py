#!/usr/bin/env python3
"""Build a local HTML/CSV report from the game's gameplay_log.jsonl."""
import argparse
import csv
import html
import json
import math
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


def num(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    return value if math.isfinite(value) else None


def read_log(path):
    events, warnings = [], []
    with path.open(encoding="utf-8-sig") as source:
        for line_no, line in enumerate(source, 1):
            if not line.strip():
                continue
            try:
                event = json.loads(line)
                if not isinstance(event, dict):
                    raise ValueError("entry is not an object")
                if not isinstance(event.get("details"), dict):
                    event["details"] = {}
                events.append(event)
            except (json.JSONDecodeError, ValueError) as exc:
                warnings.append(f"Line {line_no}: {exc}; skipped")
    events.sort(key=lambda e: (num(e.get("unix_time")) if num(e.get("unix_time")) is not None else float("inf"), str(e.get("timestamp", ""))))
    return events, warnings


def d(event):
    return event.get("details", {}) if isinstance(event.get("details"), dict) else {}


def when(event):
    return str(event.get("timestamp") or event.get("unix_time") or "Unknown time")


def fmt(value):
    n = num(value)
    if n is not None:
        return f"{n:,.4f}".rstrip("0").rstrip(".")
    if value is None:
        return "—"
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return str(value)


def write_csv(path, rows, fields=None):
    if fields is None:
        fields = sorted({key for row in rows for key in row})
    with path.open("w", newline="", encoding="utf-8-sig") as target:
        writer = csv.DictWriter(target, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def chart(title, series, width=900, height=280):
    points = [p for _, values in series for p in values if math.isfinite(p[0]) and math.isfinite(p[1])]
    if not points:
        return f'<section class="chart"><h3>{html.escape(title)}</h3><p class="muted">No data available.</p></section>'
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
    if xmin == xmax: xmax = xmin + 1
    if ymin == ymax: ymax = ymin + max(abs(ymin) * .1, 1)
    if ymin >= 0: ymin = 0
    left, right, top, bottom = 75, 18, 30, 38
    pw, ph = width - left - right, height - top - bottom
    px = lambda x: left + (x - xmin) / (xmax - xmin) * pw
    py = lambda y: top + (ymax - y) / (ymax - ymin) * ph
    out = [f'<section class="chart"><h3>{html.escape(title)}</h3><svg viewBox="0 0 {width} {height}" role="img" aria-label="{html.escape(title)}">']
    for i in range(5):
        y = ymin + (ymax - ymin) * i / 4
        out.append(f'<line x1="{left}" y1="{py(y):.1f}" x2="{width-right}" y2="{py(y):.1f}" class="grid"/><text x="{left-8}" y="{py(y)+4:.1f}" text-anchor="end" class="tick">{html.escape(fmt(y))}</text>')
        x = xmin + (xmax - xmin) * i / 4
        label = datetime.fromtimestamp(x).strftime("%H:%M:%S") if x > 0 else ""
        out.append(f'<text x="{px(x):.1f}" y="{height-12}" text-anchor="middle" class="tick">{label}</text>')
    colors = ["#e76f51", "#2a9d8f", "#7b61a8", "#e9c46a", "#457b9d", "#f4a261"]
    for index, (label, values) in enumerate(series):
        values = [(x, y) for x, y in values if math.isfinite(x) and math.isfinite(y)]
        if not values: continue
        path = " ".join(("M" if i == 0 else "L") + f"{px(x):.1f},{py(y):.1f}" for i, (x, y) in enumerate(values))
        color = colors[index % len(colors)]
        lx, ly = left + 8 + (index % 3) * 265, 15 + (index // 3) * 14
        out.append(f'<path d="{path}" fill="none" stroke="{color}" stroke-width="2.5"/><line x1="{lx}" y1="{ly-4}" x2="{lx+18}" y2="{ly-4}" stroke="{color}" stroke-width="3"/><text x="{lx+24}" y="{ly}" class="legend">{html.escape(label)}</text>')
    return "".join(out) + "</svg></section>"


def table(headers, rows, limit=100):
    if not rows: return '<p class="muted">No matching entries in this log.</p>'
    head = "".join(f"<th>{html.escape(str(h))}</th>" for h in headers)
    body = "".join("<tr>" + "".join(f"<td>{html.escape(fmt(v), quote=True)}</td>" for v in row) + "</tr>" for row in rows[:limit])
    note = f'<p class="muted">Showing {min(limit, len(rows))} of {len(rows)} rows.</p>' if len(rows) > limit else ""
    return f'<div class="table-wrap"><table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table></div>{note}'


def build_report(events, warnings, source_name, output):
    output.mkdir(parents=True, exist_ok=True)
    snapshots = [e for e in events if e.get("event") == "economy_snapshot"]
    balances, flows = defaultdict(list), defaultdict(list)
    leak, decay, snapshot_rows = [], [], []
    for event in snapshots:
        detail = d(event)
        timestamp = num(event.get("unix_time"))
        if timestamp is None:
            try: timestamp = datetime.fromisoformat(str(event.get("timestamp"))).timestamp()
            except ValueError: timestamp = None
        row = {"timestamp": when(event), "unix_time": timestamp}
        for key in ("realm_run_index", "realm_layout_id", "interval_seconds", "heat_leak_per_second", "matter_decay_per_second", "total_overflow_this_prestige", "crystallized_flame"):
            row[key] = detail.get(key, "")
        for resource, value in detail.get("resources", {}).items() if isinstance(detail.get("resources"), dict) else []:
            amount = value.get("amount") if isinstance(value, dict) else value
            row[f"balance_{resource}"] = amount
            if timestamp is not None and num(amount) is not None: balances[resource].append((timestamp, float(amount)))
        stats = detail.get("interval_statistics", {})
        for flow in ("produced", "consumed", "lost"):
            amounts = stats.get(flow, {}) if isinstance(stats, dict) else {}
            if isinstance(amounts, dict):
                for resource, amount in amounts.items():
                    row[f"{flow}_{resource}"] = amount
                    if timestamp is not None and num(amount) is not None: flows[f"{flow}_{resource}"].append((timestamp, float(amount)))
        for key, target in (("heat_leak_per_second", leak), ("matter_decay_per_second", decay)):
            if timestamp is not None and num(detail.get(key)) is not None: target.append((timestamp, float(detail[key])))
        snapshot_rows.append(row)
    write_csv(output / "snapshots.csv", snapshot_rows)

    event_rows, purchase_rows, anomalies = [], [], []
    previous_cost = {}
    for event in events:
        detail = d(event)
        event_rows.append({"timestamp": when(event), "unix_time": event.get("unix_time", ""), "category": event.get("category", ""), "event": event.get("event", ""), "source": event.get("source", ""), "details_json": json.dumps(detail, ensure_ascii=False, sort_keys=True)})
        event_name = str(event.get("event", "")).lower()
        if "generator" not in event_name or not any(word in event_name for word in ("level_purchased", "level_buy", "purchased", "purchase")): continue
        gid = str(detail.get("generator_id") or detail.get("id") or detail.get("generator") or "unknown_generator")
        cost = num(detail.get("cost"))
        if cost is None: cost = num(detail.get("purchase_cost"))
        row = {"timestamp": when(event), "unix_time": event.get("unix_time", ""), "generator_id": gid, "generator_name": detail.get("generator_name") or detail.get("name") or gid, "old_level": detail.get("old_level", ""), "new_level": detail.get("new_level", detail.get("level", "")), "cost": cost if cost is not None else "", "cost_resource": detail.get("cost_resource", detail.get("resource_id", "")), "source": event.get("source", ""), "event": event.get("event", "")}
        purchase_rows.append(row)
        if cost is not None and cost > 0:
            if gid in previous_cost:
                old_cost, old_event = previous_cost[gid]
                ratio = cost / old_cost
                if ratio < .5 or ratio > 2:
                    anomalies.append({"timestamp": when(event), "generator_id": gid, "previous_timestamp": when(old_event), "previous_cost": old_cost, "current_cost": cost, "cost_ratio": ratio, "change_percent": (ratio - 1) * 100, "note": "Review for an upgrade, reset, cost-resource change, or incomplete log."})
            previous_cost[gid] = (cost, event)
    write_csv(output / "events.csv", event_rows, ["timestamp", "unix_time", "category", "event", "source", "details_json"])
    write_csv(output / "generator_purchases.csv", purchase_rows)
    write_csv(output / "cost_anomalies.csv", anomalies)

    counts = Counter(str(e.get("event", "unknown")) for e in events)
    charts = [chart("Resource balances", [(k, v) for k, v in balances.items() if k.lower() in {"heat", "matter", "ash", "essence", "nexum", "crystalized_flame", "crystallized_flame"}])]
    for resource in ("heat", "matter", "ash", "essence", "nexum", "crystalized_flame", "crystallized_flame"):
        series = [(flow.title() + " " + resource, flows[f"{flow}_{resource}"]) for flow in ("produced", "consumed", "lost") if f"{flow}_{resource}" in flows]
        if series: charts.append(chart(f"Interval production / consumption / losses — {resource}", series))
    charts.extend([chart("Heat leak per second", [("Heat leak / s", leak)]), chart("Matter decay per second", [("Matter decay / s", decay)])])
    purchase_table = [[r["timestamp"], r["generator_name"], r["old_level"], r["new_level"], r["cost"], r["cost_resource"], r["source"]] for r in purchase_rows]
    anomaly_table = [[r["timestamp"], r["generator_id"], r["previous_cost"], r["current_cost"], f'{r["change_percent"]:+.1f}%', r["note"]] for r in anomalies]
    timeline = [[when(e), e.get("event", ""), e.get("source", ""), d(e).get("generator_name") or d(e).get("upgrade_name") or d(e).get("generator_id") or d(e).get("upgrade_id") or d(e).get("reason") or ""] for e in events if e.get("event") != "economy_snapshot"]
    warning_list = "".join(f"<li>{html.escape(w)}</li>" for w in warnings) or "<li>None</li>"
    metrics = [("Events", len(events)), ("Economy snapshots", len(snapshots)), ("Generator purchases", len(purchase_rows)), ("Cost changes to review", len(anomalies))]
    cards = "".join(f"<div class=metric><span>{label}</span><strong>{value:,}</strong></div>" for label, value in metrics)
    summary = f'<div class="cards">{cards}</div><p><b>Log period:</b> {html.escape(when(events[0]) if events else "—")} → {html.escape(when(events[-1]) if events else "—")}</p>'
    doc = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Gameplay Log Analysis</title><style>
:root{{--bg:#10151c;--panel:#1a222d;--line:#354252;--text:#e8edf2;--muted:#aab7c5}}*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--text);font:15px/1.5 system-ui,sans-serif}}main{{max-width:1200px;margin:auto;padding:28px 22px 60px}}h2{{margin-top:36px;border-bottom:1px solid var(--line);padding-bottom:8px}}h3{{margin:0 0 8px;font-size:1.05rem}}p,.muted{{color:var(--muted)}}.cards{{display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:12px;margin:24px 0}}.metric,.chart{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px;min-width:0}}.metric span{{display:block;color:var(--muted);font-size:.86rem}}.metric strong{{font-size:1.6rem}}.chart{{margin:16px 0;overflow:hidden}}svg{{width:100%;height:auto;display:block}}.grid{{stroke:var(--line);stroke-width:1}}.tick,.legend{{fill:var(--muted);font-size:10px}}.table-wrap{{overflow:auto;border:1px solid var(--line);border-radius:8px}}table{{border-collapse:collapse;width:100%;font-size:.9rem}}th,td{{padding:9px 11px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}}th{{background:var(--panel)}}td{{overflow-wrap:anywhere}}.downloads{{display:flex;flex-wrap:wrap;gap:12px}}a{{color:#86c8ff}}.downloads a{{padding:9px 12px;border:1px solid var(--line);border-radius:8px;text-decoration:none;background:var(--panel)}}@media(max-width:600px){{main{{padding:18px 12px}}}}</style></head><body><main><h1>Gameplay Log Analysis</h1><p>Source: <code>{html.escape(source_name)}</code>. Cost anomalies are investigation hints, not proof of bugs.</p>{summary}<h2>Economy charts</h2>{''.join(charts)}<h2>CSV exports</h2><div class="downloads"><a href="snapshots.csv">Snapshots</a><a href="events.csv">All events</a><a href="generator_purchases.csv">Generator purchases</a><a href="cost_anomalies.csv">Cost anomalies</a></div><h2>Generator cost changes to review</h2>{table(["Timestamp","Generator","Previous cost","Current cost","Change","Note"], anomaly_table)}<h2>Generator purchase history</h2>{table(["Timestamp","Generator","Old level","New level","Cost","Resource","Source"], purchase_table)}<h2>Event timeline (routine snapshots excluded)</h2>{table(["Timestamp","Event","Source","Related item / context"], timeline)}<h2>Event type counts</h2>{table(["Event","Count"], counts.most_common())}<h2>Parsing warnings</h2><ul>{warning_list}</ul><p class="muted">Generated locally; no log data is uploaded or transmitted.</p></main></body></html>'''
    (output / "report.html").write_text(doc, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="Path to gameplay_log.jsonl")
    parser.add_argument("-o", "--output", type=Path, default=Path("gameplay-log-report"), help="Output folder (default: gameplay-log-report)")
    args = parser.parse_args()
    if not args.log.is_file(): parser.error(f"log file does not exist: {args.log}")
    try:
        events, warnings = read_log(args.log)
        build_report(events, warnings, args.log.name, args.output)
    except OSError as exc:
        print(f"File error: {exc}", file=sys.stderr)
        return 1
    print(f"Read {len(events)} events from {args.log}")
    print(f"Report: {(args.output / 'report.html').resolve()}")
    print(f"CSV files: {args.output.resolve()}")
    if warnings: print(f"Skipped {len(warnings)} malformed line(s); see report.html")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Dev-only: summarizes an exported save for a playtest (Story 5.4).

The export is the file the main menu's Ctrl+Shift+E offers (zts-save-YYYYMMDD.json, the same JSON as
save.json). Standard library only, nothing to install. Run:
    python tools/playtest/summarize_save.py <zts-save-YYYYMMDD.json> [--json]
    python tools/playtest/summarize_save.py --selftest
It reads the file and prints; it never writes a file and never touches the network (NFR12).
tools/ is export-excluded, so this never ships.
"""
import argparse
import contextlib
import io
import json
import math
import statistics
import sys
from datetime import datetime

DASH = "—"
TOP_KEYS = 5
ACCURACY_TARGET = 85  # GDD Pillar 2: median accuracy >= 85 %.


class Summary:
    def __init__(self) -> None:
        self.warnings: list[str] = []

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)


def as_num(value):
    """A JSON number as int when whole (Godot sometimes writes 9 as 9.0), else float; None if not a finite number."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def num_field(record: dict, key: str, s: Summary, where: str):
    """as_num of record[key]; a present but non-numeric value gets a one-line warning (absent is just a dash)."""
    value = record.get(key)
    number = as_num(value)
    if number is None and value is not None:
        s.warn(f"{where}.{key} is not a finite number; shown as {DASH}")
    return number


def local_time(ts, s: Summary, where: str):
    if ts is None:
        return None
    try:
        return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
    except (OverflowError, OSError, ValueError):
        s.warn(f"{where}.timestamp {ts!r} is out of range; time shown as {DASH}")
        return None


def get_dict(parent, key: str, s: Summary, where: str) -> dict:
    value = parent.get(key) if isinstance(parent, dict) else None
    if value is None:
        return {}
    if not isinstance(value, dict):
        s.warn(f"{where}.{key} is not an object; skipped")
        return {}
    return value


def pick_profile(data, s: Summary) -> tuple[str, dict]:
    """Like SaveSchema.fill_defaults: the active profile, else "p1", else the first one."""
    profiles = get_dict(data, "profiles", s, "save")
    active = data.get("active_profile") if isinstance(data, dict) else None
    for pid in (active, "p1", *profiles.keys()):
        if isinstance(pid, str) and isinstance(profiles.get(pid), dict):
            if pid != active:
                s.warn(f"active_profile {active!r} not found; using {pid!r}")
            return pid, profiles[pid]
    s.warn("no profile found")
    return DASH, {}


def merge_per_key(runs: list[dict], s: Summary) -> list[dict]:
    """per_key is char -> [attempts, errors, {typed: count}]. Malformed entries count as absent."""
    totals: dict[str, list] = {}
    for i, run in enumerate(runs, 1):
        per_key = run.get("per_key")
        if per_key is None:
            continue
        if not isinstance(per_key, dict):
            s.warn(f"run {i}: per_key is not an object; skipped")
            continue
        for char, entry in per_key.items():
            if not (isinstance(entry, list) and len(entry) >= 2):
                s.warn(f"run {i}: per_key[{char!r}] malformed; skipped")
                continue
            attempts, errors = as_num(entry[0]), as_num(entry[1])
            if attempts is None or errors is None:
                s.warn(f"run {i}: per_key[{char!r}] counts not numbers; skipped")
                continue
            acc = totals.setdefault(char, [0, 0, {}])
            acc[0] += attempts
            acc[1] += errors
            typed = entry[2] if len(entry) > 2 and isinstance(entry[2], dict) else {}
            for wrong, count in typed.items():
                count = as_num(count)
                if count is not None:
                    acc[2][wrong] = acc[2].get(wrong, 0) + count
    rows = []
    for char, (attempts, errors, typed) in totals.items():
        if errors <= 0:
            continue
        error_pct = round(100 * errors / attempts, 1) if attempts else None
        wrong = max(typed.items(), key=lambda kv: (kv[1], kv[0]))[0] if typed else None
        rows.append({"key": char, "attempts": attempts, "errors": errors, "error_pct": error_pct,
                "most_common_wrong": wrong})
    rows.sort(key=lambda r: (-r["errors"], -(r["error_pct"] or 0), r["key"]))
    return rows[:TOP_KEYS]


def summarize(data, s: Summary) -> dict:
    if not isinstance(data, dict):
        s.warn("save is not a JSON object")
        data = {}
    profile_id, profile = pick_profile(data, s)
    raw_runs = profile.get("run_history", [])
    if not isinstance(raw_runs, list):
        s.warn("run_history is not a list; skipped")
        raw_runs = []
    runs = []
    for i, run in enumerate(raw_runs, 1):
        if isinstance(run, dict):
            runs.append(run)
        else:
            s.warn(f"run_history[{i}] is not an object; skipped")

    rows = []
    prev_ts = None
    for i, run in enumerate(runs, 1):
        where = f"run_history[{i}]"
        ts = num_field(run, "timestamp", s, where)
        gap = round((ts - prev_ts) / 60, 1) if ts is not None and prev_ts is not None else None
        if ts is not None:
            prev_ts = ts
        level = run.get("level_id")
        end = run.get("end_reason")
        rows.append({
            "n": i,
            "local_time": local_time(ts, s, where),
            "gap_min": gap,
            "level_id": level if isinstance(level, str) else None,
            "duration_s": num_field(run, "duration_s", s, where),
            "keys_typed": num_field(run, "keys_typed", s, where),
            "errors": num_field(run, "errors", s, where),
            "accuracy": num_field(run, "accuracy", s, where),
            "wpm": num_field(run, "wpm", s, where),
            "brains": num_field(run, "brains", s, where),
            "end_reason": end if isinstance(end, str) else None,
        })

    def median_of(field: str):
        values = [r[field] for r in rows if r[field] is not None]
        return as_num(round(statistics.median(values), 1)) if values else None

    def count_of(field: str) -> int:
        return sum(1 for r in rows if r[field] is not None)

    keys = [r["keys_typed"] for r in rows if r["keys_typed"] is not None]
    equipped = get_dict(profile, "equipped", s, "profile")
    flags = get_dict(profile, "flags", s, "profile")
    settings = get_dict(profile, "settings", s, "profile")
    best = get_dict(profile, "best_wpm", s, "profile")
    owned = profile.get("owned_items")
    if owned is not None and not isinstance(owned, list):
        s.warn("owned_items is not a list; skipped")
        owned = None

    def flag(d: dict, key: str):
        return d.get(key) if isinstance(d.get(key), bool) else None

    def text(d: dict, key: str):
        return d.get(key) if isinstance(d.get(key), str) else None

    return {
        "schema_version": as_num(data.get("schema_version")),
        "profile": profile_id,
        "runs": rows,
        "totals": {
            "finished_runs": len(rows),
            "median_accuracy": median_of("accuracy"),
            "accuracy_runs": count_of("accuracy"),
            "accuracy_target": ACCURACY_TARGET,
            "median_wpm": median_of("wpm"),
            "wpm_runs": count_of("wpm"),
            "total_keys": sum(keys) if keys else None,
            "best_wpm": {k: num_field(best, k, s, "profile.best_wpm") for k in best},
            "brains": num_field(profile, "brains", s, "profile"),
            "owned_items": [x for x in owned if isinstance(x, str)] if owned is not None else None,
            "equipped": {"hat": text(equipped, "hat"), "pet": text(equipped, "pet")},
            "flags": {k: flag(flags, k) for k in ("welcome_bonus_claimed", "tutorial_seen")},
            "settings": {k: flag(settings, k) for k in ("music_on", "sound_on")},
        },
        "top_missed_keys": merge_per_key(runs, s),
        "warnings": s.warnings,
    }


def show(value, suffix: str = "") -> str:
    if value is None:
        return DASH
    if isinstance(value, bool):
        return "yes" if value else "no"
    return f"{value}{suffix}"


def mmss(seconds) -> str:
    return DASH if seconds is None or seconds < 0 else f"{int(seconds) // 60}:{int(seconds) % 60:02d}"


def print_text(result: dict, path: str) -> None:
    print(f"Save summary: {path}")
    print(f"schema_version {show(result['schema_version'])} · profile {result['profile']}"
            " · times are local to this computer")
    print()
    header = ["#", "Time", "Gap min", "Level", "Dur", "Keys", "Err", "Acc %", "WPM", "Brains", "End"]
    table = [header]
    for r in result["runs"]:
        table.append([str(r["n"]), show(r["local_time"]), show(r["gap_min"]), show(r["level_id"]),
                mmss(r["duration_s"]), show(r["keys_typed"]), show(r["errors"]), show(r["accuracy"]),
                show(r["wpm"]), show(r["brains"]), show(r["end_reason"])])
    if len(table) == 1:
        print("no finished runs")
    else:
        widths = [max(len(row[c]) for row in table) for c in range(len(header))]
        for row in table:
            print("  ".join(cell.ljust(widths[c]) for c, cell in enumerate(row)).rstrip())
    t = result["totals"]
    print()
    print(f"Finished runs: {t['finished_runs']}")
    print(f"Median accuracy: {show(t['median_accuracy'], ' %')} (target >= {t['accuracy_target']} %;"
            f" {t['accuracy_runs']} of {t['finished_runs']} runs have a value)")
    print(f"Median WPM: {show(t['median_wpm'])} ({t['wpm_runs']} of {t['finished_runs']} runs) · total keys: {show(t['total_keys'])}")
    best = ", ".join(f"{k} {show(v)}" for k, v in t["best_wpm"].items()) or DASH
    print(f"Best WPM: {best}")
    print(f"Brains now: {show(t['brains'])}")
    owned = t["owned_items"]
    print(f"Owned: {DASH if owned is None else (', '.join(owned) or 'none')}")
    hat, pet = t["equipped"]["hat"], t["equipped"]["pet"]
    print(f"Worn: hat {DASH if hat is None else hat or 'none'} · pet {DASH if pet is None else pet or 'none'}")
    f, st = t["flags"], t["settings"]
    print(f"Flags: welcome_bonus_claimed {show(f['welcome_bonus_claimed'])}"
            f" · tutorial_seen {show(f['tutorial_seen'])}")
    print(f"Settings: music_on {show(st['music_on'])} · sound_on {show(st['sound_on'])}")
    print()
    print("Most-missed keys (all runs):")
    if not result["top_missed_keys"]:
        print("  none")
    for k in result["top_missed_keys"]:
        print(f"  {k['key']!r}: {k['errors']} of {k['attempts']} wrong ({show(k['error_pct'], ' %')}),"
                f" most often typed {show(k['most_common_wrong'] and repr(k['most_common_wrong']))}")
    for w in result["warnings"]:
        print(f"warning: {w}", file=sys.stderr)


SELFTEST_SAVE = {
    "schema_version": 1,
    "active_profile": "p1",
    "profiles": {"p1": {
        "brains": 41.0,
        "owned_items": ["hat_pumpkin"],
        "equipped": {"hat": "hat_pumpkin", "pet": ""},
        "flags": {"welcome_bonus_claimed": True, "tutorial_seen": True},
        "settings": {"music_on": False, "sound_on": True},
        "best_wpm": {"zombie_run": 9.0},
        "run_history": [
            {"timestamp": 1790000000, "level_id": "zombie_run", "duration_s": 120, "keys_typed": 100.0,
                "errors": 20, "accuracy": 80, "wpm": 6, "brains": 30, "end_reason": "timer",
                "per_key": {"b": [10, 5, {"d": 4, "p": 1}], "q": [4, 2, {"p": 2}], "a": [20, 0, {}]}},
            {"timestamp": 1790000390, "level_id": "zombie_run", "duration_s": 120, "keys_typed": 120,
                "errors": 6, "accuracy": 94, "wpm": 9, "brains": 40, "end_reason": "timer",
                "per_key": {"b": [8, 1, {"d": 1}], "x": "broken"}},
        ],
    }},
}


def selftest() -> int:
    s = Summary()
    r = summarize(SELFTEST_SAVE, s)
    top = r["top_missed_keys"][0]
    checks = [
        ("finished runs", r["totals"]["finished_runs"], 2),
        ("median accuracy", r["totals"]["median_accuracy"], 87),
        ("median wpm", r["totals"]["median_wpm"], 7.5),
        ("gap minutes run 2", r["runs"][1]["gap_min"], 6.5),
        ("top missed key", top["key"], "b"),
        ("top key errors/attempts", (top["errors"], top["attempts"]), (6, 18)),
        ("top key most common wrong", top["most_common_wrong"], "d"),
        ("second missed key", r["top_missed_keys"][1]["key"], "q"),
        ("float 41.0 read as int", r["totals"]["brains"], 41),
        ("music off seen", r["totals"]["settings"]["music_on"], False),
        ("wrong-typed field warned", any("is not a finite number" in w for w in summarize(
            {"profiles": {"p1": {"run_history": [{"wpm": "fast"}]}}}, Summary())["warnings"]), True),
        ("negative duration shows a dash", mmss(-5), DASH),
        ("malformed per_key warned", any("per_key['x']" in w for w in r["warnings"]), True),
    ]
    # Broken saves must summarize and print, not crash.
    nasty = {"profiles": {"p1": {"brains": float("inf"), "run_history": [
        {"timestamp": 1e30, "duration_s": float("nan"), "accuracy": float("inf")},
        {"timestamp": -99999999999999, "duration_s": -5, "wpm": "fast"}]}}}
    for broken in ({}, [], {"profiles": {"p2": {"run_history": "nope", "brains": "lots"}}},
            {"profiles": {"p1": {"run_history": [None, {"timestamp": "x"}], "equipped": 5}}}, nasty):
        try:
            ws = Summary()
            res = summarize(broken, ws)
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                print_text(res, "selftest")
            json.dumps(res, allow_nan=False)
            checks.append((f"no crash on {str(broken)[:40]}", True, True))
        except Exception as e:  # noqa: BLE001 - the point is to catch anything
            checks.append((f"no crash on {str(broken)[:40]}", repr(e), True))
    failed = 0
    for name, got, want in checks:
        ok = got == want
        failed += not ok
        print(f"{'PASS' if ok else 'FAIL'}  {name}: got {got!r}" + ("" if ok else f", want {want!r}"))
    print("PASS" if failed == 0 else f"FAIL ({failed} of {len(checks)})")
    return 0 if failed == 0 else 1


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Summarize an exported Zombies Teach Typing save.")
    parser.add_argument("save", nargs="?", help="zts-save-YYYYMMDD.json (or a copy of save.json)")
    parser.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    parser.add_argument("--selftest", action="store_true", help="check the summary on a built-in fixture")
    args = parser.parse_args(argv)
    # Windows consoles default to cp1252, which garbles the dash and dot used in the output.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    if args.selftest:
        return selftest()
    if not args.save:
        parser.print_usage()
        return 2
    try:
        with open(args.save, encoding="utf-8-sig") as fh:
            data = json.load(fh)
    except (OSError, ValueError, RecursionError) as e:
        print(f"can't read {args.save}: {e}", file=sys.stderr)
        return 2
    result = summarize(data, Summary())
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=1))
    else:
        print_text(result, args.save)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

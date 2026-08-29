#!/usr/bin/env python3
"""One-off tool: merges a batch of new l10n keys into the 4 ARB files and
appends matching getters/methods to app_localizations.dart.

Input: a JSON file, a list of objects:
  {
    "key": "caregiverActivityTitle",
    "desc": "Activity screen title",           # optional, English-ARB-only
    "section": "Caregiver",                    # optional, groups the Dart getters under a comment
    "en": "Activity", "hi": "...", "as": "...", "mr": "...",
    "params": [["name", "String"]]             # optional, empty/absent = plain getter
  }

Usage: python tool/merge_l10n_keys.py path/to/batch.json
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"
LOCALES = ["en", "hi", "as", "mr"]


def load_arb(locale):
    path = L10N / f"app_{locale}.arb"
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def save_arb(locale, data):
    path = L10N / f"app_{locale}.arb"
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")


def dart_string(value):
    return (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
    )


def main():
    if len(sys.argv) != 2:
        print("usage: merge_l10n_keys.py batch.json", file=sys.stderr)
        return 1

    with open(sys.argv[1], encoding="utf-8") as fh:
        entries = json.load(fh)

    arbs = {loc: load_arb(loc) for loc in LOCALES}
    skipped = []

    for e in entries:
        key = e["key"]
        already = any(key in arbs[loc] for loc in LOCALES)
        if already:
            skipped.append(key)
            continue
        for loc in LOCALES:
            arbs[loc][key] = e[loc]
        if e.get("desc"):
            arbs["en"][f"@{key}"] = {"description": e["desc"]}

    for loc in LOCALES:
        save_arb(loc, arbs[loc])

    # ---- Dart getters/methods ----
    dart_path = L10N / "app_localizations.dart"
    text = dart_path.read_text(encoding="utf-8")

    lines = []
    current_section = None
    for e in entries:
        key = e["key"]
        if key in skipped:
            continue
        section = e.get("section")
        if section and section != current_section:
            lines.append(f"\n  // ── {section} ─" + "─" * max(0, 60 - len(section)))
            current_section = section
        params = e.get("params") or []
        if not params:
            lines.append(f"  String get {key} => _s('{key}');")
        else:
            sig = ", ".join(f"{t} {n}" for n, t in params)
            mapargs = ", ".join(f"'{n}': {n}" for n, t in params)
            lines.append(
                f"  String {key}({sig}) => _f('{key}', <String, Object?>{{{mapargs}}});"
            )

    insertion = "\n".join(lines) + "\n"
    marker = "  // ── Language names ─────────────────────────────────────────────────────"
    idx = text.index(marker)
    text = text[:idx] + insertion + "\n" + text[idx:]
    dart_path.write_text(text, encoding="utf-8", newline="\n")

    print(f"Merged {len(entries) - len(skipped)} keys, skipped {len(skipped)} already-present: {skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

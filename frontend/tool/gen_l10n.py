#!/usr/bin/env python3
"""Generates lib/l10n/app_localizations.g.dart from the ARB files.

Stands in for `flutter gen-l10n`, which needs `intl`, `flutter_localizations`
and `generate: true` in pubspec.yaml. The ARB files are the real source of
truth and are written in the standard format, so switching to the official
tool later means deleting this script and adding an l10n.yaml — no string
changes, no call-site changes.

Run after editing any ARB:

    python3 tool/gen_l10n.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"
TEMPLATE_LOCALE = "en"
PLACEHOLDER = re.compile(r"\{(\w+)\}")


def load(locale):
    with open(L10N / f"app_{locale}.arb", encoding="utf-8") as fh:
        return json.load(fh)


def keys_of(arb):
    return [k for k in arb if not k.startswith("@")]


def dart_string(value):
    """Escapes a translated string for a single-quoted Dart literal."""
    return (
        value.replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("$", "\\$")
        .replace("\n", "\\n")
    )


def main():
    template = load(TEMPLATE_LOCALE)
    template_keys = keys_of(template)
    locales = sorted(p.stem.split("_", 1)[1] for p in L10N.glob("app_*.arb"))

    # Key parity is a build error, not a warning: a missing key would render
    # as a blank label to a patient who cannot report it.
    problems = []
    for locale in locales:
        arb = load(locale)
        missing = [k for k in template_keys if k not in arb]
        extra = [k for k in keys_of(arb) if k not in template_keys]
        if missing:
            problems.append(f"  {locale}: missing {missing}")
        if extra:
            problems.append(f"  {locale}: unknown keys {extra}")
        for key in template_keys:
            if key in arb:
                want = set(PLACEHOLDER.findall(template[key]))
                got = set(PLACEHOLDER.findall(arb[key]))
                if want != got:
                    problems.append(
                        f"  {locale}.{key}: placeholders {sorted(got)} != {sorted(want)}"
                    )
    if problems:
        print("ARB validation failed:\n" + "\n".join(problems), file=sys.stderr)
        return 1

    out = [
        "// GENERATED — do not edit by hand.",
        "// ignore_for_file: constant_identifier_names",
        "// Source: lib/l10n/app_*.arb   Regenerate: python3 tool/gen_l10n.py",
        "",
        "part of 'app_localizations.dart';",
        "",
    ]

    for locale in locales:
        arb = load(locale)
        out.append(f"const Map<String, String> _strings_{locale} = <String, String>{{")
        for key in template_keys:
            out.append(f"  '{key}': '{dart_string(arb[key])}',")
        out.append("};")
        out.append("")

    out.append("const Map<String, Map<String, String>> _byLocale =")
    out.append("    <String, Map<String, String>>{")
    for locale in locales:
        out.append(f"  '{locale}': _strings_{locale},")
    out.append("};")
    out.append("")

    (L10N / "app_localizations.g.dart").write_text("\n".join(out), encoding="utf-8")
    print(f"Generated {len(template_keys)} keys for {locales}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

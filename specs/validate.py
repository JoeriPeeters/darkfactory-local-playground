#!/usr/bin/env python3
"""
Validate Konkreet spec frontmatter against specs/schema.json.

Usage:
    python3 specs/validate.py            # validate all specs/PB-*.md
    python3 specs/validate.py path.md    # validate one file

Exit code 0 = all valid, 1 = at least one invalid. Stdlib only; no external deps.
The frontmatter is intentionally simple YAML (flat key: value, plus one inline list),
so we parse it directly rather than pulling in PyYAML.
"""
import json
import re
import sys
from pathlib import Path

SPECS_DIR = Path(__file__).resolve().parent
SCHEMA = json.loads((SPECS_DIR / "schema.json").read_text())


def extract_frontmatter(text):
    """Return the raw lines between the first two '---' fences, or None."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    out = []
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        out.append(line)
    return None  # no closing fence


def parse_value(raw):
    """Coerce a frontmatter scalar/list into a Python value."""
    raw = raw.strip()
    if raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        return [item.strip().strip('"').strip("'") for item in inner.split(",")]
    low = raw.lower()
    if low in ("true", "false"):
        return low == "true"
    return raw.strip('"').strip("'")


def parse_frontmatter(fm_lines):
    data = {}
    for line in fm_lines:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, raw = line.partition(":")
        data[key.strip()] = parse_value(raw)
    return data


def validate(data):
    errors = []
    fields = SCHEMA["fields"]
    enums = SCHEMA.get("enums", {})

    # unknown fields
    if not SCHEMA.get("allow_unknown_fields", True):
        for key in data:
            if key not in fields:
                errors.append(f"unknown field '{key}' (not in schema)")

    for name, rule in fields.items():
        if name not in data:
            if rule.get("required"):
                errors.append(f"missing required field '{name}'")
            continue
        value = data[name]
        expected = rule["type"]

        # type
        if expected == "string" and not isinstance(value, str):
            errors.append(f"'{name}' must be a string, got {value!r}")
            continue
        if expected == "bool" and not isinstance(value, bool):
            errors.append(f"'{name}' must be true/false, got {value!r}")
            continue
        if expected == "list" and not isinstance(value, list):
            errors.append(f"'{name}' must be a list, got {value!r}")
            continue

        # pattern (strings)
        if "pattern" in rule and isinstance(value, str):
            if not re.match(rule["pattern"], value):
                errors.append(f"'{name}'={value!r} does not match {rule['pattern']}")

        # enum (strings)
        if "enum" in rule and isinstance(value, str):
            if value not in rule["enum"]:
                errors.append(f"'{name}'={value!r} not in {rule['enum']}")

        # item_enum (lists)
        if "item_enum" in rule and isinstance(value, list):
            allowed = enums.get(rule["item_enum"], [])
            for item in value:
                if item not in allowed:
                    errors.append(f"'{name}' has invalid value {item!r}; allowed: {allowed}")

    return errors


def validate_file(path):
    text = Path(path).read_text()
    fm = extract_frontmatter(text)
    if fm is None:
        return [f"no frontmatter block (must start with '---' ... '---')"]
    return validate(parse_frontmatter(fm))


def main(argv):
    if argv:
        targets = [Path(a) for a in argv]
    else:
        targets = sorted(SPECS_DIR.glob("PB-*.md"))
    if not targets:
        print("no specs to validate (specs/PB-*.md)")
        return 0

    failed = 0
    for path in targets:
        errors = validate_file(path)
        if errors:
            failed += 1
            print(f"FAIL  {path.name}")
            for e in errors:
                print(f"        - {e}")
        else:
            print(f"PASS  {path.name}")

    print(f"\n{len(targets) - failed}/{len(targets)} valid")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

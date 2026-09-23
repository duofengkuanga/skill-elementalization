#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <symbol> [gitnexus impact options]" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status="$(node .gitnexus/run.cjs status)"
if [[ "$status" != *"up-to-date"* ]]; then
  echo "$status" >&2
  echo "GitNexus index is unavailable or stale; run: node .gitnexus/run.cjs analyze" >&2
  exit 1
fi

result="$(node .gitnexus/run.cjs impact "$1" --direction upstream --repo skill-elementalization "${@:2}")"
printf '%s\n' "$result" | python3 -c '
import json
import sys

try:
    result = json.load(sys.stdin)
    summary = result["summary"]
    valid = (
        result["target"]["id"]
        and result["risk"]
        and isinstance(summary["direct"], int)
        and isinstance(summary["processes_affected"], int)
    )
    if not valid:
        raise ValueError("missing target, direct dependants, affected processes, or risk")
except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
    print(f"GitNexus impact returned an incomplete result: {error}", file=sys.stderr)
    sys.exit(1)

print(json.dumps(result, ensure_ascii=False, indent=2))
'

#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# != 1 ]]; then
    printf '%s\n' 'Usage: tools/runner.sh <config.json>' >&2
    exit 2
fi
exec python3 "$root/tools/pipeline/declarative_runner.py" "$1"
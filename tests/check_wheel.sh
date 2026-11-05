#!/usr/bin/env bash
# Installs a wheel into a clean venv and runs the smoke test.
# Usage: tests/check_wheel.sh dist/<wheel>.whl
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <wheel>" >&2
  exit 2
fi

WHEEL="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
TESTS="$(cd "$(dirname "$0")" && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

uv venv --python 3.11 "$TMP/venv"
uv pip install --python "$TMP/venv/bin/python" "$WHEEL" numpy

# Outside the repository, so that only the installed package can be imported
(cd "$TMP" && "$TMP/venv/bin/python" "$TESTS/smoke_test.py")

# On macOS every non-system library must come from inside the wheel.
# /DLC/ is the install name delocate gives to bundled libraries, not a dependency.
if [ "$(uname)" = "Darwin" ]; then
  outside="$(find "$TMP/venv" -path '*/OCC/*' \( -name '*.so' -o -name '*.dylib' \) \
    -exec otool -L {} + \
    | grep -E '^[[:space:]]+/' \
    | grep -vE '^[[:space:]]+/(usr/lib|System|DLC)/' || true)"
  if [ -n "$outside" ]; then
    echo "libraries outside the wheel:" >&2
    echo "$outside" | sort -u >&2
    exit 1
  fi
  echo "linkage check passed"
fi

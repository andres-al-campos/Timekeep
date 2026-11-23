#!/bin/bash
# Test: the session clock and the daily row, compiled with swiftc against
# Sources/Models/SessionState.swift, so it runs without Xcode or a simulator.
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
if ! swiftc -O -o "$out/session-state" Sources/Models/SessionState.swift tests/session-state/main.swift 2>"$out/err"; then
    cat "$out/err"
    echo "✗ session-state: didn't compile. Fix the errors above in Sources/Models/SessionState.swift or tests/session-state/main.swift."
    exit 1
fi
"$out/session-state"

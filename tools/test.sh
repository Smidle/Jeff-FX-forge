#!/usr/bin/env bash
# FX Forge dev test runner (macOS / Linux / Git Bash).
#   tools/test.sh [unit|gallery|editor|selftest|all] [filter]
# Godot is located via $GODOT, then common install paths, then PATH.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/tests/output"
SUITE="${1:-unit}"
FILTER="${2:-}"
PATTERNS='SCRIPT ERROR|Parse Error|Unable to load addon script|Failed to load script|Compile Error'

find_godot() {
	if [[ -n "${GODOT:-}" && -x "${GODOT}" ]]; then echo "$GODOT"; return; fi
	local c
	for c in "/Applications/Godot.app/Contents/MacOS/Godot" "$(command -v godot 2>/dev/null)" "$(command -v godot4 2>/dev/null)"; do
		if [[ -n "$c" && -x "$c" ]]; then echo "$c"; return; fi
	done
	echo "Godot not found. Set GODOT to the Godot 4.7 executable." >&2
	exit 2
}

GODOT_BIN="$(find_godot)"
echo "== Godot: $GODOT_BIN"
mkdir -p "$OUT"
ALL_OK=0

run_godot() { # project logname args...
	local proj="$1" log="$OUT/$2"
	shift 2
	rm -f "$log"
	"$GODOT_BIN" --headless --path "$proj" --log-file "$log" "$@"
	local code=$?
	if [[ -f "$log" ]] && grep -Eq "$PATTERNS" "$log"; then
		echo "!! errors in $log:"
		grep -En "$PATTERNS" "$log" | head -20
		return 1
	fi
	return $code
}

ensure_imported() { [[ -d "$1/.godot" ]] || run_godot "$1" import.log --import || true; }

project_copy() {
	local d
	d="$(mktemp -d)"
	if command -v rsync >/dev/null 2>&1; then
		rsync -a --exclude .git --exclude tests/output "$ROOT/" "$d/"
	else
		cp -R "$ROOT/." "$d/" && rm -rf "$d/.git" "$d/tests/output"
	fi
	echo "$d"
}

report() { if [[ $2 -eq 0 ]]; then echo "== $1 : PASS"; else echo "== $1 : FAIL"; ALL_OK=1; fi; }

if [[ "$SUITE" == unit || "$SUITE" == all ]]; then
	ensure_imported "$ROOT"
	if [[ -n "$FILTER" ]]; then run_godot "$ROOT" unit.log --script res://tests/run_tests.gd -- "$FILTER"
	else run_godot "$ROOT" unit.log --script res://tests/run_tests.gd; fi
	report "unit tests" $?
fi

if [[ "$SUITE" == gallery || "$SUITE" == all ]]; then
	ensure_imported "$ROOT"
	run_godot "$ROOT" gallery.log --script res://tests/render_gallery.gd
	report "gallery" $?
fi

if [[ "$SUITE" == editor || "$SUITE" == all ]]; then
	ensure_imported "$ROOT"
	COPY="$(project_copy)"
	run_godot "$COPY" editor_smoke.log --editor --quit
	code=$?
	grep -q "res://addons/fx_forge/plugin.cfg" "$COPY/project.godot" || { echo "   plugin was removed from project.godot"; code=1; }
	report "editor smoke" $code
	rm -rf "$COPY"
fi

if [[ "$SUITE" == selftest || "$SUITE" == all ]]; then
	ensure_imported "$ROOT"
	COPY="$(project_copy)"
	run_godot "$COPY" selftest.log --editor -- --fxforge-selftest
	code=$?
	grep -q "FXFORGE_SELFTEST: PASS" "$OUT/selftest.log" || code=1
	report "editor export selftest" $code
	rm -rf "$COPY"
fi

exit $ALL_OK

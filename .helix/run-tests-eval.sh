#!/usr/bin/env bash
# Run the Go test suite. No Docker invocations — CI builds the image and runs this script inside it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

export ASC_BYPASS_KEYCHAIN=1

run_go_test() {
	local -a args=("go" "test" "-v" "$@")

	if [[ "$(id -u)" -eq 0 ]] && id helix >/dev/null 2>&1; then
		local cmd
		printf -v cmd '%q ' env "ASC_BYPASS_KEYCHAIN=${ASC_BYPASS_KEYCHAIN}" "GOCACHE=${GOCACHE:-/tmp/gocache}" "GOTMPDIR=${GOTMPDIR:-/tmp/go-tmp}" "${args[@]}"
		su -s /bin/bash helix -c "cd $(printf '%q' "$REPO_ROOT") && $cmd"
		return
	fi

	"${args[@]}"
}

# Root-level tests read `.github/workflows/release.yml`; some sparse checkouts omit it.
run_all() {
	local -a skip=()
	if [[ ! -f .github/workflows/release.yml ]]; then
		skip=(-skip '^TestReleaseWorkflow')
	fi
	run_go_test ./... "${skip[@]}"
}

# Comma-separated paths → unique package directories (go test runs per package).
run_targeted() {
	local csv="$1"
	local -a files=()
	local IFS=','

	read -ra files <<< "$csv"

	if [[ ${#files[@]} -eq 0 ]]; then
		run_all
		return
	fi

	declare -A pkgs=()
	local f dir
	for f in "${files[@]}"; do
		f="${f#"${f%%[![:space:]]*}"}"
		f="${f%"${f##*[![:space:]]}"}"
		[[ -z "$f" ]] && continue
		if [[ ! -e "$f" ]]; then
			echo "Error: test path does not exist: $f" >&2
			exit 1
		fi
		dir="$(dirname "$f")"
		pkgs["./$dir"]=1
	done

	if [[ ${#pkgs[@]} -eq 0 ]]; then
		run_all
		return
	fi

	run_go_test "${!pkgs[@]}"
}

if [[ $# -eq 0 ]]; then
	run_all
else
	run_targeted "$1"
fi

#!/usr/bin/env bash
# Purpose: Verify that file paths referenced by skills/ao-conductor.md exist in git.
#
# Usage: bash scripts/verify-completeness.sh

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
set -u

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
	echo "fatal: run this script inside the repository" >&2
	exit 2
}

cd "$REPO_ROOT" || exit 2

SOURCE_FILE=skills/ao-conductor.md

if [ ! -f "$SOURCE_FILE" ]; then
	echo "fatal: missing $SOURCE_FILE" >&2
	exit 2
fi

extract_referenced_paths() {
	awk '
		{
			line = $0
			while (match(line, /(^|[^A-Za-z0-9._\/-])((experts|skills\/references|references)\/[A-Za-z0-9._\/-]*[A-Za-z0-9_-])/, matches)) {
				print matches[2]
				line = substr(line, RSTART + RLENGTH)
			}
		}
	' "$SOURCE_FILE" |
		while IFS= read -r path; do
			case "$path" in
			references/*)
				# references/... inside skills/ao-conductor.md is relative to skills/.
				printf 'skills/%s\n' "$path"
				;;
			*)
				printf '%s\n' "$path"
				;;
			esac
		done |
		sort -u
}

mapfile -t REFERENCED_PATHS < <(extract_referenced_paths)

if [ "${#REFERENCED_PATHS[@]}" -eq 0 ]; then
	echo "No referenced files under experts/ or skills/references/ were found in $SOURCE_FILE."
	exit 0
fi

MISSING_PATHS=()

for path in "${REFERENCED_PATHS[@]}"; do
	if ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
		MISSING_PATHS+=("$path")
	fi
done

printf 'Checked %s referenced file(s) in %s.\n' "${#REFERENCED_PATHS[@]}" "$SOURCE_FILE"

if [ "${#MISSING_PATHS[@]}" -eq 0 ]; then
	echo "All referenced files are tracked in git."
	exit 0
fi

echo "Missing referenced files:"
printf ' - %s\n' "${MISSING_PATHS[@]}"
exit 1

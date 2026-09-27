#!/usr/bin/env bash
set -euo pipefail

# Fail if the image's rpmdb is not a healthy SQLite database.
#
# stable.20260825 shipped with a corrupt rpmdb even though its Bazzite base
# was clean. Every later rpm transaction against it failed, which is what
# broke the 2026-09-01 ISO build (titanoboa's `dnf install dracut-live`).
# Run from 99-cleanup.sh (catches corruption from our build steps) and
# again in CI against the rechunked image (catches the rechunk step).

db=/usr/lib/sysimage/rpm/rpmdb.sqlite

if [[ ! -f "${db}" ]]; then
    echo "ERROR: rpmdb not found at ${db}"
    exit 1
fi

result=$(python3 - "${db}" <<'PY'
import sqlite3
import sys

try:
    con = sqlite3.connect(sys.argv[1])
    print(con.execute("PRAGMA quick_check").fetchone()[0])
    con.close()
except sqlite3.DatabaseError as e:
    # Badly damaged databases raise instead of returning a report.
    print(e)
PY
)

if [[ "${result}" != "ok" ]]; then
    echo "ERROR: rpmdb integrity check failed:"
    echo "${result}" | head -20
    exit 1
fi

echo "rpmdb integrity check: ok"

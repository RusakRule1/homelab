#!/usr/bin/env bash
set -euo pipefail

# Scan every pinned image for known CVEs. Complements Diun: Diun says "a newer tag
# exists"; this says "your CURRENT pinned image has a known, fixable vulnerability".
# Usage: scripts/scan.sh            (HIGH,CRITICAL, fixable only; exits 1 on findings)
#        SEVERITY=CRITICAL scripts/scan.sh
#        IGNORE_UNFIXED=false scripts/scan.sh   (include not-yet-fixed CVEs)
#        FAIL_ON_FINDINGS=false scripts/scan.sh (report-only, always exit 0 — used in CI)

cd "$(dirname "$0")/.."

TRIVY_VERSION="${TRIVY_VERSION:-0.74.0}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IGNORE_UNFIXED="${IGNORE_UNFIXED:-true}"
FAIL_ON_FINDINGS="${FAIL_ON_FINDINGS:-true}"

unfixed_flag="--ignore-unfixed"
[ "$IGNORE_UNFIXED" = "false" ] && unfixed_flag=""

images=$(grep -rhoE '^[[:space:]]*image:[[:space:]]*[^[:space:]]+' ./*/docker-compose.yml \
  | awk '{print $2}' | sort -u)

rc=0
for img in $images; do
  echo "=================== $img ==================="
  docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v trivy-cache:/root/.cache/ \
    "aquasec/trivy:${TRIVY_VERSION}" image \
      --scanners vuln --severity "$SEVERITY" $unfixed_flag \
      --no-progress --exit-code 1 "$img" || rc=1
done

if [ "$rc" -ne 0 ]; then
  echo
  echo "!! Fixable ${SEVERITY} vulnerabilities found. Bump the affected pin(s) and re-scan."
  if [ "$FAIL_ON_FINDINGS" != "true" ]; then
    echo "(report-only mode: not failing the run)"
    exit 0
  fi
fi
exit "$rc"

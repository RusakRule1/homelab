#!/usr/bin/env bash
set -euo pipefail

# Scan every pinned image for known CVEs. Complements Diun: Diun says "a newer tag
# exists"; this says "your CURRENT pinned image has a known, fixable vulnerability".
# Usage: scripts/scan.sh            (HIGH,CRITICAL, fixable only)
#        SEVERITY=CRITICAL scripts/scan.sh
#        IGNORE_UNFIXED=false scripts/scan.sh   (include not-yet-fixed CVEs)

cd "$(dirname "$0")/.."

TRIVY_VERSION="${TRIVY_VERSION:-0.74.0}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
IGNORE_UNFIXED="${IGNORE_UNFIXED:-true}"

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
fi
exit "$rc"

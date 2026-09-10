#!/bin/bash
# Daily iptv maintenance: restart the container, then commit & push repo state.
# Scheduled via launchd at 05:00 daily (com.iptv.daily-maintenance.plist).

set -u

REPO="/Users/yishi/code/iptv-api"
CONTAINER="iptv"
STATE="$REPO/output/data/run_state.json"
MAX_WAIT_S=1200

log() { echo "[$(date '+%F %T')] $*"; }

# launchd runs with a minimal PATH; make docker/git available.
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/yishi/.orbstack/bin:$PATH"
export HOME="${HOME:-/Users/yishi}"

log "restarting container ${CONTAINER}"
docker restart "${CONTAINER}" || { log "docker restart failed"; exit 1; }

# update_startup=True triggers an update on boot (~2-4 min). Wait for it to
# finish so the committed output is fresh, not a mid-run snapshot.
START_EPOCH=$(date +%s)
log "waiting for startup update to complete (timeout ${MAX_WAIT_S}s)"
while :; do
  if [ -f "$STATE" ]; then
    MTIME=$(stat -f %m "$STATE" 2>/dev/null || echo 0)
    STATUS=$(grep -o '"status":"[^"]*"' "$STATE" 2>/dev/null | head -1 | cut -d'"' -f4)
    if [ "$MTIME" -gt "$START_EPOCH" ] && [ "$STATUS" = "completed" ]; then
      log "update completed"
      break
    fi
  fi
  NOW=$(date +%s)
  if [ $((NOW - START_EPOCH)) -ge "$MAX_WAIT_S" ]; then
    log "timeout waiting for update; committing current state anyway"
    break
  fi
  sleep 5
done

cd "$REPO" || { log "repo missing"; exit 1; }
git add -A
if git diff --cached --quiet; then
  log "no changes to commit"
else
  git commit -q -m "chore: daily snapshot $(date '+%F %T')" && log "committed"
fi
git push origin master 2>&1 | sed 's/^/[push] /'
log "done"

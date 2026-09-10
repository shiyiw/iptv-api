#!/bin/bash
# Daily iptv maintenance: restart the container, wait 15 min for the startup
# update to finish, then commit & push the repo state.
# Scheduled via launchd at 05:00 daily (com.iptv.daily-maintenance.plist).

set -u

REPO="/Users/yishi/code/iptv-api"
CONTAINER="iptv"
WAIT_S="${IPTV_WAIT_S:-900}"

log() { echo "[$(date '+%F %T')] $*"; }

# launchd runs with a minimal PATH; make docker/git available.
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/yishi/.orbstack/bin:$PATH"
export HOME="${HOME:-/Users/yishi}"

log "restarting container ${CONTAINER}"
docker restart "${CONTAINER}" || { log "docker restart failed"; exit 1; }

log "waiting ${WAIT_S}s for startup update to complete"
sleep "${WAIT_S}"

cd "$REPO" || { log "repo missing"; exit 1; }
git add -A
if git diff --cached --quiet; then
  log "no changes to commit"
else
  git commit -q -m "chore: daily snapshot $(date '+%F %T')" && log "committed"
fi
git push origin master 2>&1 | sed 's/^/[push] /'
log "done"

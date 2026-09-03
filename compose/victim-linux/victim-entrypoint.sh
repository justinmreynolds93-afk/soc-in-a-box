#!/bin/bash
# Start rsyslog + sshd (so auth/syslog land in /var/log for the System
# integration), then hand off to the stock Elastic Agent container entrypoint,
# which performs Fleet enrollment from the FLEET_* / KIBANA_* environment.
set -eo pipefail

# rsyslog drops privileges to the 'syslog' user, so the log files must be
# writable by it.
for f in /var/log/auth.log /var/log/syslog; do
  : > "$f"
  chown syslog:adm "$f" 2>/dev/null || true
  chmod 640 "$f"
done

rsyslogd
/usr/sbin/sshd
echo "[victim] rsyslog + sshd up"

# light background noise so the host looks alive
( while true; do sleep 300; logger -p cron.info "CRON[$$]: (root) CMD (command -v debian-sa1)"; done ) &

umask 0007
exec elastic-agent container "$@"

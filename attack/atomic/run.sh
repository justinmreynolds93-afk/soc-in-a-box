#!/usr/bin/env bash
# Run Atomic Red Team tests INSIDE the linux-victim container.
# Installs Invoke-AtomicRedTeam (via pwsh) on first use.
#
#   ./run.sh T1059.004 T1136.001         # specific techniques
#   ./run.sh --list T1053.003            # show what a technique would do
#   ./run.sh --cleanup T1136.001         # revert
#
# Windows atomics run on the VM instead — see vm/provision/40-atomics.ps1.
set -u

VICTIM="${VICTIM:-soc-in-a-box-linux-victim-1}"
ATOMICS="/opt/atomic-red-team/atomics"
MODE="run"
case "${1:-}" in
  --list)    MODE="list";    shift ;;
  --cleanup) MODE="cleanup"; shift ;;
esac
[ $# -gt 0 ] || { echo "usage: $0 [--list|--cleanup] T#### [T#### ...]"; exit 1; }

vexec() { docker exec -u root "$VICTIM" bash -lc "$*"; }

if ! vexec 'command -v pwsh >/dev/null'; then
  echo "[*] installing PowerShell + Invoke-AtomicRedTeam in the victim"
  vexec 'apt-get update -qq && apt-get install -y -qq wget apt-transport-https software-properties-common >/dev/null
         . /etc/os-release
         wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -O /tmp/ms.deb
         dpkg -i /tmp/ms.deb >/dev/null && apt-get update -qq && apt-get install -y -qq powershell >/dev/null
         pwsh -NoProfile -c "Install-Module -Name Invoke-AtomicRedTeam -Scope AllUsers -Force;
             Install-AtomicRedTeam -getAtomics -Force -InstallPath /opt/atomic-red-team"'
fi

for t in "$@"; do
  case "$MODE" in
    list)    flag="-ShowDetailsBrief" ;;
    cleanup) flag="-Cleanup" ;;
    *)       flag="" ;;
  esac
  echo "== Invoke-AtomicTest $t $flag"
  vexec "pwsh -NoProfile -c 'Invoke-AtomicTest $t -PathToAtomicsFolder $ATOMICS $flag'"
done

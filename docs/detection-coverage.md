# Detection Coverage

> Regenerate the machine-readable layer with
> `pwsh scripts/generate-navigator-layer.ps1` → `docs/attack-navigator-layer.json`
> (import at [mitre-attack.github.io/attack-navigator](https://mitre-attack.github.io/attack-navigator/)).

## The core finding from M3

The lab collects **System integration** (auth, syslog) and **Network Packet
Capture** (flows, DNS) telemetry from the Linux victim. It does **not** run
Elastic Defend, `auditd_manager`, or an EDR agent on that container — Elastic
Defend's kernel probes are unreliable inside the Docker Desktop WSL2 kernel, and
`auditd` cannot own the kernel audit socket from a container.

When the ~90 tag-curated prebuilt rules were first enabled, **~85 of them sat in
"partial failure"**: their queries target `logs-endpoint.events.*`,
`logs-auditd_manager.auditd-*`, `logs-crowdstrike.fdr*`, `winlogbeat-*`, etc. —
indices that do not exist here.

Two consequences, and they shape the rest of the project:

1. **`scripts/enable-detection-rules.ps1` now filters prebuilt rules by index
   compatibility** — it only enables rules whose index patterns overlap what we
   actually ingest, and disables the rest. The enabled set is honest about what
   can run.
2. **Process- and file-level techniques on Linux need host telemetry we don't
   have from a container.** The lab covers them two ways:
   - custom rules written against the telemetry we *do* have (auth, syslog,
     netflow, DNS) — see `elastic/detection-rules/rules/`
   - the **Windows victim** (`vm/`), where Sysmon + Windows event logs land in
     `logs-windows.sysmon_operational-*` / `logs-system.security-*` and match a
     large body of prebuilt and custom rules

## Scenario → detection results

`attack/scenarios/linux-intrusion.sh` (11 ATT&CK techniques).
`scripts/detection-gap-report.ps1` after the run:

**Coverage: 5 / 11 techniques (45%) — 27 alerts across 8 rules.**

| Technique | Name | Detected by |
|---|---|---|
| T1110.001 | SSH password guessing | `soc-linux-ssh-bruteforce` (custom) |
| T1078 | Valid Accounts | `soc-linux-ssh-bruteforce-success` (custom) + 2 prebuilt ("Successful SSH Auth from Unusual IP / User") |
| T1059.004 | Unix shell execution | **gap** — needs process events (endpoint/auditd) |
| T1087.001 | Account / system / file discovery | **gap** — needs process events |
| T1003.008 | Credential dumping (/etc/shadow) | **gap** — needs file events |
| T1136.001 | Create local account | `soc-linux-new-local-user` (custom) |
| T1053.003 | Cron persistence | `soc-linux-cron-suspicious-command` (custom) |
| T1548.003 | Sudoers / privileged group | partial — `soc-linux-user-added-privileged-group` fires on the group add, not the `/etc/sudoers.d` write (needs file events) |
| T1105 | Ingress tool transfer | **gap** — the download is a process event; only visible if the payload host also trips `soc-network-external-beaconing` |
| T1071.001 | C2 + exfil over web | `soc-network-external-beaconing` (custom) |
| T1070.003 | Clear history / logs | **gap** — needs file/process events |

**Every gap is a process- or file-level technique.** They are covered by the
Windows victim (Sysmon → `logs-windows.sysmon_operational-*`), and would be
covered on Linux by adding Elastic Defend or `auditd_manager` on a VM-based
victim rather than a container.

## Custom rules and the telemetry they use

| Rule | Type | Index | ATT&CK |
|---|---|---|---|
| `soc-linux-ssh-bruteforce` | threshold | `logs-system.auth-*` | T1110.001 |
| `soc-linux-ssh-bruteforce-success` | eql sequence | `logs-system.auth-*` | T1110.001 / T1078 |
| `soc-linux-new-local-user` | query | `logs-system.auth-*`, `logs-system.syslog-*` | T1136.001 |
| `soc-linux-user-added-privileged-group` | query | `logs-system.*` | T1098 |
| `soc-linux-cron-suspicious-command` | query | `logs-system.syslog-*` | T1053.003 |
| `soc-linux-root-login-accepted` | query | `logs-system.auth-*` | T1078.003 |
| `soc-network-external-beaconing` | threshold | `logs-network_traffic.flow-*` | T1071.001 |
| `soc-network-dns-high-unique-subdomains` | threshold | `logs-network_traffic.dns-*` | T1071.004 / T1568 |
| `soc-win-powershell-encoded-command` | query | `logs-windows.sysmon_operational-*` | T1059.001 |
| `soc-win-clear-event-logs` | query | `logs-system.security-*` | T1070.001 |
| `soc-win-new-local-admin` | query | `logs-system.security-*` | T1136.001 / T1098 |
| `soc-win-defender-tampering` | query | `logs-windows.sysmon_operational-*` | T1562.001 |
| `soc-win-lsass-credential-access` | query | `logs-windows.sysmon_operational-*` | T1003.001 |

Windows rules stay in "partial failure" until the Windows victim VM is enrolled
(`vm/`, `scripts/setup-fleet.ps1` prints its enrollment token).

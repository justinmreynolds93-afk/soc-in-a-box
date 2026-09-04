# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] — 2026-09-04

Windows telemetry live and the lab verified end to end against real data.

### Added
- **Windows host agent** enrolled and shipping — Sysmon (Olaf Hartong config),
  Windows Security / System event logs, PowerShell script-block logs, auth.
  `scripts/install-windows-telemetry.ps1` (elevated, ASCII + BOM, curl download).
- Certs carry `host.docker.internal` as a SAN — one hostname for the Fleet output
  and Fleet Server, reachable from both the containers and the Docker host.
- `docs/verification.md` — API-pulled snapshot: 2 agents online, 256 rules
  (250 succeeded / 6 partial / 0 failed), 13/13 custom rules green, live Sysmon
  event breakdown.
- `docs/wslconfig.example` — cap the WSL2 VM so a host agent isn't starved.

### Fixed
- **All 5 Windows custom rules** — invalid KQL (quoted-substring wildcards,
  unescaped `(`); rewritten against live field data, now execute `succeeded`.
- Fleet output loaded a container CA path a host agent can't reach → beats failed;
  switched to `verification_mode: none` (encrypted, `--insecure` enrollment).
- Windows policy ships **logs only** — `windows.perfmon` (~40k docs/10 min) was
  pinning Elasticsearch; `windows/metrics` + `system/metrics` inputs disabled.
- ES heap right-sized for the Windows-agent session (1.28 GB / 2.5 GB limit).
- `enable-detection-rules.ps1` second pass disables prebuilt ES|QL rules that
  hard-fail on absent fields.

### Notes
- Windows rules are proven to *execute* on live telemetry, not yet to *alert* —
  attack validation needs the VirtualBox victim VM (`vm/`); the host is never a
  target (`docs/scope.md`).

## [0.1.0] — 2026-09-03

### Added — Windows telemetry path
- `scripts/install-windows-telemetry.ps1` (elevated): Sysmon + Olaf Hartong
  config, the audit subcategories + PS script-block logging the rules need, and a
  Fleet-enrolled Elastic Agent on the Windows Victim Policy. curl.exe downloads,
  ASCII + UTF-8 BOM so Windows PowerShell 5.1 parses it.
- Certs now carry `host.docker.internal` in the SAN; one Fleet output + one Fleet
  Server host on that name, reachable from containers and the Docker host alike
- `docs/wslconfig.example` — cap the WSL2 VM so a host agent isn't starved
- **Status:** agent enrolls and registers in Fleet; its beats can't hold the
  ~400 MB they need on a 16 GB machine also running the stack — see
  `docs/detection-coverage.md`. 5 custom Windows rules + Windows prebuilts are
  deployed and enabled (261 rules live), ready for when the data streams appear.

### Added — M6 (SOAR + response)
- `compose/compose.soar.yml` + `soar/n8n/soc-alert-triage.json`: n8n **polls**
  Kibana for open SOC-in-a-Box alerts every 5 min (Elastic Basic has no rule
  connector actions), enriches `source.ip` via AbuseIPDB, opens a Kibana case for
  high severity + Slack page / note, then acks the alert. Kibana auth is built
  from `ELASTIC_PASSWORD` in the workflow — no n8n credential to wire.
- `scripts/import-soar-workflow.ps1`: import + activate + restart; wired into
  `make soar` / `soc.ps1 soar`
- **Verified end-to-end**: a synthetic high-severity alert produced a real Kibana
  case ("Successful SSH Login After Brute Force — linux-victim", high, open)
- `docs/runbooks/ssh-brute-force.md`, `docs/runbooks/suspicious-new-account.md`

### Added — M5 (detection CI)
- `.github/workflows/detection-ci.yml`: validates every custom rule (schema +
  required fields via `deploy-detections.ps1 -Validate`), checks rule_id
  uniqueness and ATT&CK mapping, and converts the Sigma rules with `sigma-cli`

### Added — M4 (detection engineering)
- `elastic/detection-rules/rules/*.json` — 13 custom rules as code (Kibana rule
  bodies, one file per rule), 8 Linux/Network + 5 Windows, each MITRE-mapped with
  triage notes and false-positive guidance
- `scripts/deploy-detections.ps1` — validate + import (`-Validate` for CI)
- `scripts/generate-navigator-layer.ps1` — ATT&CK Navigator layer from enabled rules
- `enable-detection-rules.ps1` rewritten to enable prebuilt rules **by index
  compatibility** (disable the ~85 that need EDR/auditd indices we don't have)
- `docs/detections/*.md` — per-detection writeups
- `docs/detection-coverage.md` — the coverage story + gap table

### Added — M3 (adversary emulation)
- `attack/scenarios/linux-intrusion.sh` — 11-technique kill chain vs the victim,
  writes a run log for the gap report
- `attack/scenarios/network-recon.sh` — nmap/hydra/beacon from the attacker box
- `attack/atomic/run.sh` + `techniques.yml` — Atomic Red Team runner (in-victim)
- `compose/compose.attack.yml` + `compose/attacker/` — alpine attacker + Caldera
- `scripts/detection-gap-report.ps1` — correlate a run against the alerts it produced
- Finding: with System + Network telemetry only, most prebuilt Linux rules can't
  run; custom rules + the Windows victim close the gap (see detection-coverage.md)

### Verified (M3/M4)
- Custom rules fire on real attack telemetry: SSH brute force, brute-force
  success sequence, new local user, privileged-group add, crontab replace,
  outbound beaconing

### Added — M2 (telemetry)
- `compose/compose.telemetry.yml` + `compose/victim-linux/`: an Ubuntu victim
  container (SSH, rsyslog) running a Fleet-managed Elastic Agent — System logs,
  System metrics, and Network Packet Capture
- `compose/config/kibana.yml`: Linux/Windows victim agent policies as code;
  default Fleet output pointed at the container
- `scripts/setup-fleet.ps1`: fetches per-policy enrollment tokens into `.env`
- `scripts/enable-detection-rules.ps1`: installs the 1.9k prebuilt rules, enables
  a curated ~90 (Linux / Network / Windows tags) sized for an 8 GB host
- `scripts/healthcheck.ps1`: now also reports rule count + data-stream count
- `vm/provision/*.ps1`: Windows victim provisioning (audit policy, Sysmon,
  agent enroll, Atomic Red Team) — run on a VirtualBox VM or the host
- Refactored core one-shots: `setup` (certs) + `configure` (kibana_system
  password) as separate steps so a re-`up` never wedges on a stopped one-shot

### Verified
- 2 agents online, 29 data streams, real failed-SSH logins parsed to ECS in
  `logs-system.auth-default`

### Added — M1 (Elastic core)
- `compose/docker-compose.yml`: `sysctl` + `setup` one-shots, single-node
  Elasticsearch (security + TLS), Kibana (HTTPS), Fleet Server
- `compose/config/setup.sh`: idempotent CA + PEM certificate generation and
  `kibana_system` password setup
- `scripts/bootstrap.ps1` / `.sh`: pre-flight (Docker, memory), `.env` generation
  with random secrets, bring-up, wait-for-green
- Runners now pass `--env-file .env` (Compose's project dir defaults to `compose/`)
- `.env.example`: pinned `STACK_VERSION=8.19.20`, resource caps for an 8 GB Docker VM

### Added — M0 (scaffold)
- Repository structure and Compose overlay model
- Task runners: `Makefile` and `soc.ps1`
- Documentation skeleton: architecture, threat model, scope / RoE, Windows setup
- Detection writeup and IR runbook templates
- `lint` CI workflow (markdown + YAML + actionlint)

### Next — M2
- `compose/compose.telemetry.yml`: Linux victim + Elastic Agent, Suricata / packet capture
- Fleet agent policies as code; curated prebuilt detection rules enabled

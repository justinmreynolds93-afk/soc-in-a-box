# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added — M6 (SOAR + response)
- `compose/compose.soar.yml` + `soar/n8n/soc-alert-triage.json`: webhook →
  parse alert → enrich `source.ip` (AbuseIPDB) → decide → Slack page + Kibana
  case (high) / Slack note (low)
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

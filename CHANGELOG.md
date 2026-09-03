# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

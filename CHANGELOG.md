# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added — M0 (scaffold)
- Repository structure and Compose profile model (`core` / `telemetry` / `attack` / `soar` / `casemgmt`)
- Task runners: `Makefile` and `soc.ps1` (matching verbs)
- Documentation skeleton: architecture, threat model, scope / rules of engagement, Windows setup
- Detection writeup and IR runbook templates
- `lint` CI workflow (markdown + YAML)
- `.env.example` with resource caps tuned for a 16 GB host

### Next — M1
- `compose/docker-compose.yml`: Elasticsearch + Kibana + Fleet Server, TLS, one-command bring-up

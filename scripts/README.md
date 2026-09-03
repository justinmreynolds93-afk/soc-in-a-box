# scripts/

Helper scripts. Each is self-contained and documents its own usage with `--help`.

| Script | Milestone | Purpose |
|---|---|---|
| `bootstrap.sh` / `bootstrap.ps1` | M1 | Pre-flight: check Docker, RAM, `vm.max_map_count`, `.env`; then `up` + wait for green |
| `enable-prebuilt-rules.py` | M2 | Install Elastic prebuilt rules and enable a curated subset by tag |
| `detection-gap-report.py` | M3 | Diff executed ATT&CK techniques (attack run logs) against triggered rules |
| `generate-navigator-layer.py` | M4 | Build a MITRE ATT&CK Navigator layer JSON from rule metadata |
| `replay-events.py` | M5 | Load rules into a throwaway ES, replay sample ndjson, assert signals fire |

> Scripts are added as their milestone lands; this table is the contract.

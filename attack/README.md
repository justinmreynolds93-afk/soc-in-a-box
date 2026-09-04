# attack/

Adversary emulation used to generate telemetry and prove detections fire.

> **Read [`docs/scope.md`](../docs/scope.md) first.** Everything here runs only
> against the lab's own victim VM and containers. No external targets, ever.

## `atomic/`

[Atomic Red Team](https://github.com/redcanaryco/atomic-red-team) — small,
per-technique tests.

- `Invoke-Atomic` on the Windows victim
- `atomic-operator` (Python) to orchestrate from the host
- `techniques.yml` — the curated list this lab runs, with ATT&CK IDs

## `caldera/`

[MITRE Caldera](https://github.com/mitre/caldera) — chained adversary emulation.

- `adversaries/` — profiles (e.g. "discovery + credential access", "ransomware TTPs")
- `abilities/` — any custom abilities beyond the stock plugins

## `scenarios/`

Hand-written multi-stage kill chains that tell a story end to end. Each prints
the ATT&CK techniques it runs, pauses between stages, and writes a JSONL run log
to `scenarios/runs/` for the gap report.

| Script | From | Produces |
|---|---|---|
| `linux-intrusion.sh` | host / `docker exec` | 11 techniques: brute force → valid accounts → discovery → cred access → 2× persistence → privesc → tool transfer → C2/exfil → cleanup |
| `network-recon.sh` | `attacker` container | nmap, `nmap -sV -sC`, hydra SSH spray, HTTP beacon — distinct source IP |

```bash
DWELL=25 bash attack/scenarios/linux-intrusion.sh
DWELL=25 STAGES="T1110.001 T1136.001" bash attack/scenarios/linux-intrusion.sh   # subset
```

## Output

```
pwsh scripts/detection-gap-report.ps1            # newest run
pwsh scripts/detection-gap-report.ps1 -RunLog attack/scenarios/runs/<file>.jsonl
```

Correlates executed techniques against the alerts they produced and prints an
ATT&CK coverage table + the gap list. Results and the coverage story live in
[`../docs/detection-coverage.md`](../docs/detection-coverage.md).

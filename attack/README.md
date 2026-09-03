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

Hand-written multi-stage kill chains (`bash` / `pwsh`) that tell a story end to
end: initial foothold → discovery → credential access → lateral movement →
collection → exfil / impact. Each scenario:

1. prints the ATT&CK techniques it will execute
2. runs them with pauses between stages
3. writes a run log to `scenarios/runs/` for correlating against alerts

## Output

After a run, `scripts/detection-gap-report.py` (M3) compares executed techniques
against triggered detection rules and writes the gap list that drives M4.

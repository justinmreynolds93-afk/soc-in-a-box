# Threat Model

> Skeleton — filled in through M2–M4 as detections are built. The point of the
> document is to make detection coverage a deliberate choice, not an accident of
> which rules shipped by default.

## Assets

| Asset | In the lab | Real-world analogue |
|---|---|---|
| Endpoint (workstation) | Windows victim VM | Employee laptop |
| Server | Linux victim container | App / infra host |
| Identity | Local accounts on victims | Directory accounts |
| The SOC itself | Elastic stack | SIEM — a target for evasion / tampering |

## Trust boundaries

1. Victim host ↔ Fleet Server (agent enrollment, mutual TLS)
2. Lab network ↔ host machine (VM adapter, published ports)
3. SOAR ↔ third-party enrichment APIs (egress)

## Adversary profiles emulated

| Profile | TTP focus | Tooling |
|---|---|---|
| Commodity malware | Execution, persistence, defense evasion, C2 | Atomic Red Team |
| Ransomware operator | Discovery, lateral movement, inhibit recovery, impact | Caldera + scenario scripts |
| Hands-on-keyboard intruder | Credential access, discovery, exfiltration | Attacker container |
| Insider | Collection, staging, exfiltration over web | Scenario scripts |

## In-scope ATT&CK tactics (target coverage)

Initial Access · Execution · Persistence · Privilege Escalation · Defense Evasion ·
Credential Access · Discovery · Lateral Movement · Collection · Command and Control ·
Exfiltration · Impact

Per-technique coverage is tracked in `docs/detection-coverage.md` (M4) and rendered
as a MITRE ATT&CK Navigator layer.

## Known gaps (accepted for this lab)

- **Cloud control planes.** Production data lives in SaaS (Supabase, Vercel). A
  network-tap SOC never sees it; covering it would mean shipping provider audit
  logs to Elastic — noted as a future extension, not built here.
- **macOS endpoints.** No Apple hardware in the lab.
- **Kernel-level rootkits / firmware.** Out of reach of the telemetry sources used.

## Assumptions

- The attacker starts with code execution on a victim (post-initial-access), or
  with a foothold the scenario script establishes explicitly.
- The SOC infrastructure itself is trusted and not compromised at t=0.

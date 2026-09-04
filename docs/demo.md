# Demo Walk-through

A 10-minute tour that exercises the whole loop. Assumes `.\soc.ps1 up` and
`.\soc.ps1 telemetry` are done and `scripts/healthcheck.ps1` is green.

## 1. The SIEM is up (30s)

```powershell
.\scripts\healthcheck.ps1
```
`https://localhost:5601` → Security → Overview. One Linux agent in Fleet, data
streams filling.

## 2. Detections tuned to the telemetry (1 min)

```powershell
.\scripts\enable-detection-rules.ps1     # prebuilt, index-filtered
.\scripts\deploy-detections.ps1          # 13 custom rules
```
Security → Rules: the custom rules are tagged `SOC-in-a-Box`. The Windows ones
sit in *partial failure* until the Windows victim is enrolled — that is the point
made in `docs/detection-coverage.md`.

## 3. Attack (6 min)

```bash
DWELL=25 bash attack/scenarios/linux-intrusion.sh
```
Eleven ATT&CK techniques against `linux-victim` with a run log.

## 4. Detect (2 min)

Security → Alerts — brute force, brute-force-success, new user, privileged-group
add, crontab replace, and outbound beaconing light up. Open one → Timeline →
pivot on `source.ip` / `host.name`.

## 5. The gap (1 min)

```powershell
.\scripts\detection-gap-report.ps1
.\scripts\generate-navigator-layer.ps1
```
The gap table shows which of the 11 techniques were caught and which need host
process/file telemetry (Windows victim, or Elastic Defend). Import
`docs/attack-navigator-layer.json` at the ATT&CK Navigator to see coverage.

## 6. Respond (optional)

`.\soc.ps1 soar` → import `soar/n8n/soc-alert-triage.json`, wire the Kibana
webhook connector to the custom rules. New alerts now enrich `source.ip`, post to
Slack, and open a Kibana case for the high-severity ones.

## Screenshots / GIFs

<!-- add: rules list, an alert + Timeline, the Navigator layer, an n8n run -->

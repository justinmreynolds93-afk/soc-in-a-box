# Runbook: <alert name / scenario>

| Field | Value |
|---|---|
| Trigger | `<detection rule(s) that open this runbook>` |
| Severity | `<low\|medium\|high\|critical>` |
| ATT&CK | `<tactic(s) / technique(s)>` |
| Owner | SOC analyst (L1 → L2 escalation criteria below) |

## 1. Triage (first 5 minutes)

- [ ] Confirm the alert is not a known false positive (see the detection writeup)
- [ ] Identify host, user, process, and timestamp
- [ ] Pivot in Timeline: parent/child processes, network connections, file writes

## 2. Scope

- [ ] Same technique on other hosts? (query below)
- [ ] Same user across hosts?
- [ ] Earlier stages of the kill chain present?

```kql
<scoping query>
```

## 3. Contain

- [ ] Isolate host (Elastic Defend action, or `soar/` playbook)
- [ ] Disable / reset affected account
- [ ] Block C2 indicator at the perimeter

## 4. Eradicate & recover

- [ ] Remove persistence mechanism
- [ ] Restore from known-good
- [ ] Re-image if integrity cannot be assured

## 5. Escalate to L2 when

- Confirmed hands-on-keyboard activity
- Credential access or lateral movement observed
- Any impact technique (encryption, destruction, exfiltration)

## 6. Close-out

- [ ] Case documented in Kibana
- [ ] Detection gap? → open an issue / new rule
- [ ] Runbook accurate? → update this file

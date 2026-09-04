# Runbook: SSH Brute Force (Linux)

| Field | Value |
|---|---|
| Trigger | `soc-linux-ssh-bruteforce`, escalate on `soc-linux-ssh-bruteforce-success` |
| Severity | medium (brute force) → high (successful) |
| ATT&CK | TA0006 Credential Access — T1110.001; TA0001 Initial Access — T1078 |
| Owner | SOC L1 → L2 on a successful login |

## 1. Triage (first 5 minutes)

- [ ] Open the alert. Note `source.ip`, `host.name`, count, and time window.
- [ ] `source.ip` internal or external? Check AbuseIPDB / GreyNoise (the n8n
      workflow already attached the score if enabled).
- [ ] Query for a **success** from the same `source.ip`:
      ```kql
      event.dataset:"system.auth" and event.outcome:"success" and source.ip:"<ip>"
      ```
- [ ] No success + external source → likely internet background noise. Note and move on.

## 2. Scope (if there was a success, or the source is internal)

- [ ] Which account(s) succeeded? `user.name`
- [ ] Same `source.ip` hitting other hosts?
      ```kql
      event.dataset:"system.auth" and source.ip:"<ip>" and event.outcome:"failure"
      ```
- [ ] Everything that session did: new users, sudo, cron, outbound connections
      ```kql
      host.name:"<host>" and @timestamp >= "<login time>"
      ```

## 3. Contain

- [ ] Isolate the host (Elastic Defend action if present, or pull it off the network).
- [ ] Reset the compromised account credential; invalidate active sessions
      (`pkill -KILL -u <user>`, rotate keys in `~/.ssh/authorized_keys`).
- [ ] Block `source.ip` at the perimeter.

## 4. Eradicate & recover

- [ ] Remove any persistence created in the session (see `soc-linux-new-local-user`,
      `soc-linux-cron-suspicious-command` alerts on the host).
- [ ] Rebuild if root was obtained or integrity cannot be assured.

## 5. Escalate to L2 when

- A successful login followed the brute force.
- Any persistence, privilege-escalation, or outbound-C2 alert on the same host.

## 6. Close-out

- [ ] Case documented in Kibana with `source.ip`, accounts, and actions taken.
- [ ] If the rule was noisy: tune the threshold or add a `source.ip` exception,
      and note it in `docs/detections/linux-ssh-bruteforce.md`.

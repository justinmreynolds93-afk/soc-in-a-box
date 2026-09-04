# SSH Brute Force Attempt (Linux)

| Field | Value |
|---|---|
| Rule ID | `soc-linux-ssh-bruteforce` |
| Source | `elastic/detection-rules/rules/linux_ssh_bruteforce.json` |
| ATT&CK | `T1110.001` — Password Guessing (Credential Access) |
| Data source | `logs-system.auth-*` (System integration) |
| Rule type | `threshold` |
| Severity / Risk | medium / 47 |
| Status | production |

## Hypothesis

An actor with no valid credentials will make many authentication attempts against
SSH in a short time. The System integration parses `sshd` messages from
`/var/log/auth.log` into ECS `event.category:authentication` with
`event.outcome:failure`. Counting failures per `source.ip` catches the noisy
password-guessing case that precedes most opportunistic Linux compromises.

## Logic

```
event.dataset:"system.auth" and event.category:"authentication"
  and event.outcome:"failure"
  and (event.action:("ssh_login" or "authentication_failure") or process.name:"sshd")
```

`threshold` on `source.ip` with `value: 5`, `from: now-9m`, `interval: 5m`. One
alert per source IP that crosses five failures in the window.

## Coverage & limitations

- Catches: sequential guessing, credential spraying, and dictionary attacks from
  a single host.
- Misses: **distributed** brute force (one attempt per source IP), and slow
  attacks under five per nine minutes. A `source.ip` cardinality job on
  `user.name` would complement this for the spray case.
- Depends entirely on `auth.log` being written — the victim image runs `rsyslog`
  for exactly this reason (`compose/victim-linux/`).

## False positives

| Trigger | Handling |
|---|---|
| User repeatedly mistyping a password | 5-in-9-min threshold usually filters this; raise per-host if needed |
| Backup/automation with stale credentials | Allow-list the `source.ip` via a rule exception |

## Validation

| Test | Tool | Result |
|---|---|---|
| 8 failed logins for invalid users from one host | `attack/scenarios/linux-intrusion.sh` stage `T1110.001` | alert fired within one rule interval |
| `hydra` SSH spray from the attacker container | `attack/scenarios/network-recon.sh` | alert fired, `source.ip` = attacker |

## References

- <https://attack.mitre.org/techniques/T1110/001/>
- Elastic System integration — `system.auth` dataset

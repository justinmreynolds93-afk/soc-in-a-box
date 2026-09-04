# Cron Job Created With Network or Shell Payload (Linux)

| Field | Value |
|---|---|
| Rule ID | `soc-linux-cron-suspicious-command` |
| Source | `elastic/detection-rules/rules/linux_cron_suspicious_command.json` |
| ATT&CK | `T1053.003` — Cron (Persistence) |
| Data source | `logs-system.syslog-*` |
| Rule type | `query` |
| Severity / Risk | high / 68 |
| Status | tuning |

## Hypothesis

After a foothold, actors persist by adding a cron entry that re-fetches and runs
their payload. The give-away is not "a cron job changed" (common and noisy) but
the **content**: a download-and-execute cradle or a reverse-shell one-liner.
`cron`/`crontab` activity is logged to syslog; the rule matches on suspicious
tokens in that message text.

## Logic

```
(process.name:("crontab" or "CRON" or "cron") or message:"crontab")
  and message:("curl" or "wget" or "/dev/tcp/" or "bash -i"
               or "nc -e" or "ncat" or "base64 -d" or "python -c")
```

## Coverage & limitations

- Catches: `crontab -` edits and cron execution lines that contain a network
  fetch or interpreter payload.
- Misses: payloads staged elsewhere (a script on disk referenced by an
  innocuous-looking cron line), `systemd` timers, `at` jobs, and per-file drops
  in `/etc/cron.d/` if the writing process is not `crontab`. File-integrity
  monitoring on `/etc/cron*` and `/var/spool/cron/` would close most of this —
  tracked as a gap (needs auditd/Defend).
- syslog message formats vary by distro; validated against Ubuntu 24.04.

## False positives

| Trigger | Handling |
|---|---|
| Home-grown healthcheck cron that `curl`s an endpoint | Allow-list by the exact command string or the crontab owner |
| Config-management tools writing cron entries | Exclude the management process |

## Validation

| Test | Tool | Result |
|---|---|---|
| `crontab -` adding `*/10 * * * * curl … \| bash` | `attack/scenarios/linux-intrusion.sh` stage `T1053.003` | alert fired |

## References

- <https://attack.mitre.org/techniques/T1053/003/>

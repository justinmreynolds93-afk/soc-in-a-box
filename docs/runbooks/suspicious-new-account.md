# Runbook: Suspicious Account / Persistence (Linux)

| Field | Value |
|---|---|
| Trigger | `soc-linux-new-local-user`, `soc-linux-user-added-privileged-group`, `soc-linux-cron-suspicious-command` |
| Severity | medium → high if correlated with a preceding login/brute-force |
| ATT&CK | TA0003 Persistence — T1136.001, T1053.003; TA0004 — T1098 |
| Owner | SOC L1 → L2 on correlation |

## 1. Triage

- [ ] Which host, which account/group/cron, and **which session created it**?
      Pivot on `host.name` + the minute of the alert.
- [ ] Is there a `soc-linux-ssh-bruteforce-success` or unusual login on the host
      in the preceding 30 minutes? If yes → treat as active intrusion, go to L2.
- [ ] New account with UID 0 or in `root`/`sudo`/`wheel` → high, page.

## 2. Scope

- [ ] `getent passwd`, `getent group sudo wheel root`, `crontab -l -u <user>`,
      `ls -la /etc/cron.d /etc/cron.*/ /var/spool/cron*`.
- [ ] Any `systemd` unit or timer changes? (`systemctl list-timers`,
      `find /etc/systemd /lib/systemd -newer <baseline>`).
- [ ] Outbound connections from the host to the cron callback host
      (`logs-network_traffic.flow-*`).

## 3. Contain & eradicate

- [ ] Disable the account (`usermod -L`, `chage -E0`), remove it if confirmed bad.
- [ ] Remove the cron entry / unit; capture it first for the case.
- [ ] Kill any process spawned by the persistence mechanism.

## 4. Recover

- [ ] Confirm no other persistence (authorized_keys, `.bashrc`/`.profile`,
      LD_PRELOAD, PAM modules, kernel modules).
- [ ] Rebuild if root persistence was established.

## 5. Close-out

- [ ] Document in the Kibana case.
- [ ] Feed any missed technique into `docs/detection-coverage.md` and open a
      rule task.

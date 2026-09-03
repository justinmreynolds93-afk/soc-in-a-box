# Scope & Rules of Engagement

This repository is a **personal skills and portfolio lab**. It contains offensive
tooling (Atomic Red Team, MITRE Caldera, an attacker container) used **only** to
generate telemetry for building and testing detections.

## Authorization

All adversary emulation is performed exclusively against systems the author owns
and operates for this lab:

- The Linux victim container defined in `compose/compose.telemetry.yml`
- The Windows victim VM built from `vm/` (VirtualBox, local host only)
- The lab's own Docker network (`soc-net`)

No technique in `attack/` is to be run against any host, network, account, or
service not listed above. There is no scanning, exploitation, or credential
testing against third-party or production infrastructure — including the author's
own production systems.

## Network isolation

- The lab runs on an internal Docker bridge. The Windows victim VM uses a
  host-only / NAT adapter.
- Caldera and the attacker container have **no route** to anything outside the
  lab network by design. Do not add one.
- Suricata runs in IDS (passive) mode, not IPS.

## Data handling

The SOAR playbooks in `soar/` can call third-party enrichment APIs
(VirusTotal, AbuseIPDB, GreyNoise). When enabled, these send **observed indicators
from the lab** (IPs, file hashes, domains) to those services. Keys are optional;
leave them blank in `.env` to disable enrichment entirely. Never point enrichment
at data from outside the lab.

## Teardown

```bash
make destroy        # or  .\soc.ps1 destroy
```

Removes all containers and named volumes. Delete the VirtualBox VM separately.

## Reporting

This is a solo lab; there is no disclosure process. If you fork it, keep the
authorization section accurate to *your* environment before running anything.

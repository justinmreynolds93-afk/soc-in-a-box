# vm/

The Windows victim endpoint. Windows 11 Home has no Hyper-V or Sandbox, so this
uses **VirtualBox**.

## Contents (M2)

```
vm/
├── Vagrantfile            # VirtualBox box, 4 GB RAM, host-only + NAT adapters
└── provision/
    ├── 00-base.ps1        # disable Defender sample submission, set timezone
    ├── 10-audit.ps1       # advanced audit policy, PowerShell script-block + module logging
    ├── 20-sysmon.ps1      # install Sysmon + config (Olaf Hartong modular)
    ├── 30-agent.ps1       # enroll Elastic Agent against the lab Fleet Server
    └── 40-atomics.ps1     # install Invoke-AtomicRedTeam + atomics folder
```

## Build

```bash
cd vm
vagrant up            # first run downloads the base box (~10 GB)
vagrant snapshot save clean
```

Revert between attack runs:

```bash
vagrant snapshot restore clean
```

## Without Vagrant

Build the VM by hand from a Windows Enterprise Evaluation ISO, then run the
`provision/*.ps1` scripts in order from an elevated PowerShell. See
[`../docs/windows-setup.md`](../docs/windows-setup.md).

## No-VM fallback (this repo's default for Windows telemetry)

`scripts/install-windows-telemetry.ps1` (elevated) instruments the **Docker host**
itself — Sysmon + the audit settings the rules need + a Fleet-enrolled Elastic
Agent on the Windows Victim Policy. ~400 MB RAM, no VM.

**Telemetry only** — nothing in `attack/` is ever pointed at the host (see
`docs/scope.md`). It proves the Windows detections against real data; live
attack-validation of Windows techniques still wants the VM above.

The agent reaches the lab via `host.docker.internal:8220/9200` (the Fleet default
output is set to that name so one output serves both the containers and the
host; per-policy outputs need a Platinum licence).

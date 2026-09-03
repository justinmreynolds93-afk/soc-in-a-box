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

## No-VM fallback

Instrument the host directly (Sysmon + standalone Elastic Agent) and run only the
non-destructive atomics. Lower fidelity, zero extra RAM.

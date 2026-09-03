# Windows Setup

Host used to build this: **Windows 11 Home**, 16 GB RAM, 6-core Intel Core Ultra 5,
Docker Desktop with the WSL2 backend. Notes below are specific to that setup.

## 1. Keep the repo out of OneDrive

Docker bind-mounts and volume data must not live under a synced OneDrive folder —
you will get file locks, corruption, and terrible I/O. This repo lives at
`C:\Users\JReyn\dev\soc-in-a-box`. Keep it there.

## 2. Docker Desktop

1. Install Docker Desktop, WSL2 backend (default on Home).
2. **Settings → Resources:** give it **10 GB** memory minimum, 4 CPUs, 40 GB disk.
3. **Settings → General:** "Start Docker Desktop when you sign in" is optional; the
   daemon must be running before `make up`.

### Elasticsearch `vm.max_map_count`

Elasticsearch needs `vm.max_map_count=262144` in the Linux VM that backs Docker.
On the WSL2 backend, set it persistently via `C:\Users\JReyn\.wslconfig`:

```ini
[wsl2]
kernelCommandLine = sysctl.vm.max_map_count=262144
```

Then `wsl --shutdown` and restart Docker Desktop. Verify:

```bash
docker run --rm busybox sysctl vm.max_map_count   # want: 262144
```

## 3. No `make` — use `soc.ps1`

`make` is not installed and not needed. Every Makefile target has a matching verb:

```powershell
.\soc.ps1 up
.\soc.ps1 telemetry
.\soc.ps1 status
.\soc.ps1 destroy
```

If PowerShell blocks the script: `Unblock-File .\soc.ps1`, or run with
`pwsh -File .\soc.ps1 up`.

## 4. Windows victim VM (M2+)

Windows 11 Home has **no Hyper-V and no Windows Sandbox**, so the victim runs in
**VirtualBox** (free).

1. Install VirtualBox 7.x + the Extension Pack.
2. Get a **Windows 10/11 Enterprise Evaluation** ISO from Microsoft (90-day, free) —
   or a "dev environment" VM image.
3. Build config lives in `vm/` (`Vagrantfile` + `provision/`), which installs
   Sysmon, sets the audit policy, enrolls the Elastic Agent, and installs
   Invoke-AtomicRedTeam.
4. VirtualBox and the WSL2/Hyper-V stack can coexist on recent builds but the VM
   runs slower with Hyper-V present. Acceptable for this lab.

> Alternative if VirtualBox is a problem: instrument the **host** with Sysmon +
> a standalone Elastic Agent and run only non-destructive Atomic tests. Documented
> in `attack/atomic/README.md` (M3).

## 5. First run checklist

- [ ] Docker Desktop running, 10 GB+ allocated
- [ ] `vm.max_map_count` = 262144
- [ ] `.env` created from `.env.example`, both passwords changed
- [ ] `.\soc.ps1 up` → `https://localhost:5601` loads

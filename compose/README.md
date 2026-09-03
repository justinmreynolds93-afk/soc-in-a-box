# compose/

All infrastructure-as-code for the lab. One base file plus overlay files that
each add only their own services (they are not Compose `profiles:` — you compose
them with repeated `-f` flags).

| File | Adds | Services | Status |
|---|---|---|---|
| `docker-compose.yml` | core | `sysctl`, `setup`, `elasticsearch`, `configure`, `kibana`, `fleet-server` | ✅ M1 |
| `compose.telemetry.yml` | telemetry | `linux-victim` (Ubuntu + SSH + Elastic Agent) | ✅ M2 |
| `compose.attack.yml` | attack | `caldera`, `attacker` | M3 |
| `compose.soar.yml` | soar | `n8n` | M6 |
| `compose.casemgmt.yml` | casemgmt | `thehive`, `cortex` | M6 (optional) |
| `config/` | — | `setup.sh`, Fleet policies, Suricata + Sysmon configs | M1+ |

## Raw commands

Compose's default project directory is `compose/`, so `.env` (at the repo root)
must be passed explicitly.

```bash
# core
docker compose --env-file .env -f compose/docker-compose.yml up -d

# core + telemetry
docker compose --env-file .env \
  -f compose/docker-compose.yml -f compose/compose.telemetry.yml up -d

# everything down, volumes kept
docker compose -p soc-in-a-box down

# everything down, volumes deleted
docker compose -p soc-in-a-box down -v --remove-orphans
```

`make <target>` and `.\soc.ps1 <verb>` wrap these with `--env-file .env` already set.

## Conventions

- The base file is always included; overlays only add services.
- Images are pinned via `${STACK_VERSION}` in `.env`.
- Named volumes only for stateful data — no host bind-mounts for data (OneDrive-safe).
  The one bind-mount is `config/setup.sh`, read-only.
- One user-defined network, `soc-net`.
- `sysctl` and `setup` are one-shot (`restart: "no"` / exits 0); everything else
  is long-running.

# compose/

All infrastructure-as-code for the lab. One base file plus profile overlays.

| File | Profile | Services | Status |
|---|---|---|---|
| `docker-compose.yml` | `core` | `setup`, `elasticsearch`, `kibana`, `fleet-server` | M1 |
| `compose.telemetry.yml` | `telemetry` | `suricata`, `linux-victim` | M2 |
| `compose.attack.yml` | `attack` | `caldera`, `attacker` | M3 |
| `compose.soar.yml` | `soar` | `n8n` | M6 |
| `compose.casemgmt.yml` | `casemgmt` | `thehive`, `cortex` | M6 (optional) |
| `config/` | — | service configs, Fleet agent policies, Sysmon config | M1+ |

## Raw commands (no make / soc.ps1)

```bash
# core
docker compose -f compose/docker-compose.yml up -d

# core + telemetry
docker compose -f compose/docker-compose.yml -f compose/compose.telemetry.yml up -d

# everything down, volumes kept
docker compose -p soc-in-a-box down

# everything down, volumes deleted
docker compose -p soc-in-a-box down -v --remove-orphans
```

## Conventions

- Every service sets `profiles:` so nothing starts unless its overlay is passed.
- Images are pinned to a digest or an exact tag via `${STACK_VERSION}` in `.env`.
- Named volumes only — no host bind-mounts for stateful data (OneDrive-safe).
- One user-defined network, `soc-net`.

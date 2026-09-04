# soar/n8n/

## Import the workflow

`make soar` (or `.\soc.ps1 soar`) starts n8n **and** imports
`soc-alert-triage.json` via `scripts/import-soar-workflow.ps1`. The lab runs n8n
in single-user mode (`N8N_USER_MANAGEMENT_DISABLED=true`) so there's no setup
wizard.

Then, once, in the UI (`http://localhost:5678`):

1. Add a **Basic Auth** credential (`elastic` / your `ELASTIC_PASSWORD`) and bind
   it to the *Kibana: open case* node.
2. **Activate** the workflow.

API keys and the Slack webhook are read from the environment — set them in `.env`
before `make soar` (see `.env.example`); blank keys just skip that step. The
production webhook is `http://n8n:5678/webhook/soc-alert` (from inside the lab).

## Wire Kibana to it

Kibana → Stack Management → **Connectors** → create a *Webhook* connector to
`http://n8n:5678/webhook/soc-alert` (method POST, no auth). Then either:

- add a **rule action** to the custom rules (bulk edit → add action → the webhook
  connector, on *Active* with a per-alert summary body), or
- one global action via `xpack.actions` — see `docs/runbooks/`.

## Flow

```
webhook ─► Parse Alert ─► Enrich source.ip (AbuseIPDB) ─► Decide ─► Escalate?
                                                                    ├─ yes ─► Slack page + Kibana case
                                                                    └─ no  ─► Slack note
```

`Decide` escalates when severity ≥ high, AbuseIPDB score ≥ 50, or risk ≥ 70.
Extend `Parse Alert` / `Enrich` with VirusTotal (hashes) and GreyNoise (IP noise)
the same way — the keys are already passed through.

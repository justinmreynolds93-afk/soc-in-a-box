# soar/n8n/

## Import the workflow

1. `make soar` → open `http://localhost:5678`, create the owner account.
2. Workflows → Import from File → `soc-alert-triage.json`.
3. Add a **Basic Auth** credential (`elastic` / your `ELASTIC_PASSWORD`) and bind
   it to the *Kibana: open case* node.
4. API keys and the Slack webhook are read from the environment — set them in
   `.env` before `make soar` (see `.env.example`). Blank keys just skip that step.
5. Activate the workflow. Copy the production webhook URL
   (`http://n8n:5678/webhook/soc-alert` from inside the lab network).

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

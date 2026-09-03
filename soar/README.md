# soar/

Automated response. Alerts leave Kibana as webhooks and land here.

## `n8n/`

Exported [n8n](https://n8n.io/) workflows (JSON). The core playbook:

```
Kibana detection alert (webhook)
      │
      ▼
parse alert ─► extract observables (ip, hash, domain, user, host)
      │
      ▼
enrich ─► AbuseIPDB · VirusTotal · GreyNoise      (keys optional, skipped if blank)
      │
      ▼
decision ─► severity + enrichment score
      │              │
   low/med        high/crit
      │              │
      ▼              ▼
 Slack note    Slack page + create Kibana case + (optional) Elastic Defend isolate host
```

Import: n8n → Workflows → Import from File. Credentials are configured in the n8n
UI and are **not** committed; `.env` holds the API keys the workflow reads.

## Runbooks

Human follow-up for each alert class lives in [`../docs/runbooks/`](../docs/runbooks/).

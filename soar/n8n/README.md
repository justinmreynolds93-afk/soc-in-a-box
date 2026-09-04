# soar/n8n/

`make soar` (or `.\soc.ps1 soar`) starts n8n, imports `soc-alert-triage.json`,
activates it, and restarts n8n so the schedule registers. n8n runs in single-user
mode — no setup wizard.

## How it works

Elastic **Basic** has no detection-rule connector actions (`.webhook` needs
Gold+), so the workflow **polls** instead:

```
Every 5 min ─► query Kibana for open SOC-in-a-Box alerts (last 7 min)
           ─► one item per alert
           ─► enrich source.ip (AbuseIPDB)
           ─► decide: escalate if severity ≥ high, AbuseIPDB ≥ 50, or risk ≥ 70
                ├─ escalate ─► Slack page + open a Kibana case
                └─ else     ─► Slack note
           ─► set the alert's workflow status to "acknowledged"  (dedupe)
```

A second trigger — the `soc-alert` webhook — takes a Kibana
`signals/search` response body for manual testing.

- **Kibana auth** is built inside the workflow from `ELASTIC_PASSWORD` (passed to
  the n8n container) — no n8n credential to configure.
- **AbuseIPDB / Slack** are optional: blank `ABUSEIPDB_API_KEY` /
  `SLACK_WEBHOOK_URL` in `.env` just make those nodes no-ops.

## Verify

```powershell
# feed the current open alerts straight to the workflow:
$h = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("elastic:$(( Select-String .env -Pattern '^ELASTIC_PASSWORD=(.+)').Matches.Groups[1].Value)")) }
$q = '{"size":10,"query":{"bool":{"filter":[{"range":{"@timestamp":{"gte":"now-1h"}}},{"term":{"kibana.alert.workflow_status":"open"}},{"wildcard":{"kibana.alert.rule.tags":"SOC-in-a-Box"}}]}}}'
$a = Invoke-RestMethod -Method Post https://localhost:5601/api/detection_engine/signals/search -Headers ($h + @{'kbn-xsrf'='1';'Content-Type'='application/json'}) -Body $q -SkipCertificateCheck
Invoke-RestMethod -Method Post http://localhost:5678/webhook/soc-alert -Body ($a | ConvertTo-Json -Depth 15) -ContentType application/json
```

High-severity alerts show up as cases in Kibana → Security → Cases, tagged
`soc-in-a-box`. Executions are visible at `http://localhost:5678`.

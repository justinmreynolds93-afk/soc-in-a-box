# docs/img/

Kibana screenshots for the README. The hard evidence is in
[`../verification.md`](../verification.md) (API-pulled, reproducible); these show it.

| file | page |
|---|---|
| `explore-hosts.png` | Security → Explore → Hosts — inventory built from the telemetry |

More welcome (`scripts/open-kibana.ps1` opens the useful pages): Fleet → Data
streams, the custom rules list filtered to `Custom rules (13)`, a rule detail page.

The lab CA is already trusted for the current Windows user (added to
`Cert:\CurrentUser\Root`), so `https://localhost:5601` opens clean in Chrome.
`.\scripts\open-kibana.ps1` opens the pages below; `Win`+`Shift`+`S` to grab each.

Capture after a scenario run (`bash attack/scenarios/linux-intrusion.sh`):

- `rules.png` — Security → Rules, filtered to tag `SOC-in-a-Box`
- `alerts.png` — Security → Alerts after `linux-intrusion.sh`
- `timeline.png` — one alert expanded into Timeline, pivoted on `source.ip`
- `navigator.png` — `attack-navigator-layer.json` imported at
  [mitre-attack.github.io/attack-navigator](https://mitre-attack.github.io/attack-navigator/)
- `n8n-run.gif` — a SOAR workflow execution

Kept out of the repo history until captured — this file is the placeholder.

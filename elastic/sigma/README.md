# elastic/sigma/

Vendor-neutral [Sigma](https://github.com/SigmaHQ/sigma) rules. These are the
portable source of truth for a subset of the detections; CI converts them to
Elastic query DSL on every change (`.github/workflows/detection-ci.yml`).

## Convert locally

```bash
pip install sigma-cli pysigma-backend-elasticsearch
sigma convert -t lucene -p ecs_windows elastic/sigma/rules/windows_clear_event_logs.yml
sigma convert -t eql    -p ecs_windows elastic/sigma/rules/*.yml -o build/
```

## Relationship to `../detection-rules/`

| | `sigma/rules/*.yml` | `detection-rules/rules/*.json` |
|---|---|---|
| Format | Sigma (portable) | Kibana rule body (deployable) |
| Deployed by | CI conversion → import | `scripts/deploy-detections.ps1` |
| Use | share / port to other SIEMs, show method | run in this lab |

A rule that exists in both places keeps the same intent; the JSON carries the
lab-specific tuning (thresholds, index patterns, exceptions).

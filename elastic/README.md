# elastic/

Everything that configures the SIEM, as code.

## `detection-rules/`

Custom detection rules in the layout used by Elastic's own
[`detection-rules`](https://github.com/elastic/detection-rules) toolkit.

```
detection-rules/
├── rules/     # one .toml per rule: query, metadata, ATT&CK mapping, risk score
├── tests/     # sample events (ndjson) + expected-signal assertions
└── etc/       # schema overrides, packages config
```

Workflow (M4+):

```bash
python -m pip install detection-rules
python -m detection_rules validate-all          # schema + query syntax
python -m detection_rules test                  # unit tests
python -m detection_rules kibana upload-rule     # push to the lab
```

## `sigma/`

Vendor-neutral [Sigma](https://github.com/SigmaHQ/sigma) rules plus a conversion
step to Elastic query DSL / ES|QL:

```bash
sigma convert -t esql -p ecs_windows sigma/rules/ -o build/
```

## `fleet/`

Fleet agent policies and integration settings exported as JSON, so agent config is
reproducible rather than click-configured.

## `dashboards/`

Kibana saved objects (`.ndjson`) — Security dashboards, Timelines, and data views.
Import: `POST /api/saved_objects/_import`.

# <Detection name>

| Field | Value |
|---|---|
| Rule ID | `<uuid>` |
| Source | `elastic/detection-rules/rules/<file>.toml` |
| ATT&CK | `T####` — `<technique>` (`<tactic>`) |
| Data source | `<integration / data stream>` |
| Rule type | `eql` \| `esql` \| `kql` \| `threshold` \| `new_terms` |
| Severity / Risk | `<low\|medium\|high\|critical>` / `<0–100>` |
| Status | `experimental` \| `tuning` \| `production` |

## Hypothesis

What adversary behavior this catches and why it is worth an alert. One paragraph.

## Logic

Plain-English walk-through of the query — the fields, the conditions, the window.
Paste the query itself in a fenced block.

## Coverage & limitations

Which variants of the technique this sees, and which it misses (and why).

## False positives

Known benign triggers and how they are handled (exception, tuning, or accepted).

## Validation

| Test | Tool | Result |
|---|---|---|
| `<Txxxx-N>` | Atomic Red Team / Caldera ability | alert fired in `<n>`s / did not fire |

Link to the scenario script or atomic test used.

## References

- <vendor / research links>

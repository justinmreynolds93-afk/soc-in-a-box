# Repeated Outbound Connections to a Single External Host (Beaconing)

| Field | Value |
|---|---|
| Rule ID | `soc-network-external-beaconing` |
| Source | `elastic/detection-rules/rules/network_external_beaconing.json` |
| ATT&CK | `T1071.001` — Web Protocols (Command and Control) |
| Data source | `logs-network_traffic.flow-*` (Network Packet Capture integration) |
| Rule type | `threshold` |
| Severity / Risk | medium / 47 |
| Status | tuning |

## Hypothesis

Implants check in on an interval. Even without decrypting traffic, the **flow
shape** gives it away: one internal host opening many short connections to one
external IP in a window. The Network Packet Capture integration emits a
`network_traffic.flow` document per connection with `source.ip` / `destination.ip`,
which is all the threshold needs.

## Logic

```
network.direction:("egress" or "outbound" or "external")
  or (source.ip:(10/8 or 172.16/12 or 192.168/16)
      and not destination.ip:(10/8 or 172.16/12 or 192.168/16 or 127/8))
```

`threshold` on `["source.ip","destination.ip"]` with `value: 15`,
`from: now-16m`, `interval: 10m`.

## Coverage & limitations

- Catches: fast beacons and noisy HTTP C2 (our scenario sends 8–10 POSTs in a
  row and trips it).
- Misses: **low-and-slow** beacons (one call every few minutes) and jittered
  intervals — those need a longer window plus interval-regularity or
  bytes-ratio analysis (an ML/`esql` job, not a simple threshold). Also blind to
  C2 over a shared service IP (CDN-fronted, cloud-hosted).
- No process attribution from network data alone — pivot to host telemetry on
  `source.ip`.

## False positives

| Trigger | Handling |
|---|---|
| OS / app update checks, SaaS agents, telemetry | Allow-list the destination IP or registered domain |
| DoH resolvers, NTP pools, CDN endpoints | Same |

## Validation

| Test | Tool | Result |
|---|---|---|
| 8× `curl -X POST` to a fixed external IP | `attack/scenarios/linux-intrusion.sh` stage `T1071.001` | alert fired (3 signals across runs) |
| HTTP beacon loop from attacker container | `attack/scenarios/network-recon.sh` | alert fired |

## References

- <https://attack.mitre.org/techniques/T1071/001/>

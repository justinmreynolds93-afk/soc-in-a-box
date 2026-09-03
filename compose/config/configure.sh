#!/usr/bin/env bash
# One-shot: wait for Elasticsearch, then set the kibana_system password.
# Runs after elasticsearch is healthy; kibana waits on this completing.
# Idempotent — re-running just re-sets the same password.
set -eu

CA=config/certs/ca/ca.crt
cd /usr/share/elasticsearch

echo "== waiting for Elasticsearch"
until curl -s --cacert "${CA}" https://elasticsearch:9200 | grep -q "missing authentication credentials"; do
  sleep 3
done

echo "== setting kibana_system password"
until curl -s -X POST --cacert "${CA}" \
  -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
  "https://elasticsearch:9200/_security/user/kibana_system/_password" \
  -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do
  sleep 3
done

echo "== configure complete"

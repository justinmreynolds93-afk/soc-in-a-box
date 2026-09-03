#!/usr/bin/env bash
# One-shot bootstrap for the Elastic core:
#   1. generate a private CA
#   2. issue PEM certs for elasticsearch, kibana, and fleet-server
#   3. wait for Elasticsearch, then set the kibana_system password
# Idempotent — safe to re-run; existing certs are kept.
set -eu

CERTS=config/certs
cd /usr/share/elasticsearch

if [ -z "${ELASTIC_PASSWORD:-}" ] || [ -z "${KIBANA_PASSWORD:-}" ]; then
  echo "FATAL: ELASTIC_PASSWORD and KIBANA_PASSWORD must be set (see .env)"
  exit 1
fi

if [ ! -f "${CERTS}/ca/ca.crt" ]; then
  echo "== creating CA"
  bin/elasticsearch-certutil ca --silent --pem -out "${CERTS}/ca.zip"
  unzip -o "${CERTS}/ca.zip" -d "${CERTS}"
fi

if [ ! -f "${CERTS}/elasticsearch/elasticsearch.crt" ]; then
  echo "== issuing service certificates"
  cat > "${CERTS}/instances.yml" <<'YAML'
instances:
  - name: elasticsearch
    dns: [elasticsearch, localhost]
    ip: [127.0.0.1]
  - name: kibana
    dns: [kibana, localhost]
    ip: [127.0.0.1]
  - name: fleet-server
    dns: [fleet-server, localhost]
    ip: [127.0.0.1]
YAML
  bin/elasticsearch-certutil cert --silent --pem \
    -out "${CERTS}/certs.zip" --in "${CERTS}/instances.yml" \
    --ca-cert "${CERTS}/ca/ca.crt" --ca-key "${CERTS}/ca/ca.key"
  unzip -o "${CERTS}/certs.zip" -d "${CERTS}"
fi

echo "== fixing certificate ownership / permissions"
chown -R 1000:0 "${CERTS}"
find "${CERTS}" -type d -exec chmod 750 {} \;
find "${CERTS}" -type f -exec chmod 640 {} \;

echo "== waiting for Elasticsearch to respond"
until curl -s --cacert "${CERTS}/ca/ca.crt" https://elasticsearch:9200 | grep -q "missing authentication credentials"; do
  sleep 5
done

echo "== setting the kibana_system password"
until curl -s -X POST --cacert "${CERTS}/ca/ca.crt" \
  -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" \
  "https://elasticsearch:9200/_security/user/kibana_system/_password" \
  -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do
  sleep 5
done

echo "== setup complete"

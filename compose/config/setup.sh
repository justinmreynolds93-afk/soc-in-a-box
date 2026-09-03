#!/usr/bin/env bash
# One-shot: generate a private CA and PEM certs for elasticsearch, kibana, and
# fleet-server. Idempotent — existing certs are kept. Exits 0 quickly; nothing
# downstream waits on this being "healthy", only on it completing.
set -eu

CERTS=config/certs
cd /usr/share/elasticsearch

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

echo "== certs ready"

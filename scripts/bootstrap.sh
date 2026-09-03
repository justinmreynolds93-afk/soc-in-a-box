#!/usr/bin/env bash
# Pre-flight + bring-up for the Elastic core (M1).
# Linux/macOS/WSL counterpart of bootstrap.ps1.
set -euo pipefail

cd "$(dirname "$0")/.."

info() { printf '\033[36m[*]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[+]\033[0m %s\n' "$1"; }
die()  { printf '\033[31m[!]\033[0m %s\n' "$1"; exit 1; }

info "checking Docker"
docker info >/dev/null 2>&1 || die "Docker daemon not responding. Start Docker and retry."
ok "Docker engine $(docker info --format '{{.ServerVersion}}')"

secret() { LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$1"; }

if [ ! -f .env ]; then
  info "creating .env with generated secrets"
  sed -e "s/^ELASTIC_PASSWORD=.*/ELASTIC_PASSWORD=$(secret 24)/" \
      -e "s/^KIBANA_PASSWORD=.*/KIBANA_PASSWORD=$(secret 24)/" \
      -e "s/^ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$(secret 40)/" \
      .env.example > .env
  ok ".env created (kept out of git)"
else
  ok ".env already present"
fi

info "pulling images + starting core (first run downloads ~2.5 GB)"
docker compose --env-file .env -f compose/docker-compose.yml up -d --remove-orphans

kport="$(grep -oP '^KIBANA_PORT=\K\d+' .env || echo 5601)"
info "waiting for Kibana on https://localhost:${kport}"
for _ in $(seq 1 72); do
  sleep 10
  level="$(curl -sk "https://localhost:${kport}/api/status" | grep -o '"level":"[a-z]*"' | head -1 || true)"
  echo "    kibana: ${level:-starting}"
  [ "$level" = '"level":"available"' ] && break
done
[ "$level" = '"level":"available"' ] || die "Kibana did not become available. Check: docker compose -f compose/docker-compose.yml logs"

ok "core is up"
echo
grep -E '^(ELASTIC_PASSWORD|KIBANA_PORT)=' .env | sed 's/^/  /'
echo "  Kibana: https://localhost:${kport}  (user: elastic)"
docker compose -p soc-in-a-box ps

# SOC-in-a-Box task runner.
# Windows without `make`: use  .\soc.ps1 <verb>  (same verbs), or call docker compose directly.

COMPOSE := docker compose
PROJECT := soc-in-a-box

CORE := -f compose/docker-compose.yml
TELE := -f compose/docker-compose.yml -f compose/compose.telemetry.yml
ATK  := -f compose/docker-compose.yml -f compose/compose.attack.yml
SOAR := -f compose/docker-compose.yml -f compose/compose.soar.yml
CASE := -f compose/docker-compose.yml -f compose/compose.casemgmt.yml

.DEFAULT_GOAL := help
.PHONY: help up down restart status logs telemetry telemetry-down attack attack-down \
        soar soar-down casemgmt casemgmt-down test lint destroy

help: ## List available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
	 awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

up: ## Start the Elastic core (elasticsearch, kibana, fleet-server)
	$(COMPOSE) $(CORE) up -d

down: ## Stop the core
	$(COMPOSE) $(CORE) down

restart: down up ## Restart the core

status: ## Show every lab container
	$(COMPOSE) -p $(PROJECT) ps

logs: ## Tail core logs
	$(COMPOSE) $(CORE) logs -f --tail=100

telemetry: ## Add Suricata + the Linux victim
	$(COMPOSE) $(TELE) up -d

telemetry-down: ## Remove telemetry services
	$(COMPOSE) $(TELE) stop suricata linux-victim

attack: ## Spin up Caldera + attacker (on demand)
	$(COMPOSE) $(ATK) up -d

attack-down: ## Tear down attack services
	$(COMPOSE) $(ATK) stop caldera attacker

soar: ## Start n8n
	$(COMPOSE) $(SOAR) up -d

soar-down: ## Stop n8n
	$(COMPOSE) $(SOAR) stop n8n

casemgmt: ## Start TheHive + Cortex (heavy, ~4 GB)
	$(COMPOSE) $(CASE) up -d

casemgmt-down: ## Stop TheHive + Cortex
	$(COMPOSE) $(CASE) stop thehive cortex

test: ## Run detection-rule validation + tests (M5)
	@python -m detection_rules test 2>/dev/null || echo "detection-rules tooling arrives in M4/M5"

lint: ## Lint compose + YAML
	@command -v yamllint >/dev/null 2>&1 && yamllint . || echo "yamllint not installed"

destroy: ## Stop EVERYTHING and delete volumes (DESTRUCTIVE)
	$(COMPOSE) -p $(PROJECT) down -v --remove-orphans

ANSIBLE := cd ansible &&
PLAYBOOK := ansible-playbook site.yml

.PHONY: help deps bootstrap secrets up down restart validate scan enable-backup

help:
	@echo "Homelab targets:"
	@echo "  make deps           Install required Ansible collections"
	@echo "  make bootstrap      Full converge: Docker + secrets + network + stacks"
	@echo "  make secrets        Render the SOPS bundle to secrets/* files only"
	@echo "  make up             Deploy/refresh all stacks"
	@echo "  make down           Stop all stacks"
	@echo "  make restart        Stop then deploy all stacks"
	@echo "  make enable-backup  Deploy stacks including the profile-gated backup stack"
	@echo "  make validate       Syntax-check + ansible-lint + compose/promtool/amtool/caddy/sops checks"
	@echo "  make scan           Trivy CVE scan of every pinned image (fixable HIGH/CRITICAL)"

deps:
	$(ANSIBLE) ansible-galaxy collection install -r requirements.yml

bootstrap: deps
	$(ANSIBLE) $(PLAYBOOK) --ask-become-pass

secrets:
	$(ANSIBLE) $(PLAYBOOK) --tags secrets

up:
	$(ANSIBLE) $(PLAYBOOK) --tags stacks

down:
	$(ANSIBLE) $(PLAYBOOK) --tags stacks -e stack_state=absent

restart: down up

enable-backup:
	$(ANSIBLE) $(PLAYBOOK) --tags stacks -e enable_backup=true

validate:
	$(ANSIBLE) $(PLAYBOOK) --syntax-check
	$(ANSIBLE) ansible-lint
	@for d in pihole caddy authelia nextcloud uptime-kuma diun monitoring backup; do \
		docker compose -f $$d/docker-compose.yml config -q && echo "ok: $$d"; \
	done
	docker run --rm --entrypoint promtool \
		-v $(CURDIR)/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro \
		-v $(CURDIR)/monitoring/prometheus/rules:/etc/prometheus/rules:ro \
		prom/prometheus:v3.15.0 check config /etc/prometheus/prometheus.yml
	docker run --rm --entrypoint amtool \
		-v $(CURDIR)/monitoring/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro \
		prom/alertmanager:v0.34.1 check-config /etc/alertmanager/alertmanager.yml
	docker run --rm -v $(CURDIR)/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
		caddy:2.11.4 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
	@for f in $$(git ls-files '*secrets.sops.yaml'); do \
		grep -q '^sops:' $$f && echo "encrypted: $$f" || { echo "NOT ENCRYPTED: $$f"; exit 1; }; \
	done

scan:
	./scripts/scan.sh

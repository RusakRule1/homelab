ANSIBLE := cd ansible &&
PLAYBOOK := ansible-playbook site.yml

.PHONY: help deps bootstrap secrets up down restart validate enable-backup

help:
	@echo "Homelab targets:"
	@echo "  make deps           Install required Ansible collections"
	@echo "  make bootstrap      Full converge: Docker + secrets + network + stacks"
	@echo "  make secrets        Render the SOPS bundle to secrets/* files only"
	@echo "  make up             Deploy/refresh all stacks"
	@echo "  make down           Stop all stacks"
	@echo "  make restart        Stop then deploy all stacks"
	@echo "  make enable-backup  Deploy stacks including the profile-gated backup stack"
	@echo "  make validate       Syntax-check + ansible-lint + compose config"

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

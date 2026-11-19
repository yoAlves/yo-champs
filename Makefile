# Yo Champs — the single DX and gate interface (ADR 0007).
# Every human and agent action goes through this Makefile.

SHELL := /bin/bash
.DEFAULT_GOAL := help

APP_NAME := YoChamps
BUNDLE_ID := com.yurioliveira.yochamps
ROOT := $(CURDIR)
CONFIG_DIR := $(HOME)/Library/Application Support/YoChamps
MASCOTS_DIR := $(CONFIG_DIR)/Mascots
INSTALLED_APP := $(HOME)/Applications/$(APP_NAME).app
BUNDLE := $(ROOT)/.build/$(APP_NAME).app

.PHONY: help bootstrap doctor build run demo test test-ui format lint secrets \
	mascot-validate verify ci pr-checks deploy restart stop open logs config mascots \
	install-hooks clean provider-check eval release-dry-run release \
	reset-local new-mascot tag

help: ## List targets
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Install/verify tools and resolve packages
	@./scripts/bootstrap.sh

doctor: ## Report versions, paths, config, Keychain and app state
	@./scripts/doctor.sh

build: ## Build the debug app bundle
	@./scripts/bundle.sh debug

run: build ## Build and open the debug app
	@open "$(BUNDLE)"

demo: build ## Open with MockProvider and a fixture question
	@./scripts/stop.sh
	@open "$(BUNDLE)" --args --demo

test: ## Run unit and contract tests
	@./scripts/test.sh

test-ui: ## Run XCUITest critical flow (requires full Xcode)
	@./scripts/test-ui.sh

format: ## Format Swift sources with SwiftFormat
	@swiftformat "$(ROOT)" --config "$(ROOT)/.swiftformat"

lint: ## SwiftFormat check + SwiftLint (strict)
	@./scripts/lint.sh

secrets: ## Scan the working tree for secrets with gitleaks
	@./scripts/check-secrets.sh

mascot-validate: ## Validate the default pack and local packs
	@swift run --package-path "$(ROOT)" YoChampsMascotValidator

verify: lint test build mascot-validate secrets ## Full gate: lint, test, build, pack, secrets

ci: verify provider-check ## Exactly what GitHub Actions runs

pr-checks: ## Wait for a PR's checks to finish (PR=<number>, optional TIMEOUT=<seconds>)
	@./scripts/pr-checks.sh "$(PR)" "$(or $(TIMEOUT),2400)"

deploy: ## Release build + install to ~/Applications/YoChamps.app + open (local only)
	@./scripts/deploy.sh

restart: stop open ## Stop and reopen the installed app

stop: ## Stop a running YoChamps
	@./scripts/stop.sh

open: ## Open the installed app
	@open "$(INSTALLED_APP)"

logs: ## Stream app logs
	@log stream --predicate 'subsystem == "$(BUNDLE_ID)"' --level debug --style compact

config: ## Open the config folder
	@mkdir -p "$(CONFIG_DIR)"
	@open "$(CONFIG_DIR)"

mascots: ## Open the mascot packs folder
	@mkdir -p "$(MASCOTS_DIR)"
	@open "$(MASCOTS_DIR)"

install-hooks: ## Install the pre-commit secrets/lint hook
	@./scripts/install-hooks.sh

clean: ## Remove build artifacts
	@rm -rf "$(ROOT)/.build"
	@echo "cleaned .build"

provider-check: ## Run the real streaming client against a local SSE stub
	@./scripts/provider-check.sh

eval: ## Run the eval suite (post-0.1.0 backlog)
	@echo "eval: post-0.1.0 backlog" >&2; exit 2

release-dry-run: ## Build app/DMG without signing (post-0.1.0 backlog)
	@echo "release-dry-run: post-0.1.0 backlog" >&2; exit 2

release: ## Signed/notarized release + GitHub Release (post-V0)
	@echo "release: post-V0; make deploy is the local path for now" >&2; exit 2

reset-local: ## Delete config/history/packs with confirmation (post-V0)
	@echo "reset-local: post-V0" >&2; exit 2

new-mascot: ## Scaffold a mascot pack: make new-mascot NAME=... (post-V0)
	@echo "new-mascot: post-V0" >&2; exit 2

tag: ## Create a release tag: make tag VERSION=... (post-V0)
	@echo "tag: post-V0" >&2; exit 2

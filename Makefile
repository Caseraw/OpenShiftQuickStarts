.PHONY: help validate apply delete deploy prepare reset cleanup list list-cluster status \
        component-list component-deploy component-reset component-update component-cleanup \
        components-deploy components-cleanup \
        env-check env-apply env-clean env-deploy

# SCENARIO points to a scenario directory, e.g. scenarios/example-get-started
SCENARIO ?=

# COMPONENT points to a component directory, e.g. components/demo-namespace
COMPONENT ?=

# DEPLOY_ARGS passes extra flags to env-deploy, e.g. --skip-check --skip-apply
DEPLOY_ARGS ?=

help:
	@echo "Usage: make <target> [SCENARIO=scenarios/<name>] [COMPONENT=components/<name>]"
	@echo ""
	@echo "Environment targets (run these first on a new cluster):"
	@echo "  env-deploy              Full pipeline: check → apply credentials → deploy components"
	@echo "  env-deploy --dry-run    Pre-flight check only — never modifies cluster"
	@echo "  env-deploy --skip-check Skip pre-flight (for re-runs)"
	@echo "  env-deploy --skip-apply Skip credential push (if already applied)"
	@echo "  env-check               Pre-flight validation only"
	@echo "  env-apply               Push pull secret, SSH keys, and cloud credentials to cluster"
	@echo "  env-clean               Remove env-applied cluster resources"
	@echo ""
	@echo "Visibility targets:"
	@echo "  list                    List scenarios defined in this project"
	@echo "  list-cluster            List all ConsoleQuickStart resources on the cluster"
	@echo "  list-cluster LABEL_SELECTOR=app.kubernetes.io/part-of=openshift-quickstarts"
	@echo "                          Filter cluster list to project-managed resources only"
	@echo "  status                  Compare project scenarios against what is deployed on the cluster"
	@echo "  component-list          List reusable components defined in this project"
	@echo ""
	@echo "Aggregate scenario targets (operate on all non-template scenarios):"
	@echo "  validate              Validate all scenario YAML files (syntax + required fields)"
	@echo "  apply                 Deploy all scenarios (runs each scenario's deploy.sh)"
	@echo "  delete                Remove all scenarios (runs each scenario's cleanup.sh)"
	@echo ""
	@echo "Per-scenario targets (require SCENARIO=scenarios/<name>):"
	@echo "  deploy       Apply the scenario's ConsoleQuickStart to the cluster"
	@echo "  prepare      Run the scenario's preparation script"
	@echo "  reset        Run the scenario's reset script"
	@echo "  cleanup      Run the scenario's cleanup script"
	@echo ""
	@echo "Aggregate component targets (operate on all non-template components):"
	@echo "  components-deploy     Deploy all components"
	@echo "  components-cleanup    Remove all components"
	@echo ""
	@echo "Per-component targets (require COMPONENT=components/<name>):"
	@echo "  component-deploy      Install the component on the cluster"
	@echo "  component-reset       Reset the component to its post-deploy state"
	@echo "  component-update      Re-apply the component's manifests (upgrade)"
	@echo "  component-cleanup     Remove the component and all its resources"
	@echo ""
	@echo "Examples:"
	@echo "  make status"
	@echo "  make deploy            SCENARIO=scenarios/example-get-started"
	@echo "  make prepare           SCENARIO=scenarios/example-get-started"
	@echo "  make reset             SCENARIO=scenarios/example-get-started"
	@echo "  make cleanup           SCENARIO=scenarios/example-get-started"
	@echo "  make component-deploy  COMPONENT=components/demo-namespace"
	@echo "  make component-reset   COMPONENT=components/demo-namespace"
	@echo "  make component-update  COMPONENT=components/demo-namespace"
	@echo "  make component-cleanup COMPONENT=components/demo-namespace"

# ---------------------------------------------------------------------------
# Visibility targets
# ---------------------------------------------------------------------------

# List scenarios that exist in this project (local source of truth).
list:
	@echo ""
	@echo "Scenarios in this project:"
	@echo ""
	@printf "  %-45s %s\n" "RESOURCE NAME" "DISPLAY NAME"
	@printf "  %-45s %s\n" "-------------" "------------"
	@for dir in scenarios/*/; do \
		name=$$(basename "$$dir"); \
		[ "$$name" = "_template" ] && continue; \
		qs_name=$$(grep '^ *name:' "$$dir/quickstart.yaml" 2>/dev/null | head -1 | awk '{print $$2}'); \
		display=$$(grep '^ *displayName:' "$$dir/quickstart.yaml" 2>/dev/null | head -1 | sed 's/^ *displayName: *//'); \
		printf "  %-45s %s\n" "$$qs_name" "$$display"; \
	done
	@echo ""

# List every ConsoleQuickStart installed on the cluster regardless of origin.
# Pass LABEL_SELECTOR=app.kubernetes.io/part-of=openshift-quickstarts to narrow
# the output to project-managed resources only.
LABEL_SELECTOR ?=
list-cluster:
	@echo ""
	@if [ -n "$(LABEL_SELECTOR)" ]; then \
		echo "ConsoleQuickStart resources on the cluster (filtered: $(LABEL_SELECTOR)):"; \
	else \
		echo "ConsoleQuickStart resources on the cluster (all):"; \
	fi
	@echo ""
	@if [ -n "$(LABEL_SELECTOR)" ]; then \
		oc get consolequickstarts -l "$(LABEL_SELECTOR)" \
			-o custom-columns='  RESOURCE NAME:.metadata.name,DISPLAY NAME:.spec.displayName' \
			--sort-by='.metadata.name'; \
	else \
		oc get consolequickstarts \
			-o custom-columns='  RESOURCE NAME:.metadata.name,DISPLAY NAME:.spec.displayName' \
			--sort-by='.metadata.name'; \
	fi
	@echo ""

# Compare local project scenarios against what is deployed on the cluster.
# Symbols:
#   [deployed]     scenario is in the project AND installed on the cluster
#   [not deployed] scenario is in the project but NOT yet installed on the cluster
#   [cluster-only] installed on the cluster but NOT managed by this project
status:
	@echo ""
	@echo "Quick Start status — project vs cluster"
	@echo "========================================"
	@echo ""
	@echo "Project-managed scenarios:"
	@echo ""
	@printf "  %-16s %-45s %s\n" "STATUS" "RESOURCE NAME" "DISPLAY NAME"
	@printf "  %-16s %-45s %s\n" "------" "-------------" "------------"
	@deployed=0; not_deployed=0; \
	for dir in scenarios/*/; do \
		name=$$(basename "$$dir"); \
		[ "$$name" = "_template" ] && continue; \
		qs_name=$$(grep '^ *name:' "$$dir/quickstart.yaml" 2>/dev/null | head -1 | awk '{print $$2}'); \
		display=$$(grep '^ *displayName:' "$$dir/quickstart.yaml" 2>/dev/null | head -1 | sed 's/^ *displayName: *//'); \
		if oc get consolequickstart "$$qs_name" &>/dev/null 2>&1; then \
			printf "  \033[0;32m%-16s\033[0m %-45s %s\n" "[deployed]" "$$qs_name" "$$display"; \
			deployed=$$((deployed + 1)); \
		else \
			printf "  \033[0;33m%-16s\033[0m %-45s %s\n" "[not deployed]" "$$qs_name" "$$display"; \
			not_deployed=$$((not_deployed + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "Cluster-only (installed on the cluster but not in this project):"; \
	echo ""; \
	printf "  %-16s %-45s %s\n" "STATUS" "RESOURCE NAME" "DISPLAY NAME"; \
	printf "  %-16s %-45s %s\n" "------" "-------------" "------------"; \
	cluster_only=0; \
	while IFS=$$'\t' read -r qs_name display; do \
		found=0; \
		for dir in scenarios/*/; do \
			local_name=$$(basename "$$dir"); \
			[ "$$local_name" = "_template" ] && continue; \
			local_qs=$$(grep '^ *name:' "$$dir/quickstart.yaml" 2>/dev/null | head -1 | awk '{print $$2}'); \
			[ "$$local_qs" = "$$qs_name" ] && found=1 && break; \
		done; \
		if [ "$$found" -eq 0 ]; then \
			printf "  \033[0;34m%-16s\033[0m %-45s %s\n" "[cluster-only]" "$$qs_name" "$$display"; \
			cluster_only=$$((cluster_only + 1)); \
		fi; \
	done < <(oc get consolequickstarts \
		-o custom-columns='NAME:.metadata.name,DISPLAY:.spec.displayName' \
		--sort-by='.metadata.name' --no-headers 2>/dev/null | \
		awk '{name=$$1; $$1=""; display=substr($$0,2); print name"\t"display}'); \
	echo ""; \
	echo "Summary: $$deployed deployed, $$not_deployed not deployed, $$cluster_only cluster-only."; \
	echo ""

# ---------------------------------------------------------------------------
# Aggregate targets
# ---------------------------------------------------------------------------

validate:
	./scripts/validate.sh

apply:
	@for dir in scenarios/*/; do \
		[ "$$(basename "$$dir")" = "_template" ] && continue; \
		bash "$$dir/scripts/deploy.sh"; \
		echo ""; \
	done

delete:
	@for dir in scenarios/*/; do \
		[ "$$(basename "$$dir")" = "_template" ] && continue; \
		bash "$$dir/scripts/cleanup.sh"; \
		echo ""; \
	done

# ---------------------------------------------------------------------------
# Per-scenario targets
# ---------------------------------------------------------------------------

deploy:
ifndef SCENARIO
	$(error SCENARIO is required. Usage: make deploy SCENARIO=scenarios/<name>)
endif
	bash $(SCENARIO)/scripts/deploy.sh

prepare:
ifndef SCENARIO
	$(error SCENARIO is required. Usage: make prepare SCENARIO=scenarios/<name>)
endif
	bash $(SCENARIO)/scripts/prepare.sh

reset:
ifndef SCENARIO
	$(error SCENARIO is required. Usage: make reset SCENARIO=scenarios/<name>)
endif
	bash $(SCENARIO)/scripts/reset.sh

cleanup:
ifndef SCENARIO
	$(error SCENARIO is required. Usage: make cleanup SCENARIO=scenarios/<name>)
endif
	bash $(SCENARIO)/scripts/cleanup.sh

# ---------------------------------------------------------------------------
# Component visibility targets
# ---------------------------------------------------------------------------

# List components defined in this project (local source of truth).
component-list:
	@echo ""
	@echo "Components in this project:"
	@echo ""
	@printf "  %-40s %s\n" "COMPONENT" "DESCRIPTION"
	@printf "  %-40s %s\n" "---------" "-----------"
	@for dir in components/*/; do \
		name=$$(basename "$$dir"); \
		[ "$$name" = "_template" ] && continue; \
		desc=$$(awk '/^# /{found=1; next} found && /^[^[:space:]#]/{print; exit}' \
			"$$dir/README.md" 2>/dev/null | head -1 || echo "—"); \
		printf "  %-40s %s\n" "$$name" "$${desc:-—}"; \
	done
	@echo ""

# ---------------------------------------------------------------------------
# Aggregate component targets
# ---------------------------------------------------------------------------

components-deploy:
	@for dir in components/*/; do \
		[ "$$(basename "$$dir")" = "_template" ] && continue; \
		bash "$$dir/scripts/deploy.sh"; \
		echo ""; \
	done

components-cleanup:
	@for dir in components/*/; do \
		[ "$$(basename "$$dir")" = "_template" ] && continue; \
		bash "$$dir/scripts/cleanup.sh"; \
		echo ""; \
	done

# ---------------------------------------------------------------------------
# Per-component targets
# ---------------------------------------------------------------------------

component-deploy:
ifndef COMPONENT
	$(error COMPONENT is required. Usage: make component-deploy COMPONENT=components/<name>)
endif
	bash $(COMPONENT)/scripts/deploy.sh

component-reset:
ifndef COMPONENT
	$(error COMPONENT is required. Usage: make component-reset COMPONENT=components/<name>)
endif
	bash $(COMPONENT)/scripts/reset.sh

component-update:
ifndef COMPONENT
	$(error COMPONENT is required. Usage: make component-update COMPONENT=components/<name>)
endif
	bash $(COMPONENT)/scripts/update.sh

component-cleanup:
ifndef COMPONENT
	$(error COMPONENT is required. Usage: make component-cleanup COMPONENT=components/<name>)
endif
	bash $(COMPONENT)/scripts/cleanup.sh

# ---------------------------------------------------------------------------
# Environment targets
# ---------------------------------------------------------------------------

env-deploy:
	bash environment/scripts/deploy.sh $(DEPLOY_ARGS)

env-check:
	bash environment/scripts/check.sh

env-apply:
	bash environment/scripts/apply.sh

env-clean:
	bash environment/scripts/clean.sh

env-import-spokes:
	bash environment/scripts/import-spokes.sh

TARGETS := $(shell ls scripts|grep -ve "^util-\|^pull-scripts")

# Default behavior for targets
$(TARGETS):
	./scripts/$@

.DEFAULT_GOAL := default

# Charts Build Scripts
pull-scripts:
	./scripts/pull-scripts

remove:
	./scripts/remove-asset

rebase:
	./scripts/charts-build-scripts/rebase

dev-prepare: pull-scripts
	@./bin/charts-build-scripts prepare --soft-errors --debug

dev-prepare-cached: pull-scripts
	@./bin/charts-build-scripts prepare --soft-errors --debug --useCache

prepare-cached: pull-scripts
	@./bin/charts-build-scripts prepare --useCache

patch-cached: pull-scripts
	@./bin/charts-build-scripts patch --useCache

charts-cached: pull-scripts
	@./bin/charts-build-scripts charts --useCache

CHARTS_BUILD_SCRIPTS_TARGETS := prepare patch clean clean-cache charts list index unzip zip standardize template

$(CHARTS_BUILD_SCRIPTS_TARGETS): pull-scripts
	@./bin/charts-build-scripts $@

.PHONY: $(TARGETS) $(CHARTS_BUILD_SCRIPTS_TARGETS) list

list-make:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'
# IMPORTANT: The line above must be indented by (at least one)
#            *actual TAB character* - *spaces* do *not* work.

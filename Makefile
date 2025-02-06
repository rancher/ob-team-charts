TARGETS := $(shell ls scripts|grep -ve "^util-")

# Default behavior for targets
$(TARGETS):
	./scripts/$@

.DEFAULT_GOAL := default

rebase:
	./scripts/charts-build-scripts/rebase

dev-prepare:
	@./make pull-scripts
	@./bin/charts-build-scripts prepare --soft-errors

dev-prepare-cached:
	@./make pull-scripts
	@./bin/charts-build-scripts prepare --soft-errors --useCache

prepare-cached:
	@./make pull-scripts
	@./bin/charts-build-scripts prepare --useCache

patch-cached:
	@./make pull-scripts
	@./bin/charts-build-scripts patch --useCache

charts-cached:
	@./make pull-scripts
	@./bin/charts-build-scripts charts --useCache

CHARTS_BUILD_SCRIPTS_TARGETS := prepare patch clean clean-cache charts list index unzip zip standardize template

$(CHARTS_BUILD_SCRIPTS_TARGETS):
	@./make pull-scripts
	@./bin/charts-build-scripts $@

.PHONY: $(TARGETS) $(CHARTS_BUILD_SCRIPTS_TARGETS) list

list-make:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'
# IMPORTANT: The line above must be indented by (at least one)
#            *actual TAB character* - *spaces* do *not* work.

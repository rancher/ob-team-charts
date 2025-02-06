TARGETS := $(shell ls scripts|grep -ve "^util-")

# Default behavior for targets
$(TARGETS):
	./scripts/$@

.DEFAULT_GOAL := default

.PHONY: $(TARGETS) list-make

list-make:
	@LC_ALL=C $(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/(^|\n)# Files(\n|$$)/,/(^|\n)# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | grep -E -v -e '^[^[:alnum:]]' -e '^$@$$'
# IMPORTANT: The line above must be indented by (at least one)
#            *actual TAB character* - *spaces* do *not* work.

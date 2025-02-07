TARGETS := $(shell ls scripts|grep -ve "^util-")

# Ensure mage is installed and run make within ./mage unless ob-charts-make exists in CWD
check-mage:
	@if [ ! -x "./ob-charts-make" ]; then \
		if ! command -v mage >/dev/null 2>&1; then \
			echo "Error: mage is not installed." >&2; exit 1; \
		fi; \
		cd ./mage && make; \
	fi

# Default behavior for targets
$(TARGETS): check-mage
	@./ob-charts-make call $@

help:
	@./ob-charts-make help

.DEFAULT_GOAL := help

.PHONY: $(TARGETS)

# Fallback rule for any other target that is not in $(TARGETS)
%: check-mage
	@if [ -f "$@" ]; then \
  		if [ -z $DEBUG ]; then \
			echo "Skipping '$@' because it exists as a file."; \
		fi \
	elif ! echo "$(TARGETS)" | grep -q "\<$@\>"; then \
		./ob-charts-make $@; \
	else \
		echo "Target '$@' is already handled explicitly."; \
	fi

TMPDIR ?= /tmp
export ELBY_TEMP_DIR := $(TMPDIR)

TESTS ?= $(sort $(shell /bin/ls tests))
TEST_PATHS := $(TESTS:%=tests/%)

test: $(TEST_PATHS)

$(TEST_PATHS):
	@echo
	@echo "Running test: $@"
	ruby $@/test.rb

.PHONY: test $(TEST_PATHS)

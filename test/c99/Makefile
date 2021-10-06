
TMPDIR := /tmp
TESTS := $(sort $(shell find tests -name "test.rb"))

test:
	for test in $(TESTS) ; do echo "Running test: $$test" && ELBY_TEMP_DIR=$$TMPDIR ruby $$test ; done

.PHONY: test

BIN_DIR := $(PWD)/zig-out/bin
DOCKER := podman

all: build test

build:
	zig build

install:
	zig build install

test: build
	zig build test
	@PATH=$(BIN_DIR):$(PATH) ; make -C test/c99 test

test-inspect: build
	zig build test
	@PATH=$(BIN_DIR):$(PATH) ; make -C test/c99 test TMPDIR=$(PWD)/.test-out/c

test-docker: build
	$(DOCKER) build -t elby/base -f Dockerfile
	$(DOCKER) build -t elby/tests/c -f test/c99/Dockerfile
	$(DOCKER) run -it --network none elby/tests/c

clean:
	rm -rf zig-cache
	rm -rf zig-out
	rm -rf .test-out

.PHONY: all build install test test-inspect test-docker clean

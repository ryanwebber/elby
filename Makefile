BIN_DIR := $(PWD)/zig-out/bin
DOCKER := podman

all: build test

build:
	zig build

install:
	zig build install

test:
	zig build test
	@PATH=$(BIN_DIR):$(PATH) ; make -C test/c99 test

test-docker: build
	$(DOCKER) build -t elby/base -f Dockerfile
	$(DOCKER) build -t elby/tests/c -f test/c99/Dockerfile
	$(DOCKER) run -it --network none elby/tests/c

.PHONY: all build install test test-docker

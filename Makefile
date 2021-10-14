BIN_DIR := $(PWD)/zig-out/bin
DOCKER := podman

NPM := npm
PARSER_SOURCE := lib/parser

all: build test

build:
	zig build

install:
	zig build install

test: test-unit test-compiler-inspect

test-unit:
	zig build test

test-compiler:
	@PATH=$(BIN_DIR):$(PATH) ; make -C test/c99 test

test-compiler-inspect:
	@PATH=$(BIN_DIR):$(PATH) ; make -C test/c99 test TMPDIR=$(PWD)/.test-out/c

# Parser

parser: generate-parser test-parser

generate-parser:
	$(NPM) install --prefix $(PARSER_SOURCE)
	$(NPM) run --prefix $(PARSER_SOURCE) generate

test-parser: parser
	$(NPM) run --prefix $(PARSER_SOURCE) test

# Docker

docker-bootstrap:
	$(DOCKER) build -t elby/base -f Dockerfile
	$(DOCKER) build -t elby/tests/c -f test/c99/Dockerfile

clean:
	rm -rf zig-cache
	rm -rf zig-out
	rm -rf .test-out

.PHONY: all build install test test-unit test-compiler test-compiler-inspect docker-bootstrap clean

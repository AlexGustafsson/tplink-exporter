# Disable echoing of commands
MAKEFLAGS += --silent

# Add build-time variables
PREFIX := $(shell go list ./internal/version)
VERSION := v0.1.0
COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null)
GO_VERSION := $(shell go version)
COMPILE_TIME := $(shell LC_ALL=en_US date)

BUILD_VARIABLES := -X "$(PREFIX).Version=$(VERSION)" -X "$(PREFIX).Commit=$(COMMIT)" -X "$(PREFIX).GoVersion=$(GO_VERSION)" -X "$(PREFIX).CompileTime=$(COMPILE_TIME)"
BUILD_FLAGS := -ldflags '-s -w $(BUILD_VARIABLES)'

server_source := $(shell find . -type f -name '*.go')

# Force macOS to use clang
# https://gcc.gnu.org/bugzilla/show_bug.cgi?id=93082
# https://bugs.llvm.org/show_bug.cgi?id=44406
# https://openradar.appspot.com/radar?id=4952611266494464
ifeq ($(shell uname),Darwin)
	CC=clang
endif

.PHONY: help build build-docker release build-specified format lint test clean

# Produce a short description of available make commands
help:
	pcregrep -Mo '^(#.*\n)+^[^# ]+:' Makefile | sed "s/^\([^# ]\+\):/> \1/g" | sed "s/^#\s\+\(.\+\)/\1/g" | GREP_COLORS='ms=1;34' grep -E --color=always '^>.*|$$' | GREP_COLORS='ms=1;37' grep -E --color=always '^[^>].*|$$'

# Build for the native platform
build: build/tp-link-exporter

# Build for docker
build-docker:
	docker build -t tp-link-exporter:latest -t tp-link-exporter:$(VERSION) .

# Package for release
release:
	GOOS=darwin GOARCH=amd64 $(MAKE) build-specified
	GOOS=darwin GOARCH=arm64 $(MAKE) build-specified
	GOOS=linux GOARCH=amd64 $(MAKE) build-specified
	GOOS=linux GOARCH=arm64 $(MAKE) build-specified
	GOOS=windows GOARCH=amd64 $(MAKE) build-specified
	GOOS=windows GOARCH=arm64 $(MAKE) build-specified

# Format Go code
format: $(server_source) Makefile
	gofmt -l -s -w .

# Lint Go code
lint: $(server_source) Makefile
	golint .

# Vet Go code
vet: $(server_source) Makefile
	go vet ./...

# Test Go code
test: $(server_source) Makefile
	go test -v ./...

# Build for the native platform
build/tp-link-exporter: $(server_source) Makefile
	CGO_ENABLED=0 go build $(BUILD_FLAGS) -o $@ cmd/*.go

# Build for the specified platform
build-specified: build/tp-link-exporter-$(GOOS)-$(GOARCH)
	tar -czf build/tp-link-exporter-$(GOOS)-$(GOARCH).tgz build/tp-link-exporter-$(GOOS)-$(GOARCH)

# Build for the specified platform
build/tp-link-exporter-$(GOOS)-$(GOARCH):
	CGO_ENABLED=0 go build $(BUILD_FLAGS) -o $@ cmd/*.go

# Clean all dynamically created files
clean:
	rm -rf ./build &> /dev/null || true

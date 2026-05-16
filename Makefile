# Makefile for coredns
# Provides common build, test, and development targets

BINARY    := coredns
GOFLAGS   :=
HOOKS     := $(wildcard plugin/*/)
GO        := go
GOOS      ?= $(shell go env GOOS)
GOARCH    ?= $(shell go env GOARCH)
GOVERSION := $(shell go version | awk '{print $$3}')
VERSION   := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
GITCOMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILDDATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LDFLAGS := -ldflags "-s -w \
	-X github.com/coredns/coredns/coremain.GitCommit=$(GITCOMMIT) \
	-X github.com/coredns/coredns/coremain.Version=$(VERSION)"

.PHONY: all build clean test lint fmt vet docker release

## all: Build the binary
all: build

## build: Compile the coredns binary
build:
	@echo "Building $(BINARY) $(VERSION) ($(GITCOMMIT)) for $(GOOS)/$(GOARCH)..."
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $(BINARY) .

## build-linux: Cross-compile for Linux amd64
build-linux:
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) $(LDFLAGS) -o $(BINARY)-linux-amd64 .

## test: Run all unit tests
test:
	@echo "Running tests..."
	$(GO) test ./... -v -count=1

## test-race: Run tests with race detector
test-race:
	$(GO) test -race ./... -count=1

## lint: Run golangci-lint
lint:
	@which golangci-lint > /dev/null 2>&1 || (echo "golangci-lint not found, install via: curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh" && exit 1)
	golangci-lint run ./...

## fmt: Format Go source code
fmt:
	$(GO) fmt ./...

## vet: Run go vet
vet:
	$(GO) vet ./...

## clean: Remove build artifacts
clean:
	@echo "Cleaning..."
	rm -f $(BINARY) $(BINARY)-linux-amd64
	rm -f coverage.out

## coverage: Generate test coverage report
coverage:
	$(GO) test ./... -coverprofile=coverage.out -covermode=atomic
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

## docker: Build Docker image
docker:
	docker build -t coredns:$(VERSION) .

## docker-push: Push Docker image to registry
docker-push: docker
	docker push coredns:$(VERSION)

## release: Build release binaries for multiple platforms
release:
	GOOS=linux   GOARCH=amd64  $(GO) build $(LDFLAGS) -o release/$(BINARY)-linux-amd64 .
	GOOS=linux   GOARCH=arm64  $(GO) build $(LDFLAGS) -o release/$(BINARY)-linux-arm64 .
	GOOS=darwin  GOARCH=amd64  $(GO) build $(LDFLAGS) -o release/$(BINARY)-darwin-amd64 .
	GOOS=darwin  GOARCH=arm64  $(GO) build $(LDFLAGS) -o release/$(BINARY)-darwin-arm64 .
	GOOS=windows GOARCH=amd64  $(GO) build $(LDFLAGS) -o release/$(BINARY)-windows-amd64.exe .

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'

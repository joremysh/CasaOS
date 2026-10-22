.PHONY: help generate build test lint fmt clean

# service/ only builds on Linux, so build and vet target Linux even on macOS.
GOARCH ?= $(shell go env GOARCH)
# Both codegen files come from the same go generate run; track one of them.
CODEGEN = codegen/casaos_api.go

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

generate: ## Regenerate OpenAPI code into codegen/
	go generate

$(CODEGEN): api/casaos/openapi.yaml
	go generate

build: $(CODEGEN) ## Build a Linux binary at dist/casaos (GOARCH=amd64|arm64 to override)
	GOOS=linux GOARCH=$(GOARCH) CGO_ENABLED=0 go build -o dist/casaos .

test: ## Run the test suite in a Linux container (see docker-compose.yml)
	docker compose run --rm test

lint: $(CODEGEN) ## Run go vet and check gofmt
	GOOS=linux go vet ./...
	@out=$$(gofmt -l .); if [ -n "$$out" ]; then echo "gofmt needed:"; echo "$$out"; exit 1; fi

fmt: ## Format Go files with gofmt
	gofmt -w .

clean: ## Remove build output
	rm -rf dist

.PHONY: api test lint db-up db-down local-up local-seed local-api local-smoke local-backup local-check

api:
	cd backend && go run -mod=mod ./cmd/api

test:
	cd backend && go test -mod=mod ./...

lint:
	cd backend && go vet -mod=mod ./...

db-up:
	docker compose up -d mysql redis minio

db-down:
	docker compose down

# Local stack (development only; see config/env/README.md and scripts/local.sh)
local-up:
	scripts/local.sh up
local-seed:
	scripts/local.sh seed
local-api:
	scripts/local.sh api
local-smoke:
	scripts/local.sh smoke
local-backup:
	scripts/local.sh backup
local-check:
	scripts/check-config.sh

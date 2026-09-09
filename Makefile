.PHONY: api test lint db-up db-down

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

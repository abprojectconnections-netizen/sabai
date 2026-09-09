# Phase 1 architecture

The Flutter client calls versioned REST endpoints at `/api/v1`. WebSocket events are added behind the same API gateway when chat and live tracking move beyond their REST foundations.

The Go/Gin application follows domain boundaries. HTTP controllers validate transport data, services own business workflows and transactions, repositories own MySQL queries, and Redis and object storage stay behind infrastructure adapters.

MySQL is the source of truth. Redis supports cache, rate limits, sessions, locks, and queues. MinIO provides S3-compatible storage for documents and media. Payment gateways and OAuth providers are integrated through provider-specific adapters so credentials and webhook verification remain isolated.

The delivery baseline is Docker Compose for local development and GitHub Actions for Go checks. Production adds TLS at the edge, managed secrets, database backup verification, Prometheus metrics, Grafana dashboards, and alerting.

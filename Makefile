# Makefile for Financial Data Lake Platform

.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make setup   - Set up development environment"
	@echo "  make start   - Start all services"
	@echo "  make stop    - Stop all services"
	@echo "  make restart - restart all services"
	@echo "  make clean   - Clean up generated files"
	@echo "  make test    - Run tests"
	@echo "  make lint    - Run linting"
	@echo "  make format  - Format code"
	@echo "  make build   - Build Docker images"
	@echo "  make deploy  - Deploy to production"
	@echo "  make logs    - Show logs"
	@echo "  make health  - Health check to all services"


# Environment setup
.PHONY: setup
setup:
	python -m venv venv
	. venv/bin/activate && pip install -r requirements.txt
	. venv/bin/activate && pip install -r requirements-dev.txt
	pre-commit install
	@echo "✅ Development environment ready!"

# Docker commands
.PHONY:start
start:
	docker compose up -d
	@echo "✅ All services started!"
	@echo "Waiting for services to be healthy..."
	@sleep 10
	@make health

.PHONY: stop
stop:
	docker compose down
	@echo "✅ All services stopped!"

.PHONY: restart
restart: stop start

.PHONY: build
build:
	docker compose build --no-cache
	@echo "✅ All images built!"

.PHONY: logs
logs:
	docker compose logs -f

# Development commands
.PHONY: test
test:
	pytest tests/ -v --cov=src --cov-report=html --cov-report=term

.PHONY: test-integration
test-integration:
	pytest tests/integration/ -v -m integration

.PHONY: test-e2e
test-e2e:
	pytest tests/e2e/ -v -m e2e

.PHONY: lint
lint:
	black --check src/ tests/
	flake8 src/ tests/
	mypy src/
	pylint src/

.PHONY: format
format:
	black src/ tests/
	isort src/ tests/

# Data operations
.PHONY: ingest-sample
ingest-sample:
	python scripts/ingest_sample_data.py
	@echo "✅ Sample data ingested!"

.PHONY: run-batch
run-batch:
	python -m src.processing.batch_pipeline
	@echo "✅ Batch processing completed!"

.PHONY: run-streaming
run-streaming:
	python -m src.processing.stream_pipeline
	@echo "✅ Streaming processing started!"

# Health checks
.PHONY: health
health:
	@echo "Checking service health..."
	@curl -f http://localhost:9001/minio/health/live > /dev/null 2>&1 && echo "✅ MinIO: Healthy" || echo "❌ MinIO: Unhealthy"
	@curl -f http://localhost:8080 > /dev/null 2>&1 && echo "✅ Spark: Healthy" || echo "❌ Spark: Unhealthy"
	@curl -f http://localhost:8081 > /dev/null 2>&1 && echo "✅ Kafka: Healthy" || echo "❌ Kafka: Unhealthy"
	@curl -f http//localhost:8082/health > /dev/null 2>&1 && echo "✅ Airflow: Healthy" || echo "❌ Airflow: Unhealthy"
	@curl -f http://localhost:5000/health > /dev/null 2>&1 && echo "✅MLflow: Healthy" || echo "❌ MLflow: Unhealthy"

# Cleanup
.PHONY: clean
clean:
	find . -type d -name "__pycache__" -exec rm -r {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name ".coverage" -delete
	rm -rf htmlcov/
	rm -rf .pytest_cache/
	rm -rf .mypy_cache/
	docker-compose down -v
	@echo "✅ Cleanup complete!"

# Deployment
.PHONY: deploy-dev
deploy-dev:
	@echo "Deploying to development environment..."
	docker compose -f docker-compose.yml -f docker compose.dev.yml up -d

.PHONY: deploy-prod
deploy-prod:
	@echo "Deploying to production environment..."
	docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Documentation
.PHONY: docs
docs:
	@echo "Building documentation..."
	cd docs && mkdocs build

.PHONY: docs-serve 
docs-serve:
	@echo "Serving documentation..."
	cd docs && mkdocs serve
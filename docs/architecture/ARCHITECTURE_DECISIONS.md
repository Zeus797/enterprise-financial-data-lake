# Architecture Design & Desicions

## Table of Contents
1. [System Overview](#system-overview)
2. [Core Principles](#core-principles)
3. [Technology Selection Rationale](#technology-selection-rationale)
4. [Data Flow Architecture](#data-flow-architecture)
5. [Design Patterns](#design-patterns)
6. [Trade-offs & Alternatives Considered](#trade-offs)

## System Overview

We're building a **Lambda Architecture** - combining batch and realtime processing to handle financial data at scale. This architecture enables both historical analysis and real-time data insights.

### Why Lambda Architecture?
- **Batch Layer**: Handles large-scale historical processing (accuracy)
- **Speed Layer**: Process real-time data (low latency)
- **Serving Layer**: Combines both for complete view

## Core Principles

### 1. **Scalability First**
Every component must handle 10x current load without redesign.

### 2. **Cloud-Native but Portable**
While using cloud patterns, avoid vendor lock-in.

### 3. **Schema Evolution**
Data schemas will change; design for backward compatibility

### 4. **Cost Optimization**
Use open-source where possible, optimize storage with compression and partitioning

### 5. **Developer Experience**
Local development should mirror production

## Technology Selection Rationale

### Storage Layer: MinIO (S3-Compatible)
**Why MinIO over alternatives?**
- **S3 API compatibility**: Can switch to AWS S3 without code changes
- **On-premise option**: Can run anywhere (cloud/local/hybrid)
- **High performance**: Better throughput than HDFS for our use case
- **Simple operations**: No complex cluster management like HDFS

**Alternatives considered:**
- **HDFS**: Operational complexity, declining adoption
- **AWS S3**: Vendor lock-in, can't run locally
- **Azure Blob**: Vendor lock-in, less ecosystem support

### Processing Layer: Apache Spark
**Why Spark?**
- **Unified engine**: Same API for batch and streaming
- **SQL support**: Analysts can use familiar SQL
- **ML Libraries**: Built-in MLlib for data science
- **Perfomance**: In-memory processing, catalyst optimizer

**Alternatives considered:**
- **Flink**: Better for streaming, but weak batch processing
- **Presto/Trino alone**: Query only, no processing capabilities
- **Dask**: Less mature ecosystem, smaller community

### Streaming Layer: Apache Kafka
**Why Kafka?**
- **Industry standard**: Massive adoption in finance
- **Durability**: Persistent message storage
- **Throughput**: Handles million of messages/second
- **Ecosystem**: Kafka Connect, Streams, Schema Registry

**Alternatives considered:**
- **Pulsar**: Better features but less adoption
- **RabbitMQ**: Not built for streaming use cases
- **Kinesis**: AWS lock-in

### Table Format: Apache Iceberg
**Why Iceberg?**
- **ACID transactions**: Critical for financial data
- **Time travel**: Query data as of any point in time
- **Schema evolution**: Add/drom/rename columns safely
- **Partition evolution**: Change partitioning without rewriting
- **Multi-engine support**: Works with Spark, Trino, Flink

**Alternatives considered:**
- **Delta Lake**: Spark-centric, less engine support
- **Hudi**: More complex, primarily for upsert
- **Raw Parquet**: No transactions or schema evolution

### Query Engine: Trino
**Why Trino?**
- **Federation**: Query multiple data sources
- **Performance**: Optimized for analytics queries
- **Separation of compute/storage**: Scale independently
- **Standard SQL**: Analysts already know it

**Alternatives considered:**
- **Athena**: AWS-only
- **BigQuery**: GCP-only
- **Impala**: Tightly coupled to HDFS

### Orchestration: Apache Airflow
**Why Airflow?**
- **Mature**: Battle-tested in production
- **Python-native**: Same language as our processing
- **UI**: Excellent monitoring and debugging
- **Extensible**: Custom operators for any task

**Alternatives considered:**
- **Prefect**: Less mature, smaller community
- **Dagster**: Too opinionated for our needs
- **Argo Workflows**: K8s-only, less feature rich

### ML Platform: MLflow
**Why MLflow?**
- **Open source**: No vendor lock-in
- **Comprehensive**: Tracking, registry, deployment
- **Framework agnostic**: Works with any ML library
- **Integration**: Works well with Spark MLlib

**Alternatives considered:**
- **Kubeflow**: Kubernetes complexity
- **Sagemaker**: AWS lock-in
- **Vertex AI**: GCP lock-in

## Data Flow Architecture

### Layer 1: Data Ingestion
```
[External APIs] --> [Kafka Producers] --> [Kafka Topics]
    ↓
[File Uploads] --> [NiFi/Scripts] --> [Bronze Layer]
```

**Design Decisions:**
- **Kafka for streaming**: Guarantees order, handles backpressure
- **Direct to Bronze for files**: Simple, preserves raw data
- **Schema Registry**: Enforce contracts, enable evolution

### Layer 2: Data Storage (Medallion Architecture)

```
┌─────────────────────────────────────────┐
│          BRONZE LAYER                   │
│       - Raw, Immutable data             │
│       - Source system format            │
│       - Partitioned by ingestion date   │
│       - Retention: 7 years              │
└─────────────────────────────────────────┘
                    ↓

┌─────────────────────────────────────────┐
│          SILVER LAYER                   │
│       - Cleaned, deduplicated           │
│       - Standardized schema             │
│       - Partitioned by business date    │
│       - Retention: years                │
└─────────────────────────────────────────┘
                    ↓

┌─────────────────────────────────────────┐
│          GOLD LAYER                     │
│       - Aggregated metrics              │
│       - ML Features                     │
│       - Report-ready data               │
│       - Partitioned by query patterns   │
│       - Retention: 1 years              │
└─────────────────────────────────────────┘
```

**Why Medallion Architecture?**
- **Bronze**: Debugging, reprocessing, compliance
- **Silver**: Single ource of truth for analytics
- **Gold**: Performance optimization for queries

### Layer 3: Processing Patterns

#### Batch Processing
```
Bronze ---> [Spark Batch Job] ---> Silver
Silver ---> [Spark SQL] ---> Gold
```

- Runs every hour for completeness
- Handles late-arriving data
- Complex aggregations

#### Stream Processing
```
Kafka ---> [Spark Structured Streaming] ---> Silver(Realtime) ---> Gold(Aggregates)
```

- Sub-second latency for critical metrics
- Windowed aggregations
- Exactly once semantics

### Layer 4: Serving Layer

```
                          ┌──→ [BI Tools]
Gold Layer ───────────────┼──→ [REST APIs]
                          └──→ [ML Models]
```

## Design Patterns

### 1. **Event Sourcing**
All changes are captured as events in Kafka, enabling:
- Complete audit trail
- Replay capability
- Event driven architecture

### 2. **CQRS (Command Query Responsibility Segregation)**
- **Commands**: Write to Kafka/Bronze
- **Queries**: Read from Gold/Serving layer
- Optimized for different access patterns

### 3. **Slowly Changing Dimensiona (SCD Type 2)**
Track historical changes in dimension tables:

```sql
CREATE TABLE customers (
    customer_id BIGINT,
    name STRING,
    email STRING,
    valid_from TIMESTAMP,
    valid_to TIMESTAMP,
    is_current BOOLEAN,
)
```

### 4. **Partitioning Strategy**
```python
# Time-based for time series
/year=2024/month=01/day=15/hour=14/

# Category based for lookups
/product_type=equity/exchange=NYSE/

# Hybrid for flexibility
/dt=2024-01-15/market=US/
```

### 5. **Schema Registry Pattern**
```python
# All data has versioned schemas
{
    "schema_id": 1,
    "version": 1,
    "schema": {...},
    "compatibility": "Backward"
}
```

## Trade-offs & Alternatives Considered

### Trade-off 1: Consistency vs Latency
**Decision:** Eventual consistency with real-time layer
- Low latency for dashboards
- May show slightly different results for few seconds

**Mitigation:** Reconciliation job every hour

### Trade-off 2: Storage Costs vs Query Perfomance
**Decision:** Denormalize in Gold layer
- Fast queries without joins
- Higher storage costs

**Mitigation:** Aggressive retention policies

### Trade-off 3: Complexity vs Features
**Decision:** Multiple specialized tools over monolithic platform
- Best tools for each job
- Operational complexity

**Mitigation:** Infrastrucure as Code, containerization

### Trade-off 4: Open Source vs Managed Services
**Decision:** Open source with cloud ready design
- No vendor lock-in
- More operational burden

**Mitigation:** Kubernetes operators, managed K8s

## Scalability Considerations

### Horizontal Scaling Points
- **Kafka**: Add brokers for throughput
- **Spark**: Add workers for processing
- **MinIO**: Add nodes for storage
- **Trino**: Add workers for queries

### Bottleneck Analysis
1. **Network I/O**: Kafka partitioning
2. **Storage I/O**: Compression, columnar formats
3. **Memory**: Spark caching, broadcast joins
4. **CPU**: Parallel processing, partitioning

## Security Architecture

### Data Security
- **Encryption at rest**: MinIO encryption
- **Encryption in transit**: TLS everywhere
- **Access control**: IAM integration

### Network Security
- **Segmentation**: Separate networks for each layer
- **Zero trust**: Service mesh with mTLS
- **Audit**: All access logged to SIEM

## Monitoring Strategy

### Key Metrics
- **Latency**: p50, p95, p99 for all operation
- **Throughput**: Records/second by pipeline
- **Error rate**: Failed records, dead letters
- **Resource usage**: CPU, memory, disk, network

### Observability Stack
- **Metrics**: Prometheus + Grafana
- **Logs**: ELK Stack
- **Traces**: Jaeger
- **Alerts**: AlertManager
# Data Flow Design

## End-to-End Data Journey

### 1. Market Data Flow

```
Yahoo Finance API
        |
        |(REST API call every 30 seconds)
        ↓
Kafka Producer (Python)
        |
        |(Avro serialization)
        ↓
Kafka Topic: market-data
        |
        |(Spark Structured Streaming)
        ↓
Bronze Layer:/market/raw/
        |
        |(Data Quality Checks)
        ↓
Silver Layer:/market/cleaned/
        |
        |(Aggregations)
        ↓
Gold Layer:/market/metrics/
        |
        |(Trino Query)
        ↓
Dashboard/API
```

### 2. Transaction Data Flow

```
CSV Upload
        |
        |(Python Script)
        ↓
Bronze Layer:/transactions/raw/
        |
        |(Spark Batch - Hourly)
        ↓
Silver Layer:/transactions/validated/
        |
        |(Business Rules)
        ↓
Gold Layer:/transactions/summary/
        |
        |(ML Feature Engineering)
        ↓
Feature Store
        |
        |(Model Training)
        ↓
ML Model Predictions
```

### 3. Real-time Alerts Flow

```
Kafka Stream
        |
        |(Spark Streaming)
        ↓
Pattern Detection
        |
        |(If anomaly detected)
        ↓
Alert Service
        |
        |(Notification)
        ↓
Dashboard/Email/Slack
```

## Data Transformations

### Bronze -> Silver Transofrmations
```python
# Example: Clean market data
def bronze_to_silver(df):
    return df \
        .dropna(subset=['price', 'volume']) \
        .withColumn('price', F.col('price').cast('decimal(10,2)')) \
        .withColumn('timestamp', F.to_timestamp('timestamp')) \
        .filter(F.col('price') > 0) \
        .dropDuplicates(['symbol', 'timestamp'])
```

### Silver -> Gold Transformations
```python
# Example: Create hourly OHLC
def silver_to_gold(df):
    return df\
        .groupBy(
            F.window('timestamp', '1 hour'),
            'symbol'
        ) \
        .agg(
            F.first('price').alias('open'),
            F.max('price').alias('high'),
            F.min('price').alias('low'),
            F.last('price').alias('close'),
            F.sum('volume').alias('volume')
        )
```

## Data Contracts

### Schema Standards
- All timestamps in UTC
- Decimal types for money
- Consistent naming: snake_case
- Required fields documented

### Quality Contracts
- **Bronze**: As-is from source
- **Silver**: No nulls in key fields
- **Gold**: Business rules applied

## Performance Optimizations

### Partitining Strategy
- **Time-based**: Daily partitions
- **Size target**: 100-200MB per file
- **Compactions**: Daily for small files

### Caching Strategy
- **Hot data**: Last 7 days in memory
- **Warm data**: Last 30 days on SSD
- **Cold data**: Compressed in object storage
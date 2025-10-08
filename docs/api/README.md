# API Documentation

## REST API Endpoints

Base URL: `http://localhost:8000/api/v1`

### Health Check
```http
GET /health
```

**Response:**
```json
{
    "status": "healthy",
    "timestamp": "2025-09-15T10:30:00Z",
    "services": {
        "minio": "healthy",
        "kafka": "healthy",
        "spark": "healthy"
    }
}
```

### Data Ingestion
**Upload CSV File**
```http

POST /ingest/csv
Content-Type: multipart/form-data

file: transactions.csv
dataset: transactions
```

**Response:**
```json
{
    "job_id": "abc123",
    "status": "processing",
    "message": "File uploaded successfully"
}
```

**Stream Market Data**
```http
POST /ingest/stream
Content-Type: application/json

{
    "symbols": ["AAPL", "GOOGL", "MSFT"],
    "interval": "1m",
    "duration": "1h"
}
```

### Data Query

**Execute SQL Query**
```http
POST /query/sql
Content-Type: application/json

{
    "query": "SELECT * FROM gold.stock_metrics WHERE symbol = 'AAPL', LIMIT 10"
}
```

**Response**
```json
{
    "columns": ["symbol", "timestamp", "price", "volume"],
    "data": [
        ["AAPL", "2024-09-15T10:00:00Z", 150.25, 1000000]
    ],
    "row_count": 1,
    "encounter_time_ms": 145
}
```

### ML Models
**Get Model Predictions**
```http
POST /ml/predict
Content-Type: application/json

{
    "model": "fraud_detection",
    "features": {
        "amount": 1000.00,
        "merchant": "ABC Store",
        "time": "2025-09-15T10:30:00Z"
    }
}
```

**Response:**
```json
{
    "prediction": 0,
    "probability": 0.05,
    "model_version": "1.0.0"
}
```

## Python SDK

### Installation
```bash
pip install enterprise-financial-datalake-sdk
```

### Usage
```python
from datalake import DataLakeClient

client = DataLakeClient(
    endpoint="http://localhost:8000",
    access_key="your-key",
    secret_key="your-secret
)

# Upload data
client.upload_csv("transactions.csv", dataset="transactions")

# Query data
result = client.query("SELECT * FROM gold.metrics LIMIT 10")

# Get predictions
prediction = client.predict(
    model="fraud_detection",
    features={"amount": 1000.00}
)
```

### WebSocket Streaming

**Connect to Real-time Stream**
```javascript

const ws = new WebSocket('ws://localhost:8000/ws/stream');

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    console.log('Received:', data);
};

ws.send(JSON.stringify({
    action: 'subscribe',
    topics: ['market-data', 'transactions']
}));
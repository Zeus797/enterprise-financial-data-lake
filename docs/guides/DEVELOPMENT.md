# Development Guide

## Setting Your Development Environment

### Prerequisites
- Python 3.9+
- Docker Desktop
- Git
- VS Code (recommended) or your preferred IDE

### Initial Setup

1. **Clone the repository**
```bash
git clone https://github.com/zeus797/enterprise-financial-data-lake.git
cd enterprise-financial-data-lake
```

2. **Create virtual environment**
```bash
python -m venv venv
source venv/bin/activate # Windows: venv\Scripts\activate
```

3. **Install dependenies**
```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

4. **Set up pre-commit hooks**
```bash
pre-commit install
```

5. **Copy environment variables**
```bash
cp .env.example .env
# Edit .env with your configurations
```

6. **Start services**
```bash
make start
```

### Development Workflow

1. **Create a feature branch**
```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes**
- Write code following our style guide
- Add tests for new functionality
- Update documentation

3. **Run tests locally**
```bash
make tests
make lint
```

4. **Commit changes**
```bash
git add .
git commit -m "feat: add awesome feature"
```

5. **Push and create PR**
```bash
git push origin feature/your-feature-name
```

### Common Development Tasks

**Running Spark Jobs Locally**
```python

from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("LocalDevelopment") \
    .master("local[*]") \
    .config("spark.hadoop.fs.s3a.endpoint", "http://localhost:9000") \
    .config("spark.hadoop.fs.s3a.access.key", "admin") \
    .config("spark.hadoop.fs.s3a.secret.key", "passkey123") \
    .getOrCreate()

# Your code here
df = spark.read.parquet("s3a://bronze/data/")
```

**Testing Kafka Producers**
```python
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lamda v: json.dumps(v).encode('utf-8')
)

producer.send('test-topic', {'key': 'value'})
producer.flush()
```

### Debugging Tips
1. Check service logs: docker compose logs -f [service-name]
2. Access service shells: docker exec -it [container-name] bash
Use debugger: Set breakepoints in VS Code
Monitor metrics: Check Prometheus/Grafana dashboards

### Troubleshooting Common Issues
**Issue: MinIO connection refused**
**Solution**: Ensure MinIO is running and healthy
```bash
docker compose ps
make health
```

**Issue: Spark job fails with S3 errors**
**solution**: Check S3 credentials and endpoint configuration
```python
spark.conf.set("spark.hadoop.fs.s3a.path.style.access", "true")
spark.conf.set("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
```

**Issue: Kafka consumner not receiving messages**
**Solution**: Check consumer group and topic configuration
```bash
docker exec -it datalake-kafka kafka-consumer-groups --bootstrap-server localhost:9092 --list
```
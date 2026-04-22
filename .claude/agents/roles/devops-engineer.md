---
name: "DevOps Engineer"
emoji: "⚙️"
description: "Specializes in deployment, infrastructure, CI/CD, and system reliability"
role_type: "engineering"
primary_stack: ["docker", "kubernetes", "github-actions", "terraform", "monitoring"]
---

# DevOps Engineer Role

## Work Style & Preferences

- **Automation First**: Automate everything repetitive
- **Infrastructure as Code**: Manage infrastructure through code
- **Monitoring Obsessed**: Measure everything to improve it
- **Security by Default**: Build security into every layer
- **Reliability Focused**: Ensure high availability and quick recovery

## Core Responsibilities

### 1. CI/CD Pipeline Design
- Build automated deployment pipelines
- Implement automated testing at each stage
- Ensure fast and reliable deployments
- Manage environment promotions

### 2. Infrastructure Management
```yaml
# docker-compose.prod.yml - Production environment
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - backend
    networks:
      - frontend
      - backend

  backend:
    image: personal-ai-assistant:latest
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - ENVIRONMENT=production
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    depends_on:
      - postgres
      - redis
    networks:
      - backend

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    networks:
      - backend

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - backend

volumes:
  postgres_data:
  redis_data:

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true
```

### 3. Kubernetes Deployment
```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: personal-ai-assistant-backend
  labels:
    app: personal-ai-assistant
    component: backend
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: personal-ai-assistant
      component: backend
  template:
    metadata:
      labels:
        app: personal-ai-assistant
        component: backend
    spec:
      containers:
      - name: backend
        image: personal-ai-assistant:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: redis-url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: personal-ai-assistant-backend-service
spec:
  selector:
    app: personal-ai-assistant
    component: backend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: ClusterIP
```

### 4. Monitoring and Logging
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'personal-ai-assistant'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
    scrape_interval: 5s

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

## Technical Guidelines

### 1. GitHub Actions CI/CD Pipeline
```yaml
# .github/workflows/deploy.yml
name: Build and Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
    - uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Cache dependencies
      uses: actions/cache@v3
      with:
        path: ~/.cache/pip
        key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}

    - name: Install dependencies
      run: |
        cd backend
        pip install -r requirements.txt
        pip install -r requirements-test.txt

    - name: Run tests
      run: |
        cd backend
        pytest --cov=app tests/
      env:
        DATABASE_URL: postgresql+asyncpg://postgres:testpass@localhost:5432/testdb
        REDIS_URL: redis://localhost:6379/0

    - name: Run security scan
      run: |
        cd backend
        pip install bandit
        bandit -r app/

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: read
      packages: write

    steps:
    - uses: actions/checkout@v4

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: ./backend
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production

    steps:
    - uses: actions/checkout@v4

    - name: Deploy to production
      run: |
        echo "Deploying to production..."
        # Add deployment commands here
        # kubectl apply -f k8s/
        # helm upgrade --install app ./helm-chart
```

### 2. Infrastructure as Code (Terraform)
```hcl
# terraform/main.tf
provider "aws" {
  region = var.aws_region
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "personal-ai-assistant-vpc"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "personal-ai-assistant"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "personal-ai-assistant-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "personal-ai-assistant-alb"
  }
}

# RDS Database
resource "aws_db_instance" "postgres" {
  identifier     = "personal-ai-assistant-db"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = "personal_ai_assistant"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true

  tags = {
    Name = "personal-ai-assistant-db"
  }
}

# ElastiCache Redis
resource "aws_elasticache_subnet_group" "main" {
  name       = "personal-ai-assistant-cache-subnet"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "personal-ai-assistant-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = {
    Name = "personal-ai-assistant-redis"
  }
}
```

### 3. Helm Chart for Kubernetes
```yaml
# helm-chart/values.yaml
replicaCount: 3

image:
  repository: ghcr.io/your-org/personal-ai-assistant
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 80
  targetPort: 8000

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: api.personal-ai-assistant.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: personal-ai-assistant-tls
      hosts:
        - api.personal-ai-assistant.com

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

# Database configuration
postgresql:
  enabled: true
  primary:
    persistence:
      size: 10Gi
  auth:
    database: personal_ai_assistant
    username: postgres

redis:
  enabled: true
  auth:
    enabled: true
    existingSecret: redis-secret
    existingSecretPasswordKey: redis-password
```

### 4. Monitoring Setup with Grafana
```yaml
# monitoring/grafana/dashboards/dashboard.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

dashboards:
  - name: Personal AI Assistant
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards/personal-ai-assistant.json
```

## Security and Compliance

### 1. Security Scanning
```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  push:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'ghcr.io/your-org/personal-ai-assistant:latest'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

    - name: OWASP Dependency Check
      run: |
        cd backend
        pip install safety
        safety check --json --output safety-report.json || true

    - name: Docker Security Check
      run: |
        docker run --rm -v $(pwd):/app \
          ghcr.io/aquasecurity/trivy:latest \
          config /app
```

### 2. Secrets Management
```yaml
# k8s/secrets.yaml (encrypted with SealedSecrets)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-secrets
  namespace: personal-ai-assistant
spec:
  encryptedData:
    database-url: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    redis-url: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    jwt-secret: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
    openai-key: AgBy3i4OJSWK+PiTySYZZA9rO43cGDEQAx...
```

### 3. Network Security
```yaml
# k8s/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: personal-ai-assistant-network-policy
spec:
  podSelector:
    matchLabels:
      app: personal-ai-assistant
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: database
    ports:
    - protocol: TCP
      port: 5432
  - to:
    - namespaceSelector:
        matchLabels:
          name: cache
    ports:
    - protocol: TCP
      port: 6379
```

## Disaster Recovery and Backup

### 1. Database Backup Strategy
```bash
#!/bin/bash
# scripts/backup-db.sh

# Backup PostgreSQL database
kubectl exec -it deployment/postgres -- pg_dump \
  -U postgres \
  -h localhost \
  personal_ai_assistant \
  | gzip > backup-$(date +%Y%m%d-%H%M%S).sql.gz

# Upload to S3
aws s3 cp backup-$(date +%Y%m%d-%H%M%S).sql.gz \
  s3://personal-ai-assistant-backups/database/

# Clean old backups (keep last 30 days)
aws s3 ls s3://personal-ai-assistant-backups/database/ \
  | while read -r line; do
      createDate=$(echo "$line" | awk '{print $1" "$2}')
      createDate=$(date -d "$createDate" +%s)
      olderThan=$(date -d "30 days ago" +%s)
      if [[ $createDate -lt $olderThan ]]; then
        fileName=$(echo "$line" | awk '{print $4}')
        if [[ $fileName != "" ]]; then
          aws s3 rm s3://personal-ai-assistant-backups/database/$fileName
        fi
      fi
    done
```

### 2. Restore Procedures
```bash
#!/bin/bash
# scripts/restore-db.sh

BACKUP_FILE=$1
if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file>"
  exit 1
fi

# Download backup from S3
aws s3 cp s3://personal-ai-assistant-backups/database/$BACKUP_FILE .

# Extract and restore
gunzip -c $BACKUP_FILE | kubectl exec -i deployment/postgres -- \
  psql -U postgres -d personal_ai_assistant

echo "Database restored from $BACKUP_FILE"
```

## Performance Optimization

### 1. Application Performance Monitoring
```yaml
# monitoring/apm/jaeger.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 16686
          name: ui
        - containerPort: 14268
          name: collector
        env:
        - name: COLLECTOR_ZIPKIN_HTTP_PORT
          value: "9411"
```

### 2. Resource Optimization
```yaml
# k8s/hpa.yml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: personal-ai-assistant-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: personal-ai-assistant-backend
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Monitoring and Alerting

### 1. Alert Rules
```yaml
# monitoring/alert_rules.yml
groups:
- name: personal-ai-assistant
  rules:
  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: High error rate detected
      description: "Error rate is {{ $value }} errors per second"

  - alert: HighMemoryUsage
    expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: High memory usage
      description: "Memory usage is above 90%"

  - alert: DatabaseDown
    expr: up{job="postgres"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: Database is down
      description: "PostgreSQL database is not responding"

  - alert: RedisDown
    expr: up{job="redis"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: Redis is down
      description: "Redis cache is not responding"
```

### 2. Health Checks
```python
# app/core/health.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db

router = APIRouter()

@router.get("/health")
async def health_check():
    """Basic health check"""
    return {"status": "healthy"}

@router.get("/health/ready")
async def readiness_check(db: AsyncSession = Depends(get_db)):
    """Readiness check - checks database connection"""
    try:
        await db.execute("SELECT 1")
        return {"status": "ready", "database": "connected"}
    except Exception as e:
        return {"status": "not_ready", "database": "disconnected", "error": str(e)}

@router.get("/health/live")
async def liveness_check():
    """Liveness check - indicates if the app is running"""
    return {"status": "alive"}
```

## Cost Optimization

### 1. Resource Right-Sizing
```yaml
# Use spot instances for non-critical workloads
apiVersion: v1
kind: Pod
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-lifecycle
            operator: In
            values:
            - spot
  containers:
  - name: worker
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

### 2. Auto-scaling Policies
```yaml
# Scale down during off-peak hours
apiVersion: v1
kind: ConfigMap
metadata:
  name: cron-scaling
data:
  scale-down.yaml: |
    apiVersion: autoscaling/v1
    kind: HorizontalPodAutoscaler
    metadata:
      name: off-peak-hpa
    spec:
      minReplicas: 1
      maxReplicas: 2
  scale-up.yaml: |
    apiVersion: autoscaling/v1
    kind: HorizontalPodAutoscaler
    metadata:
      name: peak-hours-hpa
    spec:
      minReplicas: 3
      maxReplicas: 10
```

## Collaboration Guidelines

### With Development Team
- Provide infrastructure requirements early
- Review deployment configurations
- Monitor application performance
- Support local development setup

### With Security Team
- Implement security best practices
- Manage secrets and certificates
- Conduct regular security audits
- Respond to security incidents

### With Product Team
- Ensure system meets availability requirements
- Monitor performance metrics
- Plan capacity for growth
- Manage operational costs

## Documentation

### 1. Architecture Documentation
```markdown
# Infrastructure Architecture

## Overview
- Cloud provider: AWS
- Orchestration: Kubernetes (EKS)
- Database: PostgreSQL (RDS)
- Cache: Redis (ElastiCache)
- Monitoring: Prometheus + Grafana

## Deployment Pipeline
1. Code pushed to GitHub
2. Tests run in GitHub Actions
3. Docker image built and pushed
4. Helm chart updated in Kubernetes
5. Health checks performed
```

### 2. Runbook Documentation
```markdown
# Incident Response Runbook

## Database Connection Issues
### Symptoms
- 5xx errors increasing
- Database timeouts in logs

### Diagnosis Steps
1. Check database logs: `kubectl logs deployment/postgres`
2. Verify database connectivity
3. Check connection pool metrics

### Resolution Steps
1. Restart application pods if needed
2. Scale database if at capacity
3. Review slow query logs
```

## Continuous Improvement

### 1. SLI/SLO/SLA Monitoring
```yaml
# Service Level Objectives
service_level_objectives:
  availability:
    target: 99.9%
    measurement: uptime_percentage
  latency:
    target: 95th percentile < 500ms
    measurement: http_request_duration
  error_rate:
    target: < 0.1%
    measurement: http_requests_5xx_rate
```

### 2. Chaos Engineering
```yaml
# chaos-experiment.yml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-failure-experiment
spec:
  selector:
    namespaces:
      - personal-ai-assistant
  mode: one
  action: pod-failure
  duration: "30s"
```

## Best Practices

1. **Infrastructure as Code**: Version control all infrastructure
2. **Immutable Infrastructure**: Replace instead of modify
3. **Automation**: Automate everything possible
4. **Monitoring**: Monitor all the things
5. **Documentation**: Document everything
6. **Security**: Security by design
7. **Cost Awareness**: Optimize for cost efficiency
8. **Disaster Recovery**: Always have a backup plan
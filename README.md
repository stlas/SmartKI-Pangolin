# SmartKI Pangolin Web Application

> **Container-basierte Web-Application mit Nginx Reverse Proxy und Service-Discovery**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![SmartKI Ecosystem](https://img.shields.io/badge/SmartKI-Ecosystem-green.svg)](https://github.com/stlas)
[![Docker](https://img.shields.io/badge/Docker-Container-blue.svg)](https://docker.com)

High-Performance Web-Application Container mit intelligenter Service-Orchestrierung, Nginx Reverse Proxy und nahtloser SmartKI-Ecosystem-Integration.

## 🚀 Features

### Container-Orchestrierung
- **Docker Container**: `fosrl/pangolin:latest`
- **Multi-Port-Konfiguration** für Web-App und API
- **Service-Discovery** mit automatischer Registration
- **Health-Monitoring** mit Restart-Policies

### Nginx Reverse Proxy
- **API-Gateway-Pattern** für Microservice-Routing
- **Load-Balancing** für High-Availability
- **SSL/TLS-Termination** mit automatischen Zertifikaten
- **WebSocket-Support** für Real-time Features

### SmartKI-Integration
- **ai-collab Authentication** über API-Gateway
- **PM-System Integration** für Task-Management
- **Knowledge-Base** Connection zu Obsidian
- **Real-time Updates** über WebSocket-Channels

## 🏗️ Architektur

```
SmartKI-Pangolin (LXC 200 - 192.168.178.186)
├── containers/
│   ├── pangolin-full/           # Haupt-Application Container
│   │   ├── web-app/            # Frontend (Port 3002)
│   │   ├── api/                # Backend API (Port 3000)
│   │   └── websockets/         # Real-time Communication
│   └── traefik/                # Service-Mesh (geplant)
├── nginx/
│   ├── conf.d/                 # Reverse Proxy Configs
│   ├── ssl/                    # SSL-Zertifikate
│   └── logs/                   # Access und Error Logs
├── scripts/
│   ├── deploy.sh              # Deployment-Automatisierung
│   ├── health-check.sh        # Container-Monitoring
│   └── backup.sh              # Application-Backups
└── monitoring/
    ├── prometheus.yml         # Metrics-Collection
    ├── grafana/              # Dashboard-Konfiguration
    └── alerts/               # Alert-Rules
```

## 📋 Aktuelle Konfiguration

### Container-Status
```bash
CONTAINER ID   IMAGE                   PORTS                    STATUS
222bb2eec2ea   fosrl/pangolin:latest   3000:3000, 8080:3002   Up 2 days
```

### Port-Mapping
- **Port 80** → Nginx Reverse Proxy (öffentlicher Zugang)
- **Port 3000** → API-Backend (intern)
- **Port 8080** → Web-App Frontend (Container Port 3002)

### Nginx-Konfiguration (Aktuell aktiv)
```nginx
server {
    listen 80;
    server_name pangolin.haossl.de 192.168.178.186;

    # Web-App Frontend
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # API-Gateway
    location /api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
    }
}
```

## 🔧 Installation & Deployment

### Voraussetzungen
- LXC Container auf Proxmox
- Docker & Docker-Compose
- Nginx Web Server
- SSH-Zugang mit entsprechenden Keys

### Quick Setup
```bash
# Repository klonen
git clone https://github.com/stlas/SmartKI-Pangolin.git
cd SmartKI-Pangolin

# Umgebung konfigurieren
cp .env.template .env
# Konfiguration anpassen

# Container deployen
./scripts/deploy.sh

# Nginx konfigurieren
sudo cp nginx/pangolin.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/pangolin /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Docker-Compose Setup
```yaml
version: '3.8'

services:
  pangolin-app:
    image: fosrl/pangolin:latest
    container_name: pangolin-full
    ports:
      - "3000:3000"    # API
      - "8080:3002"    # Web-App
    environment:
      - NODE_ENV=production
      - API_URL=http://localhost:3000
      - SMARTKI_PM_URL=http://192.168.178.186:3100
      - SMARTKI_OBSIDIAN_URL=http://192.168.178.187:3001
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx-proxy:
    image: nginx:alpine
    container_name: pangolin-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./nginx/ssl:/etc/nginx/ssl
      - ./nginx/logs:/var/log/nginx
    depends_on:
      - pangolin-app
    restart: unless-stopped
```

## 🌐 API-Integration

### SmartKI-Ecosystem Endpoints
```javascript
// PM-System Integration
app.get('/api/pm/tasks', async (req, res) => {
  const tasks = await fetch('http://192.168.178.186:3100/api/tasks');
  res.json(await tasks.json());
});

// Obsidian Knowledge-Base
app.get('/api/knowledge/:project', async (req, res) => {
  const notes = await fetch(`http://192.168.178.187:3001/api/v1/search?q=${req.params.project}`);
  res.json(await notes.json());
});

// ai-collab Session-Management
app.post('/api/ai-collab/session', async (req, res) => {
  const sessionData = req.body;
  
  // Create PM task
  await createPMTask(sessionData);
  
  // Document in Obsidian
  await createSessionDoc(sessionData);
  
  res.json({ documented: true });
});
```

### Authentication & Security
```javascript
// JWT-Token Validation
app.use('/api', verifyToken);

function verifyToken(req, res, next) {
  const token = req.headers['authorization']?.split(' ')[1];
  
  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }
  
  jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = decoded;
    next();
  });
}
```

## 🔍 Monitoring & Health Checks

### Container-Health-Monitoring
```bash
#!/bin/bash
# scripts/health-check.sh

echo "🔍 SmartKI-Pangolin Health Check"

# Container Status
echo "📦 Container Status:"
docker ps --filter "name=pangolin" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Service Endpoints
echo "🌐 Service Health:"
curl -s http://localhost:3000/health | jq '.status' || echo "❌ API Down"
curl -s http://localhost:8080/ >/dev/null && echo "✅ Web-App OK" || echo "❌ Web-App Down"
curl -s http://localhost/ >/dev/null && echo "✅ Nginx OK" || echo "❌ Nginx Down"

# Resource Usage
echo "💾 Resource Usage:"
docker stats pangolin-full --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Logs (last 5 lines)
echo "📋 Recent Logs:"
docker logs pangolin-full --tail 5
```

### Prometheus Metrics
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'pangolin-app'
    static_configs:
      - targets: ['localhost:3000']
    metrics_path: '/metrics'
    
  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']
```

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "SmartKI-Pangolin Monitoring",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph", 
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      }
    ]
  }
}
```

## 🚀 Deployment-Strategien

### Zero-Downtime Deployment
```bash
#!/bin/bash
# scripts/deploy.sh

echo "🚀 SmartKI-Pangolin Deployment"

# Pre-deployment checks
./scripts/health-check.sh

# Pull latest image
docker pull fosrl/pangolin:latest

# Create new container
docker run -d \
  --name pangolin-new \
  -p 3001:3000 \
  -p 8081:3002 \
  fosrl/pangolin:latest

# Health check for new container
sleep 30
if curl -f http://localhost:3001/health; then
  echo "✅ New container healthy"
  
  # Update nginx upstream
  sed -i 's/localhost:3000/localhost:3001/g' /etc/nginx/sites-available/pangolin
  sed -i 's/localhost:8080/localhost:8081/g' /etc/nginx/sites-available/pangolin
  
  # Reload nginx
  nginx -t && systemctl reload nginx
  
  # Stop old container
  docker stop pangolin-full
  docker rm pangolin-full
  
  # Rename new container
  docker rename pangolin-new pangolin-full
  
  echo "🎉 Deployment successful"
else
  echo "❌ New container unhealthy, rolling back"
  docker stop pangolin-new
  docker rm pangolin-new
  exit 1
fi
```

### Backup & Restore
```bash
#!/bin/bash
# scripts/backup.sh

BACKUP_DIR="/var/backups/smartki-pangolin"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR/$DATE"

# Backup container data
docker run --rm \
  -v pangolin_data:/data \
  -v "$BACKUP_DIR/$DATE":/backup \
  busybox tar czf /backup/data.tar.gz -C /data .

# Backup nginx config
cp -r /etc/nginx/sites-available/pangolin "$BACKUP_DIR/$DATE/"

# Backup container image
docker save fosrl/pangolin:latest | gzip > "$BACKUP_DIR/$DATE/pangolin-image.tar.gz"

echo "✅ Backup created: $BACKUP_DIR/$DATE"
```

## 🔒 Sicherheits-Konfiguration

### SSL/TLS Setup
```nginx
server {
    listen 443 ssl http2;
    server_name pangolin.haossl.de;
    
    ssl_certificate /etc/nginx/ssl/pangolin.crt;
    ssl_certificate_key /etc/nginx/ssl/pangolin.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Firewall-Regeln
```bash
# UFW Firewall Setup
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw deny 3000/tcp   # Block direct API access
ufw deny 8080/tcp   # Block direct web-app access
ufw enable
```

## 🎯 SmartKI-Ecosystem Integration

### Service-Discovery
```javascript
// Automatic service registration
const services = {
  'smartki-pm': 'http://192.168.178.186:3100',
  'smartki-obsidian': 'http://192.168.178.187:3001',
  'smartki-pangolin': 'http://192.168.178.186',
  'ai-collab': 'http://192.168.178.183'
};

// Health check all services
async function checkServiceHealth() {
  const results = {};
  
  for (const [name, url] of Object.entries(services)) {
    try {
      const response = await fetch(`${url}/health`, { timeout: 5000 });
      results[name] = response.ok ? 'healthy' : 'unhealthy';
    } catch (error) {
      results[name] = 'unreachable';
    }
  }
  
  return results;
}
```

### Event-Bus Integration
```javascript
// WebSocket event bus for real-time updates
const eventBus = new WebSocket('ws://localhost:3000/events');

eventBus.on('task-created', (task) => {
  // Update UI with new task
  updateTaskList(task);
});

eventBus.on('session-completed', (session) => {
  // Show session results
  displaySessionResults(session);
});

eventBus.on('knowledge-updated', (update) => {
  // Refresh knowledge base display
  refreshKnowledgeBase(update.project);
});
```

## 📊 Performance-Optimierung

### Container-Tuning
```dockerfile
# Optimized Dockerfile (für Custom-Build)
FROM node:18-alpine

# Performance optimizations
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=2048"

# Resource limits
LABEL resource.cpu="1.0"
LABEL resource.memory="2Gi"

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

### Nginx-Performance
```nginx
# Performance optimizations
worker_processes auto;
worker_connections 1024;

# Caching
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m;

location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    proxy_cache app_cache;
    proxy_cache_valid 200 1d;
    proxy_cache_valid 404 1m;
    expires 1d;
    add_header Cache-Control "public, immutable";
}

# Compression
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript;
```

## 🚀 Roadmap

### Version 1.0.0 (✅ Aktuell deployed)
- [x] Docker Container deployed
- [x] Nginx Reverse Proxy konfiguriert
- [x] Login-System funktionsfähig
- [x] API-Gateway-Pattern implementiert

### Version 1.1.0
- [ ] Traefik Service-Mesh Integration
- [ ] SSL/TLS automatische Zertifikate
- [ ] Advanced Health-Monitoring
- [ ] Performance-Dashboards

### Version 1.2.0
- [ ] Container-Orchestrierung mit Kubernetes
- [ ] Blue-Green-Deployment-Pipeline
- [ ] Advanced Security-Features
- [ ] Multi-Region-Support

## 🤝 Beitragen

1. Fork des Repositories
2. Feature-Branch für Container-Updates
3. Testing in isolierter Umgebung
4. Pull Request mit Deployment-Tests
5. Code-Review durch Infrastructure-Team

## 📝 Lizenz

MIT License - siehe [LICENSE](LICENSE) für Details.

## 👥 Team

**Entwickelt vom SmartKI-Infrastructure-Team:**
- Container-Architecture: [stlas](https://github.com/stlas)  
- Nginx-Configuration: SmartKI-DevOps
- Monitoring-Setup: ai-collab System

---

**Teil des SmartKI-Ecosystems** - Intelligente Infrastructure-as-Code für moderne Softwareentwicklung
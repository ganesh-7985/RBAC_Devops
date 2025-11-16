# ⚡ Quick Reference - Secure API Gateway

## 🚀 One-Liner Commands

### Local Development
```bash
# Start dev server
npm install && cp .env.example .env && npm run dev

# Get admin token
curl -s -X POST http://localhost:3000/auth/login -H "Content-Type: application/json" -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token'
```

### Docker
```bash
# Build and run
docker build -t secure-api-gateway . && docker run -d --name gateway -p 3000:3000 -e JWT_SECRET="$(openssl rand -base64 32)" secure-api-gateway

# Security scan
trivy image --severity HIGH,CRITICAL secure-api-gateway
```

### VM Setup
```bash
# Initial setup on VM
curl -sSL https://raw.githubusercontent.com/your-org/rbac-ssd/main/deploy/scripts/setup-vm.sh | sudo bash
```

### Deployment
```bash
# Deploy to staging
./deploy/scripts/deploy-vm.sh staging deploy@staging.example.com latest

# Deploy to production
./deploy/scripts/deploy-vm.sh production deploy@production.example.com v1.0.0
```

## 📋 Test Users

```
admin / Admin@123  → admin role (all permissions)
user / User@123    → user role (read, write)
guest / Guest@123  → guest role (read only)
```

## 🔗 Endpoints Cheat Sheet

```bash
BASE="http://localhost:3000"

# Public
curl $BASE/health
curl $BASE/api/public

# Login
TOKEN=$(curl -s -X POST $BASE/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')

# Protected (any role)
curl $BASE/api/protected -H "Authorization: Bearer $TOKEN"

# Guest level
curl $BASE/api/guest -H "Authorization: Bearer $TOKEN"

# User level
curl $BASE/api/user -H "Authorization: Bearer $TOKEN"

# Admin only
curl $BASE/api/admin -H "Authorization: Bearer $TOKEN"
```

## 🔧 Jenkins Credentials

```
docker-registry-url     → Secret text     → ghcr.io/your-org
docker-registry-creds   → Username/Pass   → Registry credentials
vm-ssh-key              → SSH private key → deploy user key
```

## 🖥️ VM Commands

```bash
# Check container status
ssh deploy@vm-host 'docker ps | grep gateway'

# View logs
ssh deploy@vm-host 'docker logs gateway --tail=100'

# Restart container
ssh deploy@vm-host 'docker restart gateway'

# Health check
ssh deploy@vm-host 'curl http://localhost:3000/health'
```

## 🐛 Quick Troubleshooting

```bash
# Container not running
docker ps -a | grep gateway
docker logs gateway

# Health check failed
docker exec gateway curl http://localhost:3000/health

# JWT secret missing
cat /etc/gateway/jwt-secret || openssl rand -base64 32 | sudo tee /etc/gateway/jwt-secret

# Permission denied
sudo usermod -aG docker deploy && sudo systemctl restart docker

# Port in use
sudo lsof -i :3000
```

## 📊 Monitoring

```bash
# Real-time logs
docker logs gateway -f

# Container stats
docker stats gateway

# Health check loop
while true; do curl -s http://localhost:3000/health | jq '.status'; sleep 5; done
```

## 🔄 Rollback

```bash
# Quick rollback
ssh deploy@prod-vm 'docker stop gateway && docker rm gateway && docker run -d --name gateway -p 3000:3000 -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) ghcr.io/org/gateway:v1.0.0'
```

## 📚 Documentation

- **README.md** → Main documentation
- **VM_DEPLOYMENT_GUIDE.md** → Detailed deployment guide
- **PROJECT_SUMMARY.md** → Project overview & file manifest

## 🔒 Security Quick Checks

```bash
# Verify JWT secret is set
cat /etc/gateway/jwt-secret

# Check firewall
sudo ufw status

# Verify non-root container
docker exec gateway id

# Scan for vulnerabilities
trivy image secure-api-gateway

# Check for security headers
curl -I http://localhost:3000/health
```

## 🎯 Environment Variables

```bash
# Required
JWT_SECRET="$(openssl rand -base64 32)"
NODE_ENV="production"

# Optional
PORT="3000"
JWT_EXPIRY="1h"
LOG_LEVEL="info"
CORS_ORIGIN="https://example.com"
```

## 📦 Build & Push

```bash
# Build
docker build -t ghcr.io/org/secure-api-gateway:v1.0.0 .

# Push
echo $GITHUB_TOKEN | docker login ghcr.io -u username --password-stdin
docker push ghcr.io/org/secure-api-gateway:v1.0.0
```

---

**Last Updated**: 2025-11-16

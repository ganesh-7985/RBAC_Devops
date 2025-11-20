# 🎯 Demo Commands Cheat Sheet

**Quick reference for live demonstration to professor**

---

## 🚀 PART 1: LOCAL DEVELOPMENT DEMO

### Setup & Start Server

```bash
# Navigate to project
cd /Users/shankarganesh/Coding/rbac-ssd

# Show project structure
ls -la

# Install dependencies (if not done)
npm install

# Start development server
npm run dev

# Expected output:
# 🚀 Secure API Gateway started
# 📝 API Documentation available at http://localhost:3000
```

---

## 🔍 PART 2: API TESTING COMMANDS

### Public Endpoints (No Authentication)

```bash
# Health check
curl http://localhost:3000/health | jq

# API info
curl http://localhost:3000/ | jq

# Public endpoint
curl http://localhost:3000/api/public | jq

# Try protected endpoint WITHOUT token (should FAIL)
curl http://localhost:3000/api/protected
# Expected: 401 - "No token provided"
```

---

### Authentication - Guest User

```bash
# Login as GUEST
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"guest","password":"Guest@123"}' | jq

# Save token (copy from response)
GUEST_TOKEN="<paste-token-here>"

# Or save automatically:
GUEST_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"guest","password":"Guest@123"}' | jq -r '.token')

echo "Guest Token: $GUEST_TOKEN"

# Test guest access (should WORK)
curl http://localhost:3000/api/guest \
  -H "Authorization: Bearer $GUEST_TOKEN" | jq

# Try user endpoint as guest (should FAIL)
curl http://localhost:3000/api/user \
  -H "Authorization: Bearer $GUEST_TOKEN" | jq
# Expected: 403 - "Insufficient permissions"

# Try admin endpoint as guest (should FAIL)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $GUEST_TOKEN" | jq
# Expected: 403 - "Insufficient permissions"
```

---

### Authentication - User Role

```bash
# Login as USER
USER_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"User@123"}' | jq -r '.token')

echo "User Token: $USER_TOKEN"

# Test guest endpoint (should WORK - user has higher privileges)
curl http://localhost:3000/api/guest \
  -H "Authorization: Bearer $USER_TOKEN" | jq

# Test user endpoint (should WORK)
curl http://localhost:3000/api/user \
  -H "Authorization: Bearer $USER_TOKEN" | jq

# Try admin endpoint as user (should FAIL)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $USER_TOKEN" | jq
# Expected: 403 - "Insufficient permissions"
```

---

### Authentication - Admin Role

```bash
# Login as ADMIN
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')

echo "Admin Token: $ADMIN_TOKEN"

# Test guest endpoint (should WORK)
curl http://localhost:3000/api/guest \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq

# Test user endpoint (should WORK)
curl http://localhost:3000/api/user \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq

# Test admin endpoint (should WORK)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq

# Test permission-based endpoint (should WORK)
curl -X POST http://localhost:3000/api/admin/users \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"username":"newuser","role":"user"}' | jq
```

---

### RBAC Demonstration Table

| Role  | /api/guest | /api/user | /api/admin | /api/admin/users |
|-------|------------|-----------|------------|------------------|
| guest | ✅ 200     | ❌ 403    | ❌ 403     | ❌ 403           |
| user  | ✅ 200     | ✅ 200    | ❌ 403     | ❌ 403           |
| admin | ✅ 200     | ✅ 200    | ✅ 200     | ✅ 200           |

---

## 🔒 PART 3: SECURITY FEATURES DEMO

### Show Security Headers

```bash
# View HTTP headers
curl -I http://localhost:3000/health

# Look for:
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
# Strict-Transport-Security: max-age=31536000
# Content-Security-Policy: default-src 'self'
```

---

### Input Validation Demo

```bash
# Test XSS prevention
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"<script>alert(1)</script>","password":"test"}' | jq

# Test SQL injection attempt (sanitized)
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin'\'' OR 1=1--","password":"test"}' | jq

# Test invalid JSON
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d 'invalid json' | jq
```

---

### Token Expiry Demo

```bash
# Login and get token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')

# Use token immediately (should WORK)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $TOKEN" | jq

# Wait for token to expire (JWT_EXPIRY=1h by default)
# For demo, you can set JWT_EXPIRY=10s in .env and restart server

# Use expired token (should FAIL)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $TOKEN" | jq
# Expected: 401 - "Token expired"
```

---

## 🐳 PART 4: DOCKER DEMO

### Build Image

```bash
# Build Docker image
docker build -t secure-api-gateway:demo .

# Show multi-stage build layers
docker history secure-api-gateway:demo

# Show image size
docker images | grep secure-api-gateway
# Expected: ~150MB (optimized)
```

---

### Security Verification

```bash
# Verify non-root user
docker run --rm secure-api-gateway:demo id
# Expected: uid=1001(nodejs) gid=1001(nodejs)

# Scan for vulnerabilities
trivy image --severity HIGH,CRITICAL secure-api-gateway:demo

# View image metadata
docker inspect secure-api-gateway:demo | jq '.[0].Config'
```

---

### Run Container

```bash
# Run container
docker run -d --name gateway-demo \
  -p 3000:3000 \
  -e JWT_SECRET="demo-secret-key-123456" \
  -e NODE_ENV="production" \
  secure-api-gateway:demo

# Wait for startup
sleep 5

# Test health
curl http://localhost:3000/health | jq

# View logs
docker logs gateway-demo

# Show container info
docker ps | grep gateway-demo

# Show resource usage
docker stats gateway-demo --no-stream

# Stop and remove
docker stop gateway-demo
docker rm gateway-demo
```

---

## 📁 PART 5: CODE WALKTHROUGH

### Show Key Files

```bash
# Main application
cat src/app.js | head -50

# Authentication middleware
cat src/middleware/auth.js

# RBAC middleware
cat src/middleware/rbac.js

# Dockerfile (multi-stage build)
cat Dockerfile

# Jenkins pipeline
cat Jenkinsfile | head -100

# Deployment script
cat deploy/scripts/deploy-vm.sh
```

---

### Show Project Structure

```bash
# Tree view (if installed)
tree -L 3 -I node_modules

# Or manual listing
ls -R src/
```

---

## 🔄 PART 6: CI/CD PIPELINE DEMO

### Show Jenkinsfile Stages

```bash
# View pipeline definition
cat Jenkinsfile

# Show environment variables
grep -A 10 "environment {" Jenkinsfile

# Show deployment script
grep -A 20 "Deploy to Staging" Jenkinsfile
```

---

### Explain Pipeline Flow

**Open Jenkins UI and show**:
1. Build history
2. Stage view (visual pipeline)
3. Console output
4. Test reports
5. Trivy scan results

---

## 🖥️ PART 7: VM DEPLOYMENT COMMANDS

### Check Staging Deployment

```bash
# SSH to staging
ssh deploy@18.190.253.152

# Check container status
docker ps | grep gateway

# View logs
docker logs gateway --tail=50

# Health check
curl http://localhost:3000/health

# Exit SSH
exit
```

---

### Check Production Deployment

```bash
# SSH to production
ssh deploy@3.133.157.227

# Same commands as staging
docker ps | grep gateway
docker logs gateway --tail=50
curl http://localhost:3000/health

exit
```

---

## 🧪 PART 8: FULL DEMO SCRIPT (15 MINUTES)

### Script Timeline

**Minute 0-2: Project Overview**
```bash
cd /Users/shankarganesh/Coding/rbac-ssd
ls -la
cat README.md | head -20
```

**Minute 2-4: Code Walkthrough**
```bash
cat src/app.js | head -50
cat src/middleware/rbac.js | head -30
cat Dockerfile
```

**Minute 4-8: Live API Demo**
```bash
npm run dev  # (in another terminal)

# Public endpoint
curl http://localhost:3000/health | jq

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')

# Test protected endpoint
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq

# Get user token
USER_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"User@123"}' | jq -r '.token')

# User tries admin endpoint (should FAIL)
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $USER_TOKEN" | jq
```

**Minute 8-11: Docker Demo**
```bash
# Build
docker build -t secure-api-gateway:demo .

# Security check
docker run --rm secure-api-gateway:demo id

# Vulnerability scan
trivy image --severity HIGH,CRITICAL secure-api-gateway:demo

# Run container
docker run -d --name gateway-demo \
  -p 3000:3000 \
  -e JWT_SECRET="demo-secret" \
  secure-api-gateway:demo

# Test
curl http://localhost:3000/health | jq

# Cleanup
docker stop gateway-demo && docker rm gateway-demo
```

**Minute 11-13: CI/CD Explanation**
```bash
cat Jenkinsfile
# Explain each stage
# Show Jenkins UI (if available)
```

**Minute 13-15: Deployment Demo**
```bash
# Show VM setup
cat deploy/scripts/setup-vm.sh

# Show deployment script
cat deploy/scripts/deploy-vm.sh

# Check live deployment
ssh deploy@18.190.253.152 'docker ps && curl -s http://localhost:3000/health'
```

---

## 🎯 TROUBLESHOOTING

### Server Won't Start

```bash
# Check port availability
lsof -i :3000

# Check environment variables
cat .env

# Check logs
npm run dev
```

---

### Docker Issues

```bash
# Check Docker is running
docker ps

# View build logs
docker build -t secure-api-gateway:demo . --no-cache

# Check container logs
docker logs gateway-demo
```

---

### Authentication Issues

```bash
# Verify JWT_SECRET is set
echo $JWT_SECRET

# Check token format
echo $ADMIN_TOKEN | cut -d'.' -f1 | base64 -d

# Test with curl verbose
curl -v http://localhost:3000/api/admin \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## 📝 QUICK REFERENCE: Test Credentials

```
Admin:
  username: admin
  password: Admin@123
  role: admin
  permissions: read, write, delete, manage_users

User:
  username: user
  password: User@123
  role: user
  permissions: read, write

Guest:
  username: guest
  password: Guest@123
  role: guest
  permissions: read
```

---

## 🔗 USEFUL URLS

```bash
# Local development
http://localhost:3000
http://localhost:3000/health
http://localhost:3000/api/public

# Staging (if configured)
http://18.190.253.152:3000

# Production (if configured)
http://3.133.157.227:3000

# Jenkins (if configured)
http://your-jenkins-url:8080
```

---

## ⚡ ONE-LINER COMMANDS

```bash
# Complete demo setup
npm install && cp .env.example .env && npm run dev

# Get admin token
curl -s -X POST http://localhost:3000/auth/login -H "Content-Type: application/json" -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token'

# Test all roles
for role in guest user admin; do echo "Testing $role:"; curl -s -X POST http://localhost:3000/auth/login -H "Content-Type: application/json" -d "{\"username\":\"$role\",\"password\":\"$(echo $role | sed 's/.*/\u&/')@123\"}" | jq; done

# Docker build and run
docker build -t secure-api-gateway:demo . && docker run -d --name gateway-demo -p 3000:3000 -e JWT_SECRET="demo-secret" secure-api-gateway:demo && sleep 5 && curl http://localhost:3000/health

# Check deployment
ssh deploy@18.190.253.152 'docker ps | grep gateway && curl -s http://localhost:3000/health'
```

---

## 🎤 PRESENTATION TIPS

1. **Have terminals ready**:
   - Terminal 1: Application running (`npm run dev`)
   - Terminal 2: Commands for testing
   - Terminal 3: Spare for Docker/SSH

2. **Pre-save tokens**:
   ```bash
   export ADMIN_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login -H "Content-Type: application/json" -d '{"username":"admin","password":"Admin@123"}' | jq -r '.token')
   export USER_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login -H "Content-Type: application/json" -d '{"username":"user","password":"User@123"}' | jq -r '.token')
   export GUEST_TOKEN=$(curl -s -X POST http://localhost:3000/auth/login -H "Content-Type: application/json" -d '{"username":"guest","password":"Guest@123"}' | jq -r '.token')
   ```

3. **Increase terminal font size** for visibility

4. **Use `| jq` for pretty JSON output**

5. **Have backup plan if network fails**:
   - Run everything locally
   - Have screenshots ready

---

**Good luck with your demo! 🚀**

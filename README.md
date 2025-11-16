# 🔐 Secure API Gateway - VM Deployment

A production-ready, security-hardened API Gateway with JWT authentication, Role-Based Access Control (RBAC), and comprehensive CI/CD pipeline using Jenkins and Docker for VM deployment.

## 📋 Overview

This project implements a minimal, secure API Gateway that can be deployed to VMs or Docker hosts via SSH. It includes JWT-based authentication, three-tier RBAC (Admin/User/Guest), input validation, security headers, and a complete Jenkins pipeline for CI/CD.

**Key Features:**
- **JWT Authentication** with configurable expiry
- **RBAC** (Admin, User, Guest roles with permissions)
- **Input Validation** using Zod schemas with XSS prevention
- **Security Headers** via Helmet.js (CSP, HSTS, etc.)
- **Hardened Docker** multi-stage builds, non-root user
- **Jenkins CI/CD** with Trivy scanning and SSH-based VM deployment
- **Systemd Integration** for container lifecycle management

## 📁 Files Created

### Application Code
- **src/app.js** - Main Express application with security middleware
- **src/config/logger.js** - Winston structured logging
- **src/middleware/auth.js** - JWT authentication and token generation
- **src/middleware/rbac.js** - Role-based access control middleware
- **src/middleware/validation.js** - Zod validation and input sanitization
- **src/middleware/security.js** - Error handling and request logging
- **src/routes/auth.routes.js** - Authentication endpoints
- **src/routes/api.routes.js** - Protected API routes with RBAC

### Configuration
- **package.json** - Dependencies and npm scripts
- **.env.example** - Environment variable template
- **.eslintrc.json** - ESLint configuration
- **.gitignore** - Git ignore patterns
- **.dockerignore** - Docker build excludes

### Docker & CI/CD
- **Dockerfile** - Multi-stage hardened Docker build
- **Jenkinsfile** - Declarative pipeline for VM deployment via SSH

### Deployment
- **deploy/systemd/gateway.service** - Systemd unit file
- **deploy/scripts/setup-vm.sh** - VM initial setup script
- **deploy/scripts/deploy-vm.sh** - Manual deployment script
- **scripts/build-and-scan.sh** - Local build and security scan

## 🚀 Quick Start

### Local Development

```bash
# 1. Clone and install
git clone <repository-url>
cd rbac-ssd
npm install

# 2. Configure environment
cp .env.example .env
echo "JWT_SECRET=$(openssl rand -base64 32)" >> .env

# 3. Start development server
npm run dev

# Server runs on http://localhost:3000
```

### Test the API

```bash
# Get a token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' \
  | jq -r '.token')

# Test protected endpoint
curl http://localhost:3000/api/protected \
  -H "Authorization: Bearer $TOKEN"

# Test admin endpoint
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $TOKEN"
```

## 📚 API Endpoints

### Public Endpoints
- `GET /` - Root endpoint with API info
- `GET /health` - Health check
- `GET /api/public` - Public API (no authentication)

### Authentication
- `POST /auth/login` - Login and get JWT token
- `GET /auth/users` - List available test users

### Protected Endpoints (Require Authentication)
- `GET /api/protected` - Any authenticated user
- `GET /api/guest` - Requires: guest, user, or admin role
- `GET /api/user` - Requires: user or admin role
- `GET /api/admin` - Requires: admin role only
- `POST /api/admin/users` - Requires: manage_users permission
- `DELETE /api/admin/users/:id` - Requires: delete permission

### Test Users

| Username | Password  | Role  | Permissions |
|----------|-----------|-------|-------------|
| admin    | Admin@123 | admin | read, write, delete, manage_users |
| user     | User@123  | user  | read, write |
| guest    | Guest@123 | guest | read |

## 🐳 Docker

### Build Image

```bash
# Build
docker build -t secure-api-gateway:latest .

# Or use the build script with security scanning
chmod +x scripts/build-and-scan.sh
./scripts/build-and-scan.sh
```

### Run Container Locally

```bash
docker run -d \
  --name api-gateway \
  -p 3000:3000 \
  -e JWT_SECRET="your-secret-key" \
  -e NODE_ENV="production" \
  secure-api-gateway:latest
```

### Security Scanning

```bash
# Install Trivy
brew install trivy  # macOS
# or for Linux: see https://aquasecurity.github.io/trivy/

# Scan image
trivy image --severity HIGH,CRITICAL secure-api-gateway:latest
```

## 🔄 Jenkins CI/CD Pipeline

### Pipeline Overview

1. **Checkout** - Clone repository
2. **Security: Dependency Audit** - npm audit for vulnerabilities
3. **Lint & Test** - ESLint and unit tests
4. **Build Docker Image** - Multi-stage build
5. **Security: Trivy Scan** - Container vulnerability scanning
6. **Push to Registry** - Push to Docker registry
7. **Deploy to Staging** - SSH to staging VM and deploy
8. **Staging Tests** - Smoke tests on staging
9. **Approve Production** - **Manual approval gate**
10. **Deploy to Production** - SSH to production VM and deploy
11. **Production Verification** - Verify deployment health

### Jenkins Agent Requirements

Your Jenkins agent must have:
- Docker CLI (`docker --version`)
- SSH client (`ssh -V`)
- Trivy (`trivy --version`)
- Git (`git --version`)

### Setup Jenkins Credentials

Add the following credentials in Jenkins (Manage Jenkins → Credentials):

**1. Docker Registry URL** (`docker-registry-url`)
- Type: Secret text
- ID: `docker-registry-url`
- Secret: `ghcr.io/your-org` (or your registry)

**2. Docker Registry Credentials** (`docker-registry-creds`)
- Type: Username with password
- ID: `docker-registry-creds`
- Username: Your registry username
- Password: Your registry token/password

**3. SSH Private Key** (`vm-ssh-key`)
- Type: SSH Username with private key
- ID: `vm-ssh-key`
- Username: `deploy`
- Private Key: Paste your SSH private key

### Configure Pipeline Job

1. **Create Pipeline Job** in Jenkins
2. **Pipeline from SCM**:
   - SCM: Git
   - Repository URL: Your repo URL
   - Script Path: `Jenkinsfile`
3. **Update environment variables** in Jenkinsfile:
   ```groovy
   STAGING_VM_HOST = 'deploy@staging.example.com'
   PROD_VM_HOST = 'deploy@production.example.com'
   REGISTRY = credentials('docker-registry-url')
   ```

### Manual Approval

The pipeline includes a manual approval stage before production deployment. Only users with `admin` or `release-manager` roles can approve.

## 🖥️ VM / Docker Host Deployment

### Initial VM Setup

Run this script on each target VM (staging and production):

```bash
# Copy setup script to VM
scp deploy/scripts/setup-vm.sh user@vm-host:~

# SSH to VM and run setup
ssh user@vm-host
chmod +x setup-vm.sh
./setup-vm.sh
```

This script will:
- Install Docker
- Create `deploy` user
- Configure firewall (UFW)
- Generate JWT secret
- Setup log rotation

### Configure SSH Access

```bash
# On your Jenkins server or local machine
ssh-copy-id deploy@staging.example.com
ssh-copy-id deploy@production.example.com

# Test SSH access
ssh deploy@staging.example.com 'docker ps'
```

### Manual Deployment to VM

```bash
# Deploy to staging
./deploy/scripts/deploy-vm.sh staging deploy@staging.example.com latest

# Deploy to production
./deploy/scripts/deploy-vm.sh production deploy@production.example.com v1.0.0
```

### Systemd Service (Optional)

For systemd management of the container:

```bash
# Copy service file to VM
scp deploy/systemd/gateway.service deploy@vm-host:~

# On the VM
sudo cp gateway.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable gateway
sudo systemctl start gateway
sudo systemctl status gateway

# View logs
sudo journalctl -u gateway -f
```

### Verify Deployment

```bash
# SSH to VM and test
ssh deploy@staging.example.com

# Check container
docker ps | grep gateway

# Test health endpoint
curl http://localhost:3000/health

# View logs
docker logs gateway --tail=100
```

## 🔒 Security Checklist

### Pre-Deployment
- [ ] JWT_SECRET is strong (32+ characters) and unique per environment
- [ ] All secrets stored securely (not in code)
- [ ] HTTPS/TLS configured with reverse proxy (nginx/traefik)
- [ ] CORS origins restricted to known domains
- [ ] Trivy scan shows no CRITICAL vulnerabilities
- [ ] npm audit passes (no high/critical issues)
- [ ] Firewall configured on VMs (ports 22, 80, 443, 3000)
- [ ] SSH access limited to Jenkins agent and admins
- [ ] Container runs as non-root user (UID 1001)

### Post-Deployment
- [ ] Verify health check: `curl https://api.example.com/health`
- [ ] Test authentication and RBAC
- [ ] Monitor container logs for errors
- [ ] Setup log aggregation (optional: ELK, Loki)
- [ ] Configure monitoring alerts
- [ ] Document rollback procedure
- [ ] Test disaster recovery

### Recommended Hardening
- [ ] Setup reverse proxy (nginx) for HTTPS termination
- [ ] Implement rate limiting at proxy level
- [ ] Use secret management (HashiCorp Vault)
- [ ] Enable automatic security updates on VMs
- [ ] Setup log aggregation and monitoring
- [ ] Implement automated backups
- [ ] Configure alerts for security events

## 🧪 Smoke Tests

```bash
#!/bin/bash
# smoke-test.sh

BASE_URL="https://api.example.com"

echo "🧪 Running smoke tests..."

# Test 1: Health check
curl -f $BASE_URL/health || exit 1
echo "✅ Health check passed"

# Test 2: Login
TOKEN=$(curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' \
  | jq -r '.token')
[ -z "$TOKEN" ] && echo "❌ Login failed" && exit 1
echo "✅ Authentication passed"

# Test 3: Protected endpoint
curl -f $BASE_URL/api/protected \
  -H "Authorization: Bearer $TOKEN" || exit 1
echo "✅ Protected endpoint passed"

# Test 4: RBAC - admin endpoint
curl -f $BASE_URL/api/admin \
  -H "Authorization: Bearer $TOKEN" || exit 1
echo "✅ RBAC test passed"

# Test 5: User role cannot access admin
USER_TOKEN=$(curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"User@123"}' \
  | jq -r '.token')
  
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/api/admin \
  -H "Authorization: Bearer $USER_TOKEN")
[ "$STATUS" != "403" ] && echo "❌ RBAC enforcement failed" && exit 1
echo "✅ RBAC enforcement passed"

echo "✅ All smoke tests passed!"
```

## 🔄 Rollback Procedure

### Via Jenkins

1. Navigate to previous successful build
2. Click "Rebuild"
3. Approve production deployment
4. Verify rollback

### Manual Rollback

```bash
# SSH to the VM
ssh deploy@production.example.com

# Stop current container
docker stop gateway
docker rm gateway

# Run previous version
docker run -d \
  --name gateway \
  --restart unless-stopped \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
  -e PORT=3000 \
  ghcr.io/your-org/secure-api-gateway:previous-tag

# Verify
docker ps | grep gateway
curl http://localhost:3000/health
```

## 📊 Environment Variables

### Required
- `JWT_SECRET` - Strong random string (32+ characters)
- `NODE_ENV` - "development" or "production"

### Optional
- `PORT` - Server port (default: 3000)
- `JWT_EXPIRY` - Token expiry (default: 1h)
- `CORS_ORIGIN` - Allowed CORS origins
- `LOG_LEVEL` - Logging level (debug, info, warn, error)

## 🆘 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs gateway

# Common issues:
# - JWT_SECRET not set
# - Port already in use
# - Permission issues
```

### Health Check Fails

```bash
# Check if container is running
docker ps

# Check container logs
docker logs gateway --tail=100

# Test from inside container
docker exec gateway curl http://localhost:3000/health
```

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -v deploy@vm-host

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh

# Verify deploy user can run docker
ssh deploy@vm-host 'docker ps'
```

### JWT Token Issues

```bash
# Token expired - get new token
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}'

# Invalid token - check JWT_SECRET matches
```

## 🚀 Next Steps

### Phase 1: Production Hardening
1. **Setup HTTPS reverse proxy** (nginx/traefik) for TLS termination
2. **Integrate database** (PostgreSQL/MongoDB) and use bcrypt for passwords
3. **Implement secret management** (HashiCorp Vault or AWS Secrets Manager)

### Phase 2: Monitoring & Observability
1. **Setup log aggregation** (ELK Stack or Loki/Grafana)
2. **Add metrics** (Prometheus exporter endpoint)
3. **Configure alerts** (PagerDuty, Opsgenie, or Slack)

### Phase 3: Advanced Features
1. **Rate limiting** at application or reverse proxy level
2. **Refresh tokens** and token revocation
3. **Multi-factor authentication** (MFA/2FA)

## 📄 License

MIT

## 👤 Author

**Ganesh N**  
Secure API Gateway - VM Deployment Version

---

**Version**: 1.1  
**Last Updated**: 2025-11-16  
**Deployment Target**: VM/Docker Host (No Kubernetes)
# RBAC_Devops

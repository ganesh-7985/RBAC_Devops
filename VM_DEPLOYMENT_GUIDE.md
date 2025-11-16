# 🖥️ VM Deployment Guide - Secure API Gateway

Complete guide for deploying the Secure API Gateway to VMs or Docker hosts using Jenkins and SSH.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [VM Setup](#vm-setup)
4. [Jenkins Configuration](#jenkins-configuration)
5. [Deployment Process](#deployment-process)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## 🏗️ Architecture Overview

```
┌─────────────────────┐
│   Jenkins Server    │
│   (CI/CD Pipeline)  │
└──────────┬──────────┘
           │ SSH
           ├────────────────────┐
           │                    │
           ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   Staging VM     │  │  Production VM   │
│  ┌────────────┐  │  │  ┌────────────┐  │
│  │   Docker   │  │  │  │   Docker   │  │
│  │ Container  │  │  │  │ Container  │  │
│  │  (Gateway) │  │  │  │  (Gateway) │  │
│  └────────────┘  │  │  └────────────┘  │
│   Port 3000      │  │   Port 3000      │
└──────────────────┘  └──────────────────┘
```

**Deployment Flow:**
1. Jenkins builds Docker image
2. Trivy scans for vulnerabilities
3. Push to Docker registry
4. SSH to staging VM → Deploy container
5. Run smoke tests
6. **Manual approval gate**
7. SSH to production VM → Deploy container
8. Verify production deployment

## 📋 Prerequisites

### Jenkins Server
- Jenkins >= 2.400
- Plugins:
  - SSH Agent Plugin
  - Docker Pipeline
  - Credentials Binding
- Jenkins agent with:
  - Docker CLI
  - SSH client
  - Trivy
  - Git

### Target VMs (Staging & Production)
- Ubuntu 20.04+ or Debian 11+
- Docker installed
- SSH access
- User: `deploy` with Docker permissions
- Open ports: 22 (SSH), 3000 (API), 80/443 (optional nginx)

### Docker Registry
- GitHub Container Registry (GHCR)
- Docker Hub
- AWS ECR
- Or private registry

## 🖥️ VM Setup

### Step 1: Initial Server Configuration

Run on each target VM (staging and production):

```bash
# 1. Copy setup script to VM
scp deploy/scripts/setup-vm.sh user@staging.example.com:~

# 2. SSH to VM
ssh user@staging.example.com

# 3. Run setup script
chmod +x setup-vm.sh
sudo ./setup-vm.sh
```

### Step 2: What the Setup Script Does

The `setup-vm.sh` script performs:

1. **System Update**
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

2. **Docker Installation**
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   ```

3. **Create Deploy User**
   ```bash
   sudo useradd -m -s /bin/bash deploy
   sudo usermod -aG docker deploy
   ```

4. **Generate JWT Secret**
   ```bash
   sudo mkdir -p /etc/gateway
   openssl rand -base64 32 | sudo tee /etc/gateway/jwt-secret
   sudo chown deploy:deploy /etc/gateway/jwt-secret
   sudo chmod 600 /etc/gateway/jwt-secret
   ```

5. **Configure Firewall**
   ```bash
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 3000/tcp  # API
   sudo ufw allow 80/tcp    # HTTP
   sudo ufw allow 443/tcp   # HTTPS
   sudo ufw --force enable
   ```

### Step 3: Configure SSH Access

```bash
# Generate SSH key pair (if not exists)
ssh-keygen -t ed25519 -C "jenkins-deploy"

# Copy public key to VMs
ssh-copy-id deploy@staging.example.com
ssh-copy-id deploy@production.example.com

# Test SSH access
ssh deploy@staging.example.com 'docker ps'
ssh deploy@production.example.com 'docker ps'
```

### Step 4: Verify JWT Secret

```bash
# On each VM, verify JWT secret exists
ssh deploy@staging.example.com 'cat /etc/gateway/jwt-secret'

# IMPORTANT: Save these secrets securely!
# They must match across deployments or tokens won't work
```

## 🔧 Jenkins Configuration

### Step 1: Install Required Plugins

Navigate to: **Manage Jenkins → Plugins → Available**

Install:
- SSH Agent Plugin
- Docker Pipeline Plugin
- Credentials Binding Plugin

### Step 2: Configure Credentials

Go to: **Manage Jenkins → Credentials → System → Global credentials**

#### A. Docker Registry URL

- **Type**: Secret text
- **ID**: `docker-registry-url`
- **Secret**: `ghcr.io/your-org` (or your registry URL)
- **Description**: Docker registry URL

#### B. Docker Registry Credentials

- **Type**: Username with password
- **ID**: `docker-registry-creds`
- **Username**: Your registry username
- **Password**: Your registry token/password
- **Description**: Docker registry credentials

#### C. SSH Private Key for VMs

- **Type**: SSH Username with private key
- **ID**: `vm-ssh-key`
- **Username**: `deploy`
- **Private Key**: Enter directly or paste from file
- **Passphrase**: Enter if your key has one
- **Description**: SSH key for VM deployment

### Step 3: Configure Jenkins Agent

Ensure your Jenkins agent has required tools:

```bash
# On Jenkins agent, verify:
docker --version      # Docker CLI
ssh -V               # SSH client
trivy --version      # Trivy scanner
git --version        # Git
```

Label your agent with: `docker`

### Step 4: Create Pipeline Job

1. **New Item** → **Pipeline** → Name: `secure-api-gateway`

2. **General Settings**:
   - Description: "Secure API Gateway CI/CD Pipeline"
   - Discard old builds: Keep last 10

3. **Build Triggers**:
   - GitHub webhook (recommended)
   - Or Poll SCM: `H/5 * * * *`

4. **Pipeline**:
   - Definition: **Pipeline script from SCM**
   - SCM: **Git**
   - Repository URL: `https://github.com/your-org/rbac-ssd.git`
   - Credentials: Add if private repo
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

5. **Environment Variables** (in Jenkinsfile):

Edit `Jenkinsfile` to update:

```groovy
environment {
    REGISTRY = credentials('docker-registry-url')
    STAGING_VM_HOST = 'deploy@staging.example.com'  // UPDATE THIS
    PROD_VM_HOST = 'deploy@production.example.com'  // UPDATE THIS
    SSH_CREDENTIALS_ID = 'vm-ssh-key'
    CONTAINER_NAME = 'gateway'
    CONTAINER_PORT = '3000'
}
```

### Step 5: Test SSH Connection from Jenkins

Create a test pipeline job to verify SSH:

```groovy
pipeline {
    agent { label 'docker' }
    stages {
        stage('Test SSH') {
            steps {
                sshagent(credentials: ['vm-ssh-key']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no deploy@staging.example.com 'hostname && docker ps'
                    """
                }
            }
        }
    }
}
```

## 🚀 Deployment Process

### Automated Deployment via Jenkins

1. **Trigger Build**:
   - Push code to repository (if webhook configured)
   - Or click "Build Now" in Jenkins

2. **Pipeline Stages**:
   - ✅ Checkout code
   - ✅ npm audit (security)
   - ✅ Lint & Test
   - ✅ Build Docker image
   - ✅ Trivy security scan
   - ✅ Push to registry
   - ✅ Deploy to staging VM
   - ✅ Staging smoke tests
   - ⏸️ **Wait for manual approval**
   - ✅ Deploy to production VM
   - ✅ Production verification

3. **Manual Approval**:
   - Jenkins pauses at "Approve Production Deployment"
   - Review staging deployment
   - Click "Deploy" to proceed or "Abort" to stop
   - Only users with `admin` or `release-manager` roles can approve

### Manual Deployment

If Jenkins is unavailable, deploy manually:

```bash
# 1. Build image locally
docker build -t secure-api-gateway:v1.0.0 .

# 2. Push to registry
docker tag secure-api-gateway:v1.0.0 ghcr.io/your-org/secure-api-gateway:v1.0.0
docker push ghcr.io/your-org/secure-api-gateway:v1.0.0

# 3. Deploy to staging
./deploy/scripts/deploy-vm.sh staging deploy@staging.example.com v1.0.0

# 4. Test staging
ssh deploy@staging.example.com 'curl http://localhost:3000/health'

# 5. Deploy to production (after verification)
./deploy/scripts/deploy-vm.sh production deploy@production.example.com v1.0.0
```

### Deployment Script Details

The `deploy-vm.sh` script performs:

```bash
#!/bin/bash
# 1. SSH to target VM
# 2. Stop old container
docker stop gateway || true
docker rm gateway || true

# 3. Pull new image
docker pull ghcr.io/your-org/secure-api-gateway:v1.0.0

# 4. Run new container
docker run -d \
  --name gateway \
  --restart unless-stopped \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
  -e PORT=3000 \
  -e LOG_LEVEL=info \
  ghcr.io/your-org/secure-api-gateway:v1.0.0

# 5. Health check
sleep 10
curl -f http://localhost:3000/health
```

## ✅ Verification

### Verify Container Status

```bash
# SSH to VM
ssh deploy@staging.example.com

# Check container is running
docker ps | grep gateway

# Should show:
# CONTAINER ID   IMAGE                         STATUS         PORTS
# abc123def456   ghcr.io/.../gateway:v1.0.0   Up 2 minutes   0.0.0.0:3000->3000/tcp
```

### Health Check

```bash
# From VM
curl http://localhost:3000/health

# From external (if firewall allows)
curl http://staging.example.com:3000/health

# Expected response:
# {
#   "status": "healthy",
#   "timestamp": "2025-11-16T00:00:00.000Z",
#   "uptime": 120.5,
#   "environment": "production"
# }
```

### Test Authentication

```bash
# Get token
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"Admin@123"}' \
  | jq -r '.token')

# Test protected endpoint
curl http://localhost:3000/api/admin \
  -H "Authorization: Bearer $TOKEN"
```

### Check Logs

```bash
# View container logs
docker logs gateway --tail=100

# Follow logs
docker logs gateway -f

# Check for errors
docker logs gateway | grep -i error
```

## 🐛 Troubleshooting

### Issue: SSH Connection Refused

**Symptoms:**
```
ssh: connect to host staging.example.com port 22: Connection refused
```

**Solutions:**
1. Verify VM is running and accessible
2. Check firewall allows port 22
   ```bash
   sudo ufw status
   sudo ufw allow 22/tcp
   ```
3. Verify SSH service is running
   ```bash
   sudo systemctl status ssh
   ```

### Issue: Docker Permission Denied

**Symptoms:**
```
Got permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add deploy user to docker group
sudo usermod -aG docker deploy

# Re-login or restart Docker
sudo systemctl restart docker

# Verify
docker ps
```

### Issue: Container Fails to Start

**Check logs:**
```bash
docker logs gateway
```

**Common causes:**
1. **JWT_SECRET not set**
   ```bash
   # Verify secret exists
   cat /etc/gateway/jwt-secret
   
   # If missing, generate:
   openssl rand -base64 32 | sudo tee /etc/gateway/jwt-secret
   ```

2. **Port already in use**
   ```bash
   # Check what's using port 3000
   sudo lsof -i :3000
   
   # Kill process or use different port
   docker run -p 8080:3000 ...
   ```

3. **Image pull failed**
   ```bash
   # Manual pull to see error
   docker pull ghcr.io/your-org/secure-api-gateway:latest
   
   # Check registry credentials
   docker login ghcr.io
   ```

### Issue: Health Check Fails

**Symptoms:**
```
curl: (7) Failed to connect to localhost port 3000: Connection refused
```

**Solutions:**
1. Verify container is running
   ```bash
   docker ps | grep gateway
   ```

2. Check container logs
   ```bash
   docker logs gateway --tail=50
   ```

3. Test from inside container
   ```bash
   docker exec gateway curl http://localhost:3000/health
   ```

### Issue: Jenkins Pipeline Fails at SSH Stage

**Check:**
1. SSH credentials configured correctly in Jenkins
2. SSH key has correct permissions (600)
3. deploy user has Docker permissions
4. Test SSH manually:
   ```bash
   ssh deploy@staging.example.com 'docker ps'
   ```

### Issue: Old Container Not Stopping

**Solution:**
```bash
# Force stop and remove
docker stop gateway || true
docker rm -f gateway || true

# Check for orphaned containers
docker ps -a | grep gateway
```

## 🔄 Rollback Procedure

### Quick Rollback

```bash
# SSH to affected VM
ssh deploy@production.example.com

# Stop current container
docker stop gateway
docker rm gateway

# Pull and run previous version
docker pull ghcr.io/your-org/secure-api-gateway:v1.0.0-prev
docker run -d \
  --name gateway \
  --restart unless-stopped \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=$(cat /etc/gateway/jwt-secret) \
  -e PORT=3000 \
  ghcr.io/your-org/secure-api-gateway:v1.0.0-prev

# Verify
docker ps
curl http://localhost:3000/health
```

### Jenkins Rollback

1. Find previous successful build
2. Click "Rebuild"
3. Approve deployment to production

## 📊 Monitoring

### Container Health Monitoring

```bash
# Create monitoring script
cat > /usr/local/bin/check-gateway.sh << 'EOF'
#!/bin/bash
if ! docker ps | grep -q gateway; then
    echo "Gateway container not running!" | mail -s "ALERT: Gateway Down" admin@example.com
fi
if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
    echo "Gateway health check failed!" | mail -s "ALERT: Gateway Unhealthy" admin@example.com
fi
EOF

chmod +x /usr/local/bin/check-gateway.sh

# Add to cron (check every 5 minutes)
echo "*/5 * * * * /usr/local/bin/check-gateway.sh" | crontab -
```

### Log Monitoring

```bash
# View logs in real-time
docker logs gateway -f

# Search for errors
docker logs gateway | grep -i error

# Export logs
docker logs gateway > /tmp/gateway.log
```

## 🔒 Security Best Practices

1. **Use HTTPS**: Setup nginx reverse proxy for TLS termination
2. **Restrict SSH**: Only allow Jenkins agent IP
3. **Rotate Secrets**: Change JWT_SECRET periodically
4. **Update Regularly**: Keep Docker and VMs updated
5. **Monitor Logs**: Setup log aggregation (ELK/Loki)
6. **Limit Permissions**: deploy user should only have Docker access
7. **Backup Secrets**: Store JWT secrets in password manager

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Jenkins SSH Agent Plugin](https://plugins.jenkins.io/ssh-agent/)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [UFW Firewall Guide](https://help.ubuntu.com/community/UFW)

---

**Last Updated**: 2025-11-16  
**Version**: 1.1
